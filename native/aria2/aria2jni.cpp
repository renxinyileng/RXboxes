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
#include <android/log.h>

#include <atomic>
#include <string>
#include <vector>

#include <aria2/aria2.h>

#define LOG_TAG "aria2jni"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

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
    if (gRunning.load()) {
        LOGI("aria2 已在运行，忽略本次启动请求");
        return JNI_TRUE;
    }
    if (keys == nullptr || values == nullptr) {
        LOGE("选项数组为空");
        return JNI_FALSE;
    }

    const jsize n = env->GetArrayLength(keys);
    if (n != env->GetArrayLength(values)) {
        LOGE("选项键值数量不一致");
        return JNI_FALSE;
    }

    gOptions.clear();
    gOptions.reserve(static_cast<size_t>(n));
    for (jsize i = 0; i < n; ++i) {
        jstring k = static_cast<jstring>(env->GetObjectArrayElement(keys, i));
        jstring v = static_cast<jstring>(env->GetObjectArrayElement(values, i));
        std::string key = jstringToStd(env, k);
        std::string value = jstringToStd(env, v);
        if (!key.empty()) {
            gOptions.emplace_back(key, value);
        }
        env->DeleteLocalRef(k);
        env->DeleteLocalRef(v);
    }

    gStopRequested.store(false);
    gRunning.store(true);
    gStartState = kPending;
    if (pthread_create(&gThread, nullptr, aria2Worker, nullptr) != 0) {
        LOGE("创建 aria2 工作线程失败");
        gRunning.store(false);
        return JNI_FALSE;
    }
    gJoinable = true;

    // 等工作线程把 session 建起来（或失败），再把真实结果返回给 Java。
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
        return JNI_FALSE;
    }
    return JNI_TRUE;
}

JNIEXPORT void JNICALL
Java_com_rxteam_aria2_Aria2_nativeStop(JNIEnv*, jclass)
{
    if (!gJoinable) {
        return;
    }
    // 事件循环自己退出的情况下 gRunning 已经是 false，线程仍然需要 join
    gStopRequested.store(true);
    pthread_join(gThread, nullptr);
    gJoinable = false;
}

JNIEXPORT jboolean JNICALL
Java_com_rxteam_aria2_Aria2_nativeIsRunning(JNIEnv*, jclass)
{
    return gRunning.load() ? JNI_TRUE : JNI_FALSE;
}

} // extern "C"
