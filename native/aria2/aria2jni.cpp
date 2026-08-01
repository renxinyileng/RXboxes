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

std::atomic<bool> gRunning{false};
std::atomic<bool> gStopRequested{false};
pthread_t gThread;
aria2::KeyVals gOptions;

/*
 * aria2 的 Session 不是线程安全的，所有 API 调用都必须发生在同一个线程上，
 * 所以 session 的创建、事件循环、销毁全部放在这个工作线程里完成。
 */
void* aria2Worker(void*)
{
    if (aria2::libraryInit() != 0) {
        LOGE("libraryInit 失败");
        gRunning.store(false);
        return nullptr;
    }

    aria2::SessionConfig config;
    // 没有下载任务时也要保持事件循环，否则 RPC 服务会随引擎一起退出
    config.keepRunning = true;
    // 不要在宿主 App 进程里安装 SIGINT/SIGTERM 处理器
    config.useSignalHandler = false;

    aria2::Session* session = aria2::sessionNew(gOptions, config);
    if (session == nullptr) {
        LOGE("sessionNew 失败，请检查传入的选项");
        aria2::libraryDeinit();
        gRunning.store(false);
        return nullptr;
    }

    LOGI("aria2 会话已启动");
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
    if (pthread_create(&gThread, nullptr, aria2Worker, nullptr) != 0) {
        LOGE("创建 aria2 工作线程失败");
        gRunning.store(false);
        return JNI_FALSE;
    }
    return JNI_TRUE;
}

JNIEXPORT void JNICALL
Java_com_rxteam_aria2_Aria2_nativeStop(JNIEnv*, jclass)
{
    if (!gRunning.load() && !gStopRequested.load()) {
        return;
    }
    gStopRequested.store(true);
    pthread_join(gThread, nullptr);
}

JNIEXPORT jboolean JNICALL
Java_com_rxteam_aria2_Aria2_nativeIsRunning(JNIEnv*, jclass)
{
    return gRunning.load() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jstring JNICALL
Java_com_rxteam_aria2_Aria2_nativeVersion(JNIEnv* env, jclass)
{
    return env->NewStringUTF("libaria2");
}

} // extern "C"
