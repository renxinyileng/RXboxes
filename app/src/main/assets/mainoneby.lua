require("import")
initApp = true
import "jesse205"
import "android.app.*"
import "android.widget.*"
import "android.os.*"
import "android.view.*"
import "aria2.main"
开启服务()
--StatService.start(this)
--activity.setTitle(R.string.app_name)
--activity.setTitle("")
actionBar = activity.getSupportActionBar()
actionBar.hide()
--actionBar.setTitle("")
--this.setTitle("")
--function onCreateOptionsMenu(menu)
--    local inflater = activity.getMenuInflater()
--    inflater.inflate(R.menu.menu_main, menu)
--end
--function onOptionsItemSelected(item)
--    local id = item.getItemId()
--    local Rid = R.id
--    local aRid = android.R.id
--    if id == aRid.home then
--        activity.finish()
--    elseif id == Rid.menu_more_watch_fireworks then
--
--    elseif id == Rid.menu_more_about then
--
--    end
--end
数据存储 = "/data/data/" .. tostring(activity.getPackageName()) .. "/"
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
import "android.content.*"
import "androidx.core.widget.NestedScrollView"
import "com.google.android.material.appbar.AppBarLayout"
import "com.google.android.material.appbar.CollapsingToolbarLayout"
Toolbar = luajava.bindClass "androidx.appcompat.widget.Toolbar"
CoordinatorLayout = luajava.bindClass "androidx.coordinatorlayout.widget.CoordinatorLayout"
ColorStateList = luajava.bindClass "android.content.res.ColorStateList"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
local Animation = luajava.bindClass "android.view.animation.Animation"
import "androidx.viewpager.widget.ViewPager"
import "android.animation.LayoutTransition"
import "android.graphics.drawable.GradientDrawable"
local MaterialCardView = luajava.bindClass "com.google.android.material.card.MaterialCardView"
local RotateAnimation = luajava.bindClass "android.view.animation.RotateAnimation"
local DrawerLayout = luajava.bindClass "androidx.drawerlayout.widget.DrawerLayout"

function 状态栏高度()
    if Build.VERSION.SDK_INT >= 19 then
        resourceId = activity.getResources().getIdentifier("status_bar_height", "dimen", "android")
        return activity.getResources().getDimensionPixelSize(resourceId)
    else
        return 0
    end
end
page1 = {
    LinearLayout;
    layout_height = "match_parent";
    gravity = "center";
    layout_width = "match_parent";
    orientation = "vertical";
    {
        TextView;
        textSize = "16sp";
        text = "Hello AndLua+";
    };
};
page2 = {
    LinearLayout;
    layout_height = "match_parent";
    gravity = "center";
    layout_width = "match_parent";
    orientation = "vertical";
    {
        TextView;
        textSize = "16sp";
        text = "Hello AndLua+";
    };
};
page3 = {
    LinearLayout;
    layout_height = "match_parent";
    gravity = "center";
    layout_width = "match_parent";
    orientation = "vertical";
    {
        WebView;
        layout_width = "-1",
        layout_height = "-1",
        id = "aria2web",
    },
};
page4 = {
    LinearLayout;
    layout_height = "match_parent";
    gravity = "center";
    layout_width = "match_parent";
    orientation = "vertical";
    {
        WebView;
        layout_width = "-1",
        layout_height = "-1",
        id = "web",
    },
};
layout = {
    FrameLayout;
    layout_width = "fill";
    layout_height = "fill";
    {
        DrawerLayout;
        id = "Drawer";
        layout_width = "fill";
        layout_height = "fill";
        BackgroundColor = 0xffFFFBFA,
        {
            MaterialCardView;
            strokeColor = "#944747", --边框颜色
            layout_width = "fill";
            elevation = "0dp";
            id = "card3";

            layout_height = "fill";
            CardBackgroundColor = "#F1F0FA";
        }, --主页背后的一个卡片
        {
            MaterialCardView;
            Elevation = 0,
            strokeColor = "#296b3d",
            layout_width = "fill";
            elevation = "0dp";
            id = "card2";
            layout_height = "fill";
            CardBackgroundColor = "#F1F0FA";
        }, --主页背后的一个卡片
        {
            MaterialCardView; --主页卡片
            strokeColor = "#565899",
            layout_width = "fill";
            elevation = "0dp";
            id = "yj";
            layout_height = "fill";
            CardBackgroundColor = "#F1F0FA";


            --主页布局↓
            { NestedScrollView,
              backgroundColor = 0xffF1F0FA;
              layout_width = -1;
              layout_height = -1;
                --下面这个是将布局放在标题栏下面
              layout_behavior = "appbar_scrolling_view_behavior";
              { LinearLayout;
                orientation = "vertical";
                layout_height = "fill";
                layout_width = "fill";
                {
                    LinearLayout;
                    orientation ="horizontal",
                    layout_height="60dp",
                    layout_width="fill",
                    {
                        TextView;
                        layout_width= "-2",
                        layout_height ="-2",
                        text="测试";
                    }
                };
                {
                    LinearLayout;
                    layout_width = "match_parent";
                    layout_weight = "1";
                    orientation = "vertical";
                    layout_height = "100%h"; --输入fill可能会出现白条
                    { PageView;
                      layout_width = "match_parent";
                      layout_weight = "match_parent";
                      id = "pagev";
                    }
                },
              };
            };
        }, --下面是侧滑布局
        {
            LinearLayout;
            layout_gravity = "left";
            layout_width = "60%w";
            BackgroundColor = "#00000000";
            id = "左侧滑";
            layout_height = "fill";
            orientation = "vertical";
            {
                LinearLayout;
                layout_marginTop = "40%h",
                layout_width = "fill";
                background = "#00000000";
                id = "侧滑打开布局";
                layout_height = "50%h";
                orientation = "vertical";
                {
                    TextView;
                    layout_marginTop = "5%h";
                    layout_gravity = "center";
                    id = "lookbook";
                    TextSize = "8sp";
                    TextColor = "0xFF000000";
                    text = "Look Book";

                };
                {
                    TextView;
                    layout_marginTop = "5%h";
                    layout_gravity = "center";
                    id = "Tool";
                    TextSize = "8sp";
                    TextColor = "0xFF000000";
                    text = "Tool";
                };
                {
                    TextView;
                    layout_marginTop = "5%h";
                    layout_gravity = "center";
                    id = "MY";
                    TextSize = "8sp";
                    TextColor = "0xFF000000";
                    text = "MY";

                };
            },
        };
    }
}

