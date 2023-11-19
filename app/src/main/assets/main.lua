-- 导入必要的库
require("import")
require("rxteam")
import("sha256")
import "android.app.*"
import "android.widget.*"
import "android.os.*"
import "android.view.*"
-- Import the necessary libraries
local socket = require("socket")

-- Define the function to test TCP latency
function test_tcp_latency(server_ip, server_port)
    -- Create a new TCP socket
    local tcp_socket = socket.tcp()
    
    -- Set the timeout to 1 second
    tcp_socket:settimeout(1)
    
    -- Connect to the server
    local connect_start_time = socket.gettime()
    local connect_result, connect_error = tcp_socket:connect(server_ip, server_port)
    local connect_end_time = socket.gettime()
    
    -- If there was an error connecting, return it
    if not connect_result then
        return nil, connect_error
    end
    
    -- Calculate the latency and return it
    local latency = connect_end_time - connect_start_time
    return latency
end

-- Call the function to test the TCP latency of a server with IP address "192.168.1.1" and port 80
local latency, error_message = test_tcp_latency("8.8.8.8", 53)

-- Print the result
if latency then
    -- print("TCP latency:", latency)
    network=true
else
    -- print("Error:", error_message)
    network=false
end

-- Note: Replace "192.168.1.1" and 80 with the IP address and port of the server you want to test.
thread(function()
    require("import")
    --Android动态权限申请,回调和检查
    --定义请求码
    local permissionRequestCode = 10
    --申请权限
    function requestPermissions(permissions, requestCode)
        local ActivityCompat = luajava.bindClass "androidx.core.app.ActivityCompat"
        return ActivityCompat.requestPermissions(activity, permissions, requestCode);
    end
    --申请权限的回调在这里执行
    onRequestPermissionsResult = function(requestCode, permissions, grantResults)
        local PackageManager = luajava.bindClass "android.content.pm.PackageManager"
        --判断是不是自己的权限申请
        if requestCode == permissionRequestCode then
            local count = 0
            for i = 0, #permissions - 1 do
                if grantResults[i] == PackageManager.PERMISSION_GRANTED then
                    --print(permissions[i].."权限通过")
                    count = count + 1
                else
                    --print(permissions[i].."权限拒绝")
                end
            end
            print("申请了" .. #permissions .. "个权限，通过了" .. count .. "个权限")
        end
    end
    --示例
    --要申请的权限列表，请写成常量以免自己写错
    --所有的权限常量定义在Manifest的内部类permission里，写法如下
    local Manifest = luajava.bindClass "android.Manifest"

    --以储存权限为例
    local requirePermissions = {
        Manifest.permission.FOREGROUND_SERVICE,
        Manifest.permission.WRITE_EXTERNAL_STORAGE,
        Manifest.permission.INTERNET,
        Manifest.permission.WAKE_LOCK,
        Manifest.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,

    }
    --发起请求
    requestPermissions(requirePermissions, permissionRequestCode)
    --检查权限
    function checkPermission(permission)
        return 0 == activity.checkSelfPermission(permission)
    end
    --单纯检查一下有没有指定权限
    --local flag = checkPermission(Manifest.permission.READ_EXTERNAL_STORAGE)
    --print("READ_EXTERNAL_STORAGE检查结果"..tostring(flag))
end)

隐藏标题栏_androidx()
--import "android.content.Intent"
--import "rx.team.renxinyileng.box.MainActivity"
--activity.startActivity(Intent(this, MainActivity().getClass()))

--服务器运行网页
import "java.io.File"
import "com.LuaGoMyServer.LuaGoMyServer"
import "com.LuaGoMyServer.MainActivity"
import "com.LuaGoMyServer.SimpleServer"
xpcall(function()
    server = LuaGoMyServer(tonumber(8080), File(activity.getLuaDir() .. '/aria2NGGUI/'));
    server.start(4000, false);
end, function(e)
    print("错误" .. e)
end)
import "android.content.pm.PackageManager"
--获取包管理器
local pm = activity.getPackageManager();
local pm = pm.getPackageInfo(activity.getPackageName(), PackageManager.GET_SIGNATURES).signatures[0].hashCode()
sha256sign = sha256.sha256(tostring(pm))
--print(sha256sign)
if (File(数据存储 .. tostring(sha256sgin)).exists() == false) then
    提示("by:人心已冷\nqq:2713359049")
    File(数据存储 .. sha256sign).mkdir()
    import "android.os.SystemProperties"
    --[[  if tostring(SystemProperties.get("ro.product.cpu.abi")) == "arm64-v8a" and tostring(io.popen("uname -m"):read("*l")) == "aarch64" then
          提示("符合aric2软件的开启条件正在尝试开启")
          File(tostring(Environment.getExternalStorageDirectory().getAbsolutePath() .. "/Download/RX盒子/aria2ini/")).mkdir()
          io.popen("chmod 777 " .. activity.getLuaDir() .. "/www/aria2/android/aria2c"):read("*all")
          print(io.popen("uname -m"):read("*l"))
          --print(APPassets目录)
          下载路径 = tostring(Environment.getExternalStorageDirectory()) .. "/Download/RX盒子/aria2"
          会话文件路径 = tostring(activity.getLuaDir("/aria2/aria2.session")) --任务保存文件。不用修改
          conf = tostring("\n" .. "dir=" .. 下载路径 .. "\n" .. "input-file=" .. 会话文件路径 .. "\n" .. "save-session=" .. 会话文件路径)
          io.open(tostring(activity.getLuaDir("/aria2/aria2.conf")), "a+"):write(conf):close()
          print(io.popen("/data/data/rx.team.renxinyileng.box/files/www/aria2/android/aria2c --conf-path=/data/data/rx.team.renxinyileng.box/files/www/aria2/aria2.conf -D"):read("*all"))
      else
          提示("不符合aria2软件的开启条件")
      end]]
end
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
import "androidx.viewpager.widget.ViewPager"
import "android.animation.LayoutTransition"
import "android.graphics.drawable.GradientDrawable"
local DrawerLayout = luajava.bindClass "androidx.drawerlayout.widget.DrawerLayout"
-- 为了清除X5浏览器缓存，我们需要访问WebView的缓存并清除它。
-- 首先，我们需要初始化WebView并启用其缓存。
-- 然后，我们可以调用clearCache()方法来清除缓存。
-- 初始化WebView
local webView = WebView(activity)
-- 启用缓存
webView.settings.cacheMode = WebSettings.LOAD_DEFAULT
-- 清除缓存
webView.clearCache(true)  -- true表示我们还清除磁盘上的缓存文件
-- 最后，我们可以销毁WebView以释放其资源
webView.destroy()
map = HashMap();
map.put(TbsCoreSettings.TBS_SETTINGS_USE_SPEEDY_CLASSLOADER, true);
map.put(TbsCoreSettings.TBS_SETTINGS_USE_DEXLOADER_SERVICE, true);
QbSdk.initTbsSettings(map);
function 状态栏高度()
    if Build.VERSION.SDK_INT >= 19 then
        resourceId = activity.getResources().getIdentifier("status_bar_height", "dimen", "android")
        return activity.getResources().getDimensionPixelSize(resourceId)
    else
        return 0
    end
end
page1={
    LinearLayout;
    orientation = "vertical";
    layout_width = "fill";
    background = "#ffeeeeee";
    layout_height = "fill";
    {
        LinearLayout;
        layout_width = "fill";
        layout_height = "wrap";
        {
            EditText;
            layout_width = "0dp";
            layout_weight = "1";
            hint = "Search";
            id = "search_box";
        };
        {
            Button;
            layout_width = "wrap";
            text = "Search";
            onClick = function()
                search()
            end;
        };
    };
    {
        ListView;
        DividerHeight = 1;
        layout_width = "fill";
        layout_height = "fill";
        layout_margin = "20dp";
        verticalScrollBarEnabled = false;
        id = "list";
    };
};
page2 = {
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
page3 = { LinearLayout;
          layout_width = "-1",
          layout_height = "-1",
          orientation = "vertical",
          {
              EditText;
              layout_width = "-1",
              layout_height = "-2",
              id = "edit2",
              text = "",
              gravity = "center",
          },
          {
              Button;
              layout_width = "-1",
              layout_height = "-2",
              text = "查询",
              id = "button",
          },
          {
              ScrollView;
              layout_width = "-1",
              layout_height = "-1",
              {
                  LinearLayout;
                  layout_width = "-1",
                  layout_height = "-1",
                  orientation = "vertical",
                  {
                      TextView;
                      layout_width = "-1",
                      layout_height = "-2",
                      text = "",
                      id = "text",
                  },
              },
          },
}
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
page5 = {
    LinearLayout;
    orientation = "vertical";
    layout_height = "-1";
    layout_width = "-1";
    {
        LinearLayout;
        orientation = "horizontal";
        layout_height = "-2";
        layout_width = "-1";
        {
            Button;
            text = "内部储存";
            --layout_width = "match_parent";
            id = "mButton1";
        };
        {
            Button;
            text = "上级目录";
            --layout_width = "match_parent";
            id = "mButton2";
        };
        {
            Button;
            text = "打开指定链接";
            id = "openurl";
        };
    };
    {
        TextView;
        id = "mTextView1";
        layout_width = "match_parent";
        layout_height = "-2";
    };
    {
        ListView;
        layout_height = "match_parent";
        layout_width = "match_parent";
        id = "mListView1";
    };
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
            LinearLayout;
            orientation = "vertical";
            layout_height = "fill";
            layout_width = "fill";
            --顶部布局文件
            {
                LinearLayout;
                orientation = "horizontal",
                layout_height = "56dp",
                layout_width = "fill",
                {
                    CardView;
                    layout_height = "56dp";
                    backgroundColor = "0xFF2196F3";
                    radius = "0dp";
                    CardElevation = "3dp";
                    layout_width = "match_parent";
                    {
                        LinearLayout;
                        orientation = "horizontal";
                        gravity = "center";
                        layout_height = "56dp";
                        layout_width = "match_parent";
                        {
                            LinearLayout;
                            layout_height = "match_parent";
                            gravity = "center";
                            {
                                CardView;
                                layout_height = "80dp";
                                PreventCornerOverlap = false;
                                layout_marginLeft = "-15dp";
                                CardElevation = "0dp";
                                background = "#00000000";
                                radius = "40dp";
                                UseCompatPadding = false;
                                layout_width = "80dp";
                                {
                                    ImageView;
                                    layout_height = "match_parent";
                                    layout_margin = "-10dp";
                                    id = "btn";
                                    background = "#00000000";
                                    padding = "38dp";
                                    src = "icon/navnav.png";
                                    layout_width = "match_parent";
                                };
                            };
                        };
                        {
                            TextView;
                            gravity = "center|left";
                            singleLine = true;
                            layout_marginLeft = "-15dp";
                            layout_width = "match_parent";
                            text = activity.getTitle();
                            id = "title";
                            textSize = "19dp";
                            ellipsize = "end";
                            layout_height = "match_parent";
                            layout_weight = "1";
                            textColor = "#FFFFFF";
                        };
                        {
                            CardView;
                            layout_height = "65dp";
                            PreventCornerOverlap = false;
                            CardElevation = "0dp";
                            layout_marginRight = "-10dp";
                            background = "#00000000";
                            radius = "33dp";
                            UseCompatPadding = false;
                            layout_width = "65dp";
                            {
                                TextView;
                                layout_height = "0dp";
                                id = "menu";
                                layout_marginLeft = "-145dp";
                                layout_marginTop = "10dp";
                                layout_width = "0dp";
                            };
                            {
                                ImageView;
                                layout_height = "match_parent";
                                layout_margin = "-10dp";
                                id = "btn3";
                                background = "#00000000";
                                padding = "31dp";
                                src = "icon/abc_ic_menu_moreoverflow_mtrl_alpha.png";
                                layout_width = "match_parent";
                            };
                        };
                    };
                };
            };
            --滑动布局
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
                    id = "readcomics";
                    TextSize = "8sp";
                    TextColor = "0xFF000000";
                    text = "Read Comics";
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
adp.add(loadlayout(page5))
adp.add(loadlayout(page1))
adp.add(loadlayout(page3))
adp.add(loadlayout(page2))
adp.add(loadlayout(page4))
Drawer.setScrimColor(0)
--page1运行配置
function search()
    local keyword = search_box.Text
    local results = {}
    for i = 1, adp.getCount() do
        local item = adp.Item(i)
        if item.标题:find(keyword) or item.内容:find(keyword) then
            table.insert(results, item)
        end
    end
    adp.clear()
    for i = 1, #results do
        adp.add(results[i])
    end
end
local layout2 = {
    LinearLayout;
    layout_height = "fill";
    layout_width = "fill";
    {
        CardView;
        layout_width = "match_parent";
        layout_margin = "10dp";
        {
            LinearLayout;
            orientation = "vertical";
            layout_width = "match_parent";
            {
                TextView;
                layout_marginLeft = "20dp";
                textColor = "0xFF000000";
                layout_width = "match_parent";
                layout_marginRight = "20dp";
                id = "标题";
                layout_marginTop = "20dp";
            };
            {
                TextView;
                textColor = "0xFF000000";
                layout_width = "match_parent";
                id = "内容";
                layout_margin = "20dp";
            };
        };
    };
};
adp = LuaAdapter(activity, layout2)
function addlb(title, m3u8)
    adp.add { 标题 = tostring(title), 内容 = tostring(m3u8) }
end
function Parsing_M3u()
    require "import"
    local file = io.open(activity.getApplicationInfo().dataDir .. "/m3u/TV-IPV4.m3u", "r")
    -- Check if the file exists
if file then
    -- Read the contents of the file
    local content = file:read("*all")
    file:close()
    for title, m3u8 in content:gmatch("#EXTINF:.-,(.-)\n(.-)\n") do
        call("addlb", tostring(title), tostring(m3u8))
    end
else
    提示("File does not exist")
end
end
thread(Parsing_M3u)
list.Adapter = adp
-- 简写列表的点击事件，使其更加简洁
list.onItemClick = function(parent, v, pos, id)
    -- 直接调用新的Activity，无需中间变量
    activity.newActivity("aliyun_player/aliyun_player", { v.Tag.内容.Text })
end
--page4运行配置
activity.getWindow().setFormat(PixelFormat.TRANSLUCENT);
web.getSettings().setJavaScriptEnabled(true);
web.getSettings().setTextZoom(100)
web.setNetworkAvailable(true)
web.getSettings().setDisplayZoomControls(false)
web.getSettings().setSupportZoom(true)
web.getSettings().setDomStorageEnabled(true)
web.getSettings().setDatabaseEnabled(true)
web.getSettings().setUseWideViewPort(true)
web.getSettings().setAllowFileAccess(true)
web.getSettings().setBuiltInZoomControls(true)
web.getSettings().setLoadWithOverviewMode(true)
web.getSettings().setLoadsImagesAutomatically(true)
web.getSettings().setSaveFormData(true)
web.getSettings().setAllowContentAccess(true)
web.getSettings().setJavaScriptEnabled(true)
web.getSettings().supportMultipleWindows()
web.getSettings().setUseWideViewPort(true)
web.getSettings().setCacheMode(web.getSettings().LOAD_CACHE_ELSE_NETWORK)
web.getSettings().setLayoutAlgorithm(web.getSettings().LayoutAlgorithm.SINGLE_COLUMN)
web.setLayerType(View.LAYER_TYPE_HARDWARE, nil)
web.getSettings().setPluginsEnabled(true)
web.setOverScrollMode(WebView.OVER_SCROLL_NEVER)
web.getSettings().setJavaScriptCanOpenWindowsAutomatically(true)
web.getSettings().setBlockNetworkImage(false)
web.getSettings().setAllowFileAccess(true)
if Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN then
    web.getSettings().setAllowFileAccessFromFileURLs(true)
    web.getSettings().setAllowUniversalAccessFromFileURLs(true)
end
web.getSettings().setNeedInitialFocus(true)
web.getSettings().setDefaultTextEncodingName("UTF-8")
web.getSettings().setDefaultFontSize(16)
web.getSettings().setMinimumFontSize(12)
web.getSettings().setGeolocationEnabled(true)
if Build.VERSION.SDK_INT >= 20 then
    web.setWebContentsDebuggingEnabled(true)
end
setting = web.getSettings()
setting.setUseWideViewPort(true)
setting.setLoadWithOverviewMode(true)
setting.setBuiltInZoomControls(false)
if network==true then
web.loadUrl("https://rxteam.xyz")
elseif network==false then
web.loadUrl("file:///android_asset/404.html")
end
--page2配置
aria2web.getSettings().setJavaScriptEnabled(true);
aria2web.getSettings().setTextZoom(100)
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
--aria2web.loadUrl("file://" .. activity.getLuaDir() .. "/aria2/www/index.html")
aria2web.loadUrl("http://127.0.0.1:8080")
--page3配置
JSON = import("json")
function jsontostring(str)
    str = string.gsub(str, "{", "")
    str = string.gsub(str, "}", "")
    str = string.gsub(str, ",", "\n")
    str = string.gsub(str, ":", "=")
    str = string.gsub(str, '"', "")
    return str
end

function stringToTable(str)
    local t = {}
    local function helper(line)
        local first, last = string.find(line, '=')
        if first then
            local key = string.sub(line, 1, first - 1)
            local value = string.sub(line, last + 1)
            t[key] = value
        end
    end

    for line in string.gmatch(str, '([^\n]*)\n') do
        helper(line)
    end
    return t
end

function json_tale(str)
    return stringToTable(jsontostring(str))
end
function 查询结果(data, zhi)
    if data.status == nil or data.status == "" or data.message == nil or data.message == "" then
        text.setText(str1 .. "\n" .. zhi .. "查询结果为空")
    else
        text.setText(str1 .. "\n" .. "状态:" .. data.status .. "\n" .. "查询结果:" .. data.message)
    end
end
button.onClick = function()
    local edit = edit2.getText().toString()
    if edit ~= "" or edit ~= nil then
        Http.get("https://zy.xywlapi.cc/lolname?name=" .. edit, function(code, data)
            data = stringToTable(jsontostring(data))
            if tostring(code) == "200" then
                str1 = text.getText()
                if data.qq == nil or data.qq == "" then
                    查询结果(data, "LOL网名查绑定QQ")
                else
                    text.setText(str1 .. "\n查询到的QQ账户：" .. data.qq)
                end
            end
        end)
        Http.get("https://zy.xywlapi.cc/qqlol?qq=" .. edit, function(code, data)
            data = stringToTable(jsontostring(data))
            if tostring(code) == "200" then
                str1 = text.getText()
                if data.name == nil or data.name == "" then
                    查询结果(data, "QQ查绑定LOL网名")
                else
                    if data.daqu == nil or data.daqu == "" then
                        text.setText(str1 .. "\n查询到的LOL游戏名：" .. data.name)
                    else
                        text.setText(str1 .. "\n查询到的账户名：" .. data.name .. "\n查询到的大区：" .. data.daqu)
                    end
                end
            end
        end)
        Http.get("https://zy.xywlapi.cc/qqphone?phone=" .. edit, function(code, data)
            data = stringToTable(jsontostring(data))
            if tostring(code) == "200" then
                str1 = text.getText()
                if data.qq == nil or data.qq == "" then
                    查询结果(data, "手机号查绑定QQ")
                else
                    text.setText(str1 .. "\n查询到的QQ账户：" .. data.qq)
                end
            end
        end)
        Http.get("https://zy.xywlapi.cc/qqapi?qq=" .. edit, function(code, data)
            data = stringToTable(jsontostring(data))
            if tostring(code) == "200" then
                str1 = text.getText()
                if data.phone == nil or data.phone == "" then
                    查询结果(data, "QQ查绑定手机号")
                else
                    text.setText(str1 .. "\n查询到的手机号：" .. data.phone)
                    return data.phone
                end
            end
        end)
        Http.get("https://zy.xywlapi.cc/wbapi?id=" .. edit, function(code, data)
            data = stringToTable(jsontostring(data))
            if tostring(code) == "200" then
                str1 = text.getText()
                if data.phone == nil or data.phone == "" then
                    查询结果(data, "微博查绑定手机号")
                else
                    text.setText(str1 .. "\n查询到的手机号：" .. data.phone)
                end
            end
        end)
        Http.get("https://zy.xywlapi.cc/wbphone?phone=" .. edit, function(code, data)
            data = stringToTable(jsontostring(data))
            if tostring(code) == "200" then
                str1 = text.getText()
                if data.id == nil or data.id == "" then
                    查询结果(data, "手机号查绑定微博")
                else
                    text.setText(str1 .. "\n查询到的微博ID：" .. data.id)
                end
            end
        end)
    else
        提示("请输入要查询的内容")
    end
end
--titlebar配置
import "android.graphics.Paint"
--设置title标题
title.getPaint().setFakeBoldText(true)
--添加menu菜单和控制事件
pop = PopupMenu(activity, menu)
menu = pop.Menu
--btn3= pop.Menu
menu.add("关于软件").onMenuItemClick = function(v)
    弹窗UI("关于软件", "本软件由人心已冷开发部分功能可在GitHub上找到相关开源项目，",
            "xxx.dismiss();", [[activity.newActivity("github_open_source_programs");xxx.dismiss();]], "查看开源程序",
            "知道了")
end
--左侧滑按钮
btn.onClick = function()
    Drawer.openDrawer(3)
end
--右上角显示配置
btn3.onClick = function()
    pop.show()
end
--左侧滑配置
lookbook.onClick = function()
    activity.newActivity("Pen_fun_Pavilion/Pen_fun_Pavilion")
end
readcomics.onClick = function()
    activity.newActivity("read_comics/read_comics")
end
--page5运行配置
local currentPath = tostring(Environment.getExternalStorageDirectory().getAbsolutePath()) .. "/"
function RefreshFileList()
    mTextView1.Text = currentPath
    if File(currentPath).listFiles() ~= nil then
        fileTable = luajava.astable(File(currentPath).listFiles())
        table.sort(fileTable, function(a, b)
            return (a.isDirectory() ~= b.isDirectory() and a.isDirectory()) or ((a.isDirectory() == b.isDirectory()) and a.Name < b.Name)
        end)
    else
        fileTable = {}
    end
    fileAdp = ArrayAdapter(activity, android.R.layout.simple_list_item_1)
    mListView1.setAdapter(fileAdp)
    for index, filePath in pairs(fileTable) do
        if filePath.isDirectory() then
            fileAdp.add(filePath.Name .. "/")
        else
            fileAdp.add(filePath.Name)
        end
    end
end
RefreshFileList()
mButton2.onClick = function()
    currentPath = tostring(File(currentPath).getParentFile()) .. "/"
    RefreshFileList()
    return true
end
mButton1.onClick = function()
    currentPath = tostring(Environment.getExternalStorageDirectory()) .. "/"
    RefreshFileList()
    return true
end
mListView1.onItemClick = function(p, v, i, s)
    local filename = tostring(v.Text)
    if File(currentPath .. "/" .. v.Text).isDirectory() then
        currentPath = currentPath .. v.Text
        RefreshFileList()
    else
        if get_file_type(filename) == "pdf" then
            activity.newActivity("pdfread", { currentPath .. filename })
        elseif get_file_type(filename) == "m3u8" or get_file_type(filename) == "mp4" then
            activity.newActivity("aliyun_player/MP4", { filename })
        else
            提示("暂时未适配的内容")
        end
    end
    return true
end
openurl.onClick = function()
    local page1 = { LinearLayout;
                    layout_width = "-1",
                    layout_height = "-1",
                    orientation = "vertical",
                    {
                        EditText;
                        layout_width = "-1",
                        layout_height = "-2",
                        id = "edittxt",
                        text = "",
                        gravity = "center",
                    },
                    {
                        Button;
                        layout_width = "-1",
                        layout_height = "-2",
                        text = "检索",
                        id = "jiansuobutton",
                    },
    }
    local xxx = AlertDialog.Builder(this)
    xxx.setView(loadlayout(page1))
    xxx.setCancelable(false)
    local xxx = xxx.show()
    jiansuobutton.onClick = function()
        local str = edittxt.getText().toString()
        if get_file_type(str) == "m3u8" or get_file_type(str) == "mp4" then
            activity.newActivity("aliyun_player/aliyun_player", { str })
            xxx.dismiss();
        elseif get_file_type(str) == "pdf" then
            activity.newActivity("pdfread", { str })
            xxx.dismiss();
        else
            提示("暂时未适配的内容")
            xxx.dismiss();
        end
    end
end
--注销变量
--web, id, wv, webView, webSettings, aria2web, lookbook, readcomics, pdfview, privacy_inquiry, button, setting = nil
-- activity.newActivity("iptv/iptvgithub")
