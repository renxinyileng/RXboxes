/*
 * libaria2 的 JNI 封装。
 *
 * 目的：不再把 aria2c 当成可执行文件 fork/exec —— Android 10（API 29）起
 * targetSdk >= 29 的应用已经不允许执行自己可写目录里的文件。这里改成把
 * aria2 以库的形式链进进程内运行。
 *
 * RPC 照常工作：sessionNew() 内部会走 MultiUrlRequestInfo::prepare()，
 * 只要选项里 enable-rpc=true，DownloadEngineFactory 就会建立 RPC 监听
 * 与 WebSocket，AriaNg 前端无需任何改动。
 */
#include <jni.h>
#include <pthread.h>

#include <atomic>
#include <string>
#include <vector>

#include <aria2/aria2.h>

// 非 Android 下退化成 stderr，这样同一份引擎驱动逻辑能编成宿主机程序，
// 在 CI 里对着真实的 aria2.conf 跑一遍 JSON-RPC（见文件末尾的 main）。
// 我们实际发布的是 sessionNew 这条库入口，跟 aria2c 可执行文件那条不是
// 同一条路径，所以必须按这条来验证。
#ifdef __ANDROID__
#  include <android/log.h>
#  define LOG_TAG "aria2jni"
#  define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#  define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
#  include <cstdio>
#  define LOGI(...) do { fprintf(stderr, "[I] " __VA_ARGS__); fputc('\n', stderr); } while (0)
#  define LOGE(...) do { fprintf(stderr, "[E] " __VA_ARGS__); fputc('\n', stderr); } while (0)
#endif

namespace {

enum StartState { kPending, kStarted, kFailed };

std::atomic<bool> gRunning{false};
std::atomic<bool> gStopRequested{false};
bool gJoinable = false;
pthread_t gThread;
aria2::KeyVals gOptions;

// 用来把"会话是否建起来了"这个结果从工作线程回传给 nativeStart，
// 否则 Java 侧拿到的 true 只代表线程创建成功，并不代表 aria2 真的起来了
pthread_mutex_t gStartMutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t gStartCond = PTHREAD_COND_INITIALIZER;
StartState gStartState = kPending;

void publishStartState(StartState state)
{
    pthread_mutex_lock(&gStartMutex);
    gStartState = state;
    pthread_cond_broadcast(&gStartCond);
    pthread_mutex_unlock(&gStartMutex);
}

/*
 * aria2 的 Session 不是线程安全的，所有 API 调用都必须发生在同一个线程上，
 * 所以 session 的创建、事件循环、销毁全部放在这个工作线程里完成。
 */
void* aria2Worker(void*)
{
    if (aria2::libraryInit() != 0) {
        LOGE("libraryInit 失败");
        gRunning.store(false);
        publishStartState(kFailed);
        return nullptr;
    }

    aria2::SessionConfig config;
    // 没有下载任务时也要保持事件循环，否则 RPC 服务会随引擎一起退出
    config.keepRunning = true;
    // 不要在宿主 App 进程里安装 SIGINT/SIGTERM 处理器
    config.useSignalHandler = false;

    aria2::Session* session = aria2::sessionNew(gOptions, config);
    if (session == nullptr) {
        // aria2 的选项解析错误只写到 stderr，Android 上等于丢弃，
        // 所以这里把传进去的选项打出来，否则失败原因无从查起
        LOGE("sessionNew 失败，实际传入的 %zu 项选项如下：", gOptions.size());
        for (const auto& kv : gOptions) {
            LOGE("    %s = %s", kv.first.c_str(), kv.second.c_str());
        }
        aria2::libraryDeinit();
        gRunning.store(false);
        publishStartState(kFailed);
        return nullptr;
    }

    LOGI("aria2 会话已启动");
    publishStartState(kStarted);

    while (!gStopRequested.load()) {
        // RUN_ONCE 每次事件轮询最多阻塞 1 秒，便于及时响应停止请求
        int rv = aria2::run(session, aria2::RUN_ONCE);
        if (rv != 1) {
            if (rv < 0) {
                LOGE("run() 返回错误码 %d", rv);
            }
            break;
        }
    }

    aria2::sessionFinal(session);
    aria2::libraryDeinit();
    gRunning.store(false);
    LOGI("aria2 会话已停止");
    return nullptr;
}

// 真正的启动逻辑。JNI 入口和宿主机探针都走这里，保证被验证的就是被发布的。
bool startEngine(aria2::KeyVals options)
{
    if (gRunning.load()) {
        LOGI("aria2 已在运行，忽略本次启动请求");
        return true;
    }

    gOptions = std::move(options);
    gStopRequested.store(false);
    gRunning.store(true);
    gStartState = kPending;

    if (pthread_create(&gThread, nullptr, aria2Worker, nullptr) != 0) {
        LOGE("创建 aria2 工作线程失败");
        gRunning.store(false);
        return false;
    }
    gJoinable = true;

    // 等工作线程把 session 建起来（或失败），再把真实结果返回给调用方。
    // 建会话包括绑定 RPC 端口，很快，不至于卡住调用方太久。
    pthread_mutex_lock(&gStartMutex);
    while (gStartState == kPending) {
        pthread_cond_wait(&gStartCond, &gStartMutex);
    }
    const StartState state = gStartState;
    pthread_mutex_unlock(&gStartMutex);

    if (state != kStarted) {
        pthread_join(gThread, nullptr);
        gJoinable = false;
        return false;
    }
    return true;
}

void stopEngine()
{
    if (!gJoinable) {
        return;
    }
    // 事件循环自己退出的情况下 gRunning 已经是 false，线程仍然需要 join
    gStopRequested.store(true);
    pthread_join(gThread, nullptr);
    gJoinable = false;
}

std::string jstringToStd(JNIEnv* env, jstring s)
{
    if (s == nullptr) {
        return std::string();
    }
    const char* chars = env->GetStringUTFChars(s, nullptr);
    std::string out(chars != nullptr ? chars : "");
    if (chars != nullptr) {
        env->ReleaseStringUTFChars(s, chars);
    }
    return out;
}

} // namespace

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_rxteam_aria2_Aria2_nativeStart(JNIEnv* env, jclass, jobjectArray keys,
                                        jobjectArray values)
{
    if (keys == nullptr || values == nullptr) {
        LOGE("选项数组为空");
        return JNI_FALSE;
    }

    const jsize n = env->GetArrayLength(keys);
    if (n != env->GetArrayLength(values)) {
        LOGE("选项键值数量不一致");
        return JNI_FALSE;
    }

    aria2::KeyVals options;
    options.reserve(static_cast<size_t>(n));
    for (jsize i = 0; i < n; ++i) {
        jstring k = static_cast<jstring>(env->GetObjectArrayElement(keys, i));
        jstring v = static_cast<jstring>(env->GetObjectArrayElement(values, i));
        std::string key = jstringToStd(env, k);
        std::string value = jstringToStd(env, v);
        if (!key.empty()) {
            options.emplace_back(key, value);
        }
        env->DeleteLocalRef(k);
        env->DeleteLocalRef(v);
    }

    return startEngine(std::move(options)) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_rxteam_aria2_Aria2_nativeStop(JNIEnv*, jclass)
{
    stopEngine();
}

JNIEXPORT jboolean JNICALL
Java_com_rxteam_aria2_Aria2_nativeIsRunning(JNIEnv*, jclass)
{
    return gRunning.load() ? JNI_TRUE : JNI_FALSE;
}

} // extern "C"