--以上是加载布局文件
activity.setContentView(loadlayout(layout))
--加载滑动布局
adp = ArrayPageAdapter()
pagev.setAdapter(adp)
adp.add(loadlayout(page1))
adp.add(loadlayout(page2))
adp.add(loadlayout(page3))
adp.add(loadlayout(page4))

Drawer.setScrimColor(0)
--隐藏动画效果

--获取页面根布局
local lay = Drawer.getChildAt(1)

--监听侧滑滑动事件
local pio = this.getWidth() * 0.062

--额一些变量名称，不要在意名字
额 = 0
俄 = 0
呃 = 0

Drawer.setDrawerListener(DrawerLayout.DrawerListener {
    onDrawerSlide = function(v, i)
        yj.setScaleX(1 - i / 8).setScaleY(1 - i / 8)--页面缩放
        yj.setTranslationX((({ 0, 0, 1, 0, -1 })[v.LayoutParams.gravity]) * (i * 8 * pio))--页面位移(其中那段奇怪的表是用于判断位移方向，不过依然仅支持左右侧滑)
        yj.setRadius(100 * i)
        yj.strokeWidth = i * 3

        card2.setScaleX(1 - i / 8).setScaleY(1 - i / 8)--页面缩放
        card2.setTranslationX((({ 0, 0, 1, 0, -1 })[v.LayoutParams.gravity]) * (i * 7.2 * pio))--页面位移(其中那段奇怪的表是用于判断位移方向，不过依然仅支持左右侧滑)
        card2.setRadius(100 * i)
        card2.strokeWidth = i * 3

        card3.setScaleX(1 - i / 8).setScaleY(1 - i / 8)--页面缩放
        card3.setTranslationX((({ 0, 0, 1, 0, -1 })[v.LayoutParams.gravity]) * (i * 6.3 * pio))--页面位移(其中那段奇怪的表是用于判断位移方向，不过依然仅支持左右侧滑)
        card3.setRadius(100 * i)
        card3.strokeWidth = i * 3

        人 = i * 10
        惹 = i * 6.5
        睿 = i * 2

        Rotate_right = RotateAnimation(额, 人,
                Animation.RELATIVE_TO_SELF, 0.5,
                Animation.RELATIVE_TO_SELF, 0.5)
        Rotate_right.setDuration(100)
        Rotate_right.setFillAfter(true)
        yj.startAnimation(Rotate_right)

        Rotate_right = RotateAnimation(俄, 惹,
                Animation.RELATIVE_TO_SELF, 0.5,
                Animation.RELATIVE_TO_SELF, 0.5)
        Rotate_right.setDuration(100)
        Rotate_right.setFillAfter(true)

        card2.startAnimation(Rotate_right)

        Rotate_right = RotateAnimation(呃, 睿,
                Animation.RELATIVE_TO_SELF, 0.5,
                Animation.RELATIVE_TO_SELF, 0.5)
        Rotate_right.setDuration(100)
        Rotate_right.setFillAfter(true)

        card3.startAnimation(Rotate_right)

        --保存变量，连贯动画
        额 = 人
        俄 = 惹
        呃 = 睿

    end })

