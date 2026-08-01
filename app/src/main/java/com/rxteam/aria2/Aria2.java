package com.rxteam.aria2;

import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 进程内运行的 aria2 下载核心。
 *
 * <p>以前的做法是把 assets 里的 aria2c 复制到应用私有目录、chmod 后 exec。
 * Android 10（API 29）起，targetSdk &gt;= 29 的应用不允许执行自己可写目录里的
 * 文件（W^X 限制），这条路已经走不通。这里改为通过 JNI 直接驱动 libaria2，
 * 不再有子进程。
 *
 * <p>RPC 行为与独立的 aria2c 完全一致：只要选项里 {@code enable-rpc=true}，
 * 引擎就会监听 RPC 端口并支持 WebSocket，AriaNg 前端无需改动。
 */
public final class Aria2 {

    private static final String TAG = "Aria2";

    static {
        System.loadLibrary("aria2jni");
    }

    private Aria2() {
    }

    /**
     * 按给定选项启动 aria2。选项键名与 aria2 命令行/配置文件一致（不带 {@code --}）。
     *
     * @return 启动成功返回 true；已在运行时也返回 true
     */
    public static synchronized boolean start(Map<String, String> options) {
        if (options == null) {
            options = new LinkedHashMap<String, String>();
        }
        List<String> keys = new ArrayList<String>(options.size());
        List<String> values = new ArrayList<String>(options.size());
        for (Map.Entry<String, String> e : options.entrySet()) {
            if (e.getKey() == null || e.getKey().length() == 0) {
                continue;
            }
            keys.add(e.getKey());
            values.add(e.getValue() == null ? "" : e.getValue());
        }
        return nativeStart(keys.toArray(new String[0]), values.toArray(new String[0]));
    }

    /**
     * 读取 aria2.conf 后启动。
     *
     * @param confPath 配置文件路径，不存在时按空配置启动
     * @param override 需要覆盖/追加的选项，可为 null
     */
    public static synchronized boolean startWithConf(String confPath, Map<String, String> override) {
        Map<String, String> options = readConf(confPath);
        if (override != null) {
            options.putAll(override);
        }
        return start(options);
    }

    /** 停止 aria2 并等待事件循环退出。 */
    public static synchronized void stop() {
        nativeStop();
    }

    public static boolean isRunning() {
        return nativeIsRunning();
    }

    /**
     * 解析 aria2 配置文件。格式为每行 {@code key=value}，{@code #} 开头为注释。
     * 文件不存在或读取失败时返回空表，不抛异常。
     */
    public static Map<String, String> readConf(String confPath) {
        Map<String, String> options = new LinkedHashMap<String, String>();
        if (confPath == null) {
            return options;
        }
        File file = new File(confPath);
        if (!file.isFile()) {
            Log.w(TAG, "配置文件不存在：" + confPath);
            return options;
        }
        BufferedReader reader = null;
        try {
            reader = new BufferedReader(new FileReader(file));
            String line;
            while ((line = reader.readLine()) != null) {
                line = line.trim();
                if (line.length() == 0 || line.charAt(0) == '#' || line.charAt(0) == ';') {
                    continue;
                }
                int i = line.indexOf('=');
                String key;
                String value;
                if (i < 0) {
                    // 形如 "continue" 的开关项，等价于 continue=true
                    key = line;
                    value = "true";
                } else {
                    key = line.substring(0, i).trim();
                    value = line.substring(i + 1).trim();
                }
                if (key.startsWith("--")) {
                    key = key.substring(2);
                }
                if (key.length() > 0) {
                    options.put(key, value);
                }
            }
        } catch (IOException e) {
            Log.w(TAG, "读取配置文件失败：" + confPath, e);
        } finally {
            if (reader != null) {
                try {
                    reader.close();
                } catch (IOException ignored) {
                }
            }
        }
        return options;
    }

    private static native boolean nativeStart(String[] keys, String[] values);

    private static native void nativeStop();

    private static native boolean nativeIsRunning();
}
