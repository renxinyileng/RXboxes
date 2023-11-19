require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "com.aliyun.player.*"
import "com.aliyun.player.AliPlayerFactory"
import "com.aliyun.player.IPlayer"
import "com.aliyun.player.source.UrlSource"
activity.getSupportActionBar().hide()
url = ...
layout = {
    LinearLayout,
    orientation = "vertical",
    layout_height = "fill",
    layout_width = "fill",
    tool_bar,
    {
        SurfaceView,
        layout_height = "wrap",
        layout_width = "wrap",
        id = "surface_view"
    }
};
activity.setContentView(loadlayout(layout))
-- main_title_id.setText("AliyunPlayer")

-- 该源码无法直接使用，需要打包后才可使用。
-- 移植到自己项目时需要把工程下 /extend/lib/ 文件夹复制到自己的项目/extend 目录下再进行打包。

--[[Author:Azure
官方文档:https://help.aliyun.com/document_detail/311525.html]]

-- 创建 AliyunPlayer
aliPlayer = AliPlayerFactory.createAliPlayer(activity);
-- 埋点日志上报功能默认开启，当 traceId 设置为 DisableAnalytics 时，则关闭埋点日志上报。当 traceId 设置为其他参数时，则开启埋点日志上报。
-- 建议传递 traceId，便于跟踪日志。traceId 为设备或用户的唯一标识符，通常为 imei 或 idfa 。
-- aliPlayer.setTraceId("traceId"); 

-- 此回调会在使用播放器的过程中，出现了任何错误，都会回调此接口
aliPlayer.setOnErrorListener(IPlayer.OnErrorListener {
    onError = function(errorInfo)
        errorCode = errorInfo.getCode(); -- 错误码
        errorMsg = errorInfo.getMsg(); -- 错误描述
        -- 出错后需要停止播放器
        aliPlayer.stop();
    end
})

-- 调用 aliPlayer.prepare() 方法后，播放器开始读取并解析数据。成功后，会回调此接口
aliPlayer.setOnPreparedListener(IPlayer.OnPreparedListener {
    onPrepared = function()
        -- 开始播放
        aliPlayer.start();
    end
});

-- 播放完成之后，就会回调到此接口
aliPlayer.setOnCompletionListener(IPlayer.OnCompletionListener {
    onCompletion = function()
        -- 停止播放
        aliPlayer.stop();
    end
});

-- 监听播放器中的一些信息，包括：当前进度、缓存位置等等
aliPlayer.setOnInfoListener(IPlayer.OnInfoListener {
    onInfo = function(infoBean)
        code = infoBean.getCode(); -- 信息码
        msg = infoBean.getExtraMsg(); -- 信息内容
        value = infoBean.getExtraValue(); -- 信息值

        -- 当前进度：InfoCode.CurrentPosition
        -- 当前缓存位置：InfoCode.BufferedPosition
    end
});

-- 播放器的加载状态, 网络不佳时，用于展示加载画面
aliPlayer.setOnLoadingStatusListener(IPlayer.OnLoadingStatusListener {
    onLoadingBegin = function()
        -- 开始加载(画面和声音不足以播放)
    end,
    onLoadingProgress = function(percent, netSpeed)
        -- 加载进度(百分比和网速)
    end,
    onLoadingEnd = function()
        -- 结束加载(画面和声音可以播放)
    end
});

-- 设置显示View
surface_view.getHolder().addCallback(SurfaceHolder.Callback {
    surfaceCreated = function(holder)
        aliPlayer.setSurface(holder.getSurface());
    end,
    surfaceChanged = function(holder, format, width, height)
        aliPlayer.surfaceChanged();
    end,
    surfaceDestroyed = function(holder) aliPlayer.setSurface(nil); end
});

-- 播放视频
-- local url="https://vip.lz-cdn14.com/20220716/4878_e679da3c/index.m3u8"
urlSource = UrlSource();
urlSource.setUri(url);
aliPlayer.setDataSource(urlSource);
aliPlayer.setAutoPlay(true); -- 自动播放
aliPlayer.prepare();

parameter = 0
function onKeyDown(code, event)
    if string.find(tostring(event), "KEYCODE_BACK") ~= nil then
        if parameter + 2 > tonumber(os.time()) then
            if aliPlayer then
                -- 退出停止播放
                aliPlayer.stop()
            end
            activity.finish()
        else
            print("再按一次返回键退出")
            parameter = tonumber(os.time())
        end
        return true
    end
end