activity.getWindow().setFormat(PixelFormat.TRANSLUCENT);
id, wv, webView = web, web, web
webSettings = wv.getSettings();
webSettings.setJavaScriptEnabled(true);
webSettings.setTextZoom(100)
web.getSettings().setSafeBrowsingEnabled(true)
web.getSettings().setGeolocationEnabled(true)
--function onKeyDown(keyCode, event)
--    if (keyCode == KeyEvent.KEYCODE_BACK and wv.canGoBack()) then
--        id.goBack()
--        return true
--    end
--    return false
--end
UiManagergetFragmentgetWebView = web
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
web.loadUrl("https://rxteam.xyz") --加载打包文件
webSettings = aria2web.getSettings();
webSettings.setJavaScriptEnabled(true);
webSettings.setTextZoom(100)
aria2web.getSettings().setSafeBrowsingEnabled(true)
aria2web.getSettings().setGeolocationEnabled(true)
aria2web.setNetworkAvailable(true)
aria2web.getSettings().setDisplayZoomControls(false)
aria2web.getSettings().setSupportZoom(true)
aria2web.getSettings().setDomStorageEnabled(true)
aria2web.getSettings().setDatabaseEnabled(true)
aria2web.getSettings().setUseWideViewPort(true)
aria2web.getSettings().setAllowFileAccess(true)
aria2web.getSettings().setBuiltInZoomControls(true)
aria2web.getSettings().setLoadWithOverviewMode(true)
aria2web.getSettings().setLoadsImagesAutomatically(true)
aria2web.getSettings().setSaveFormData(true)
aria2web.getSettings().setAllowContentAccess(true)
aria2web.getSettings().setJavaScriptEnabled(true)
aria2web.getSettings().supportMultipleWindows()
aria2web.getSettings().setUseWideViewPort(true)
aria2web.getSettings().setCacheMode(aria2web.getSettings().LOAD_CACHE_ELSE_NETWORK)
aria2web.getSettings().setLayoutAlgorithm(aria2web.getSettings().LayoutAlgorithm.SINGLE_COLUMN)
aria2web.setLayerType(View.LAYER_TYPE_HARDWARE, nil)
aria2web.getSettings().setPluginsEnabled(true)
aria2web.setOverScrollMode(WebView.OVER_SCROLL_NEVER)
aria2web.getSettings().setJavaScriptCanOpenWindowsAutomatically(true)
aria2web.getSettings().setBlockNetworkImage(false)
aria2web.getSettings().setAllowFileAccess(true)
if Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN then
    aria2web.getSettings().setAllowFileAccessFromFileURLs(true)
    aria2web.getSettings().setAllowUniversalAccessFromFileURLs(true)
end
aria2web.getSettings().setNeedInitialFocus(true)
aria2web.getSettings().setDefaultTextEncodingName("UTF-8")
aria2web.getSettings().setDefaultFontSize(16)
aria2web.getSettings().setMinimumFontSize(12)
aria2web.getSettings().setGeolocationEnabled(true)
if Build.VERSION.SDK_INT >= 20 then
    aria2web.setWebContentsDebuggingEnabled(true)
end
setting = aria2web.getSettings()
setting.setUseWideViewPort(true)
setting.setLoadWithOverviewMode(true)
setting.setBuiltInZoomControls(false)
aria2web.loadUrl("file://"..activity.getLuaDir().."/aria2/www/index.html") --加载打包文件

--隐藏功能有彩蛋
--import "android.content.Intent"
--import "rx.team.renxinyileng.box.MainActivity"
--activity.startActivity(Intent(this,MainActivity.getClass()))
lookbook.onClick=function()
    activity.newActivity("Pen_fun_Pavilion/Pen_fun_Pavilion")
end