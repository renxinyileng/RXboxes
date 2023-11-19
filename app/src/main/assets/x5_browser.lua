require("import")
import("android.widget.*")
import("android.view.*")
import("android.os.*")
import("android.app.*")
数据存储 = activity.getFilesDir().getAbsolutePath() .. "/"
import "android.graphics.PixelFormat"
import "com.tencent.smtt.sdk.WebViewClient"
import "com.tencent.smtt.sdk.WebView"
import "com.tencent.smtt.export.external.*"
import "com.tencent.smtt.export.external.extension.interfaces.*"
import "com.tencent.tbs.video.interfaces.*"
import "com.tencent.smtt.export.external.proxy.*"
import "com.tencent.smtt.export.external.extension.proxy.*"
import "com.tencent.smtt.export.external.interfaces.ConsoleMessage"
import "com.tencent.smtt.sdk.*"
import "com.x5.WebView.*"
import "java.util.HashMap"
import "rxteam"
urlpath, Landscape_and_portrait, webViewUAmenu = ...

if webViewUAmenu then
    activity.setTitle("")
end
local window = activity.getWindow();
window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
xpcall(function()
    lp = window.getAttributes();
    lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
    window.setAttributes(lp);
end, function(e)
end)
activity.setRequestedOrientation(Landscape_and_portrait) --横屏0--竖屏1
layout = {
    LinearLayout;
    layout_width = "-1",
    layout_height = "-1",
    orientation = "vertical",
    {
        WebView;
        layout_width = "-1",
        layout_height = "-1",
        id = "UiManagergetFragmentgetWebView",
    },
}
activity.setContentView(loadlayout(layout))
activity.getWindow().setFormat(PixelFormat.TRANSLUCENT);
id, wv, webView = web, web, web
webSettings = wv.getSettings();
webSettings.setJavaScriptEnabled(true);
webSettings.setTextZoom(100)
web.getSettings().setSafeBrowsingEnabled(true)
web.getSettings().setGeolocationEnabled(true)
function onKeyDown(keyCode, event)
    if (keyCode == KeyEvent.KEYCODE_BACK and wv.canGoBack()) then
        id.goBack()
        return true
    end
    return false
end

import("android.os.Build")-- Set a WebViewClient to listen for page title changes
UiManagergetFragmentgetWebView.setWebViewClient(object : WebViewClient() {
    override fun onReceivedTitle(view: WebView?, title: String?) {
        super.onReceivedTitle(view, title)
        // Set the activity title to the page title
        activity.title = title
    }
})
--Note: This code is written in Kotlin, not Lua.
UiManagergetFragmentgetWebView.setNetworkAvailable(true)
UiManagergetFragmentgetWebView.getSettings().setDisplayZoomControls(false)
UiManagergetFragmentgetWebView.getSettings().setSupportZoom(true)
UiManagergetFragmentgetWebView.getSettings().setDomStorageEnabled(true)
UiManagergetFragmentgetWebView.getSettings().setDatabaseEnabled(true)
UiManagergetFragmentgetWebView.getSettings().setUseWideViewPort(true)
UiManagergetFragmentgetWebView.getSettings().setAllowFileAccess(true)
UiManagergetFragmentgetWebView.getSettings().setBuiltInZoomControls(true)
UiManagergetFragmentgetWebView.getSettings().setLoadWithOverviewMode(true)
UiManagergetFragmentgetWebView.getSettings().setLoadsImagesAutomatically(true)
UiManagergetFragmentgetWebView.getSettings().setSaveFormData(true)
UiManagergetFragmentgetWebView.getSettings().setAllowContentAccess(true)
UiManagergetFragmentgetWebView.getSettings().setJavaScriptEnabled(true)
UiManagergetFragmentgetWebView.getSettings().supportMultipleWindows()
UiManagergetFragmentgetWebView.getSettings().setUseWideViewPort(true)
UiManagergetFragmentgetWebView.getSettings().setCacheMode(UiManagergetFragmentgetWebView.getSettings().LOAD_CACHE_ELSE_NETWORK)
UiManagergetFragmentgetWebView.getSettings().setLayoutAlgorithm(UiManagergetFragmentgetWebView.getSettings().LayoutAlgorithm.SINGLE_COLUMN)
UiManagergetFragmentgetWebView.setLayerType(View.LAYER_TYPE_HARDWARE, nil)
UiManagergetFragmentgetWebView.getSettings().setPluginsEnabled(true)
UiManagergetFragmentgetWebView.setOverScrollMode(WebView.OVER_SCROLL_NEVER)
UiManagergetFragmentgetWebView.getSettings().setJavaScriptCanOpenWindowsAutomatically(true)
UiManagergetFragmentgetWebView.getSettings().setBlockNetworkImage(false)
UiManagergetFragmentgetWebView.getSettings().setAllowFileAccess(true)
if Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN then
    UiManagergetFragmentgetWebView.getSettings().setAllowFileAccessFromFileURLs(true)
    UiManagergetFragmentgetWebView.getSettings().setAllowUniversalAccessFromFileURLs(true)