// ---------------------------------------------------------------------------
// 宿主机 RPC 探针（只在非 Android 下编译）
//
// 存在的理由：CI 里能跑的 aria2c 可执行文件走的是 main() -> MultiUrlRequestInfo
// 那条路，而我们实际发布的是 sessionNew() 这条库入口。两条路共用 RPC 建立
// 逻辑，但"选项怎么进去"是不同的——尤其 conf-path 经 sessionNew 传递这件事
// 从来没被验证过。如果它静默失效，配置全部被忽略、enable-rpc 回到默认 false，
// 表现就是 App 看着正常启动但 AriaNg 连不上。
//
// 这里复用上面同一个 startEngine()，所以被验证的就是被发布的那份逻辑。
//
// 用法：aria2-probe <aria2.conf 路径> <rpc 端口> <下载目录>
//       起来后阻塞，收到 SIGINT/SIGTERM 退出。
#ifndef __ANDROID__
#include <csignal>
#include <unistd.h>

namespace {
volatile sig_atomic_t gProbeStop = 0;
void onSignal(int) { gProbeStop = 1; }
} // namespace

int main(int argc, char** argv)
{
    if (argc < 4) {
        fprintf(stderr, "用法: %s <aria2.conf> <rpc 端口> <下载目录>\n", argv[0]);
        return 2;
    }
    const std::string conf = argv[1];
    const std::string port = argv[2];
    const std::string dir = argv[3];

    signal(SIGINT, onSignal);
    signal(SIGTERM, onSignal);

    // 与 Aria2.startWithConf() + main.lua 的覆盖项保持一致
    aria2::KeyVals options{
        {"conf-path", conf},
        {"dir", dir},
        {"input-file", dir + "/aria2.session"},
        {"save-session", dir + "/aria2.session"},
        {"rpc-listen-port", port},
        {"enable-rpc", "true"},
    };

    if (!startEngine(std::move(options))) {
        fprintf(stderr, "启动失败\n");
        return 1;
    }
    printf("READY %s\n", port.c_str());
    fflush(stdout);

    while (!gProbeStop && gRunning.load()) {
        usleep(100 * 1000);
    }
    stopEngine();
    printf("STOPPED\n");
    return 0;
}
#endif // !__ANDROID__
