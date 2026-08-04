require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.util.Log"
import "androidx.media3.exoplayer.ExoPlayer"
import "androidx.media3.common.MediaItem"
import "androidx.media3.common.Player"
import "androidx.media3.ui.PlayerView"
import "androidx.media3.datasource.DefaultHttpDataSource"
import "androidx.media3.exoplayer.source.DefaultMediaSourceFactory"

-- 本地文件(m3u8/mp4)播放入口,由 main.lua 传入完整路径(如 /storage/emulated/0/xxx.m3u8)
-- 也兼容直接传入 http(s):// 地址或 file:// URI
urlpatn = ...
if type(urlpatn) ~= "string" then
    urlpatn = ""
end
-- 纯本地路径补成 file:// URI,交给 ExoPlayer
if urlpatn ~= "" and not urlpatn:find("^file://") and not urlpatn:find("^https?://") then
    urlpatn = "file://" .. urlpatn
end

pcall(function() activity.getActionBar().hide() end)

layout = {
    LinearLayout,
    orientation = "vertical",
    layout_height = "fill",
    layout_width = "fill",
    {
        PlayerView,
        layout_width = "fill",
        layout_height = "fill",
        id = "player_view"
    }
};
activity.setContentView(loadlayout(layout))

-- 播放视频时保持屏幕常亮
activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

-- 错误码 -> 用户可读提示
function 播放错误提示(code)
    local tips = {
        ["ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT"] = "视频源连接超时，请检查网络或稍后重试",
        ["ERROR_CODE_IO_NETWORK_CONNECTION_FAILED"] = "视频源网络连接失败",
        ["ERROR_CODE_IO_DNS_FAILED"] = "视频源域名解析失败",
        ["ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED"] = "不支持的视频格式",
        ["ERROR_CODE_PARSING_MANIFEST_UNSUPPORTED"] = "不支持的视频清单格式",
        ["ERROR_CODE_DECODER_INIT_FAILED"] = "解码器初始化失败",
        ["ERROR_CODE_DECODING_FAILED"] = "视频解码失败",
    }
    return tips[code] or ("播放失败(" .. tostring(code) .. ")")
end

-- 创建 ExoPlayer 并绑定到 PlayerView(连接/读取超时放宽到 15s,默认 8s 对慢源太短)
-- 注意:media3 1.3+ 已移除 Builder.setHttpDataSourceFactory,需经 DefaultMediaSourceFactory 注入数据源
-- 用 pcall 兜底:万一自定义数据源配置失败,回退到默认构建,保证播放器可用
dsFactory = DefaultHttpDataSource.Factory()
dsFactory.setConnectTimeoutMs(15000)
dsFactory.setReadTimeoutMs(15000)
local ok, err = pcall(function()
    player = ExoPlayer.Builder(activity).setMediaSourceFactory(DefaultMediaSourceFactory(dsFactory)).build()
end)
if not ok then
    Log.w("ExoPlayer", "自定义数据源配置失败,回退默认构建: " .. tostring(err))
    player = ExoPlayer.Builder(activity).build()
end
player_view.setPlayer(player)
player_view.setShowBuffering(1)

-- 错误回调:logcat 输出真实错误码,界面 Toast 提示用户
player.addListener(Player.Listener {
    onPlayerError = function(e)
        local code = tostring(e.getErrorCodeName())
        local msg = tostring(e.getMessage())
        Log.e("ExoPlayer", "播放错误 code=" .. code .. " msg=" .. msg)
        print("ExoPlayer 播放错误 code=" .. code .. " msg=" .. msg)
        Toast.makeText(activity, 播放错误提示(code), Toast.LENGTH_LONG).show()
    end
})

if urlpatn ~= "" then
    player.setMediaItem(MediaItem.fromUri(urlpatn))
    player.prepare()
    player.play()
else
    Log.e("ExoPlayer", "未传入视频地址")
    print("ExoPlayer 未传入视频地址")
end

parameter = 0
function onKeyDown(code, event)
    if string.find(tostring(event), "KEYCODE_BACK") ~= nil then
        if parameter + 2 > tonumber(os.time()) then
            if player then
                player.release()
            end
            activity.finish()
        else
            print("再按一次返回键退出")
            parameter = tonumber(os.time())
        end
        return true
    end
end