end
UiManagergetFragmentgetWebView.getSettings().setNeedInitialFocus(true)
UiManagergetFragmentgetWebView.getSettings().setDefaultTextEncodingName("UTF-8")
UiManagergetFragmentgetWebView.getSettings().setDefaultFontSize(16)
UiManagergetFragmentgetWebView.getSettings().setMinimumFontSize(12)
UiManagergetFragmentgetWebView.getSettings().setGeolocationEnabled(true)
if Build.VERSION.SDK_INT >= 20 then
    UiManagergetFragmentgetWebView.setWebContentsDebuggingEnabled(true)
end
setting = UiManagergetFragmentgetWebView.getSettings()
setting.setUseWideViewPort(true)
setting.setLoadWithOverviewMode(true)
setting.setBuiltInZoomControls(false)
web.loadUrl(urlpath) --加载打包文件
id.setWebViewClient(WebViewClient() {
    shouldOverrideUrlLoading = function(view, url)
        view.loadUrl(url)
        return true
    end,
    onPageStarted = function(view, url, favicon)
    end,
    onReceivedError = function(var1, var2, var3, var4)
        提示("网页加载失败")
        return false
    end
})
if webViewUAmenu then
    function onCreateOptionsMenu(menu)
        tab = { "移动端UA", "桌面端UA", "塞班UA", "神秘UA", "QQ浏览器UA" }
        for k, v in ipairs(tab) do
            menu.add(tab[k])
        end
    end
    function 刷新网页(id)
        id.loadUrl(tostring(id.getUrl()))
    end
    function onOptionsItemSelected(item)
        v = item.Title
        if v == "移动端UA" then
            --提示("移动端UA")
            webView.getSettings().setUserAgentString("Mozilla/5.0 (Linux; Android 7.1.2; Build/NJH47F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.109 Safari/537.36")
            刷新网页(webView)
        end
        if v == "桌面端UA" then
            --提示("桌面端UA")
            webView.getSettings().setUserAgentString("User-Agent:Mozilla/5.0 (Windows NT 6.1; rv:2.0.1) Gecko/20100101 Firefox/4.0.1")
            刷新网页(webView)
        end
        if v == "塞班UA" then
            --提示("塞班UA")
            webView.getSettings().setUserAgentString("user-agent = Mozilla/5.0 (SymbianOS/9.4; Series60/5.0 Nokia5800d-1/60.0.003; Profile/MIDP-2.1 Configuration/CLDC-1.1 ) AppleWebKit/533.4 (KHTML, like Gecko) NokiaBrowser/7.3.1.33 Mobile Safari/533.4 3gpp-gba")
            刷新网页(webView)
        end
        if v == "神秘UA" then
            --提示("神秘UA")
            webView.getSettings().setUserAgentString("user-agent = Mozilla/5.0Dalvik/2( Linux; U;NEM-AL10Build/HONORNEM-AL10; Youku;7.1.4;)AppleWebKit/537.36( KHTML, like Gecko)Version/4.0Safari/537.36( Baidu;P16.0)iPhone/7.1Android/8.0")
            刷新网页(webView)
        end
        if v == "QQ浏览器UA" then
            --提示("QQ浏览器UA")
            webView.getSettings().setUserAgentString("User-Agent: MQQBrowser/26 Mozilla/5.0 (Linux; U; Android 2.3.7; zh-cn; MB200 Build/GRJ22; CyanogenMod-7) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1")
            刷新网页(webView)
        end
    end

end