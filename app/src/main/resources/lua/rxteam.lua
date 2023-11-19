--传入两个参数:jar路径,dex路径
function JarToDex(jarPath, dexPath)
    local Mythread = thread(
            function(jarPath, dexPath)
                require "import"
                import "com.android.dx.command.Main"
                xpcall(function()
                    --调用主方法,传入参数
                    Main.main({
                        "--dex",
                        "--output=" .. dexPath,
                        jarPath
                    })
                    print("转换成功")
                end,
                        function(err)
                            print("转换异常" .. err)
                        end)
            end,
            jarPath, dexPath
    )
end

function 弹窗UI(标题, 内容, 确认事件, 取消事件, 按钮1, 按钮2, 高度)
    require "import"
    import "android.graphics.Typeface"
    弹窗框架 = {
        LinearLayout,
        orientation = 'vertical',
        layout_width = 'fill',
        layout_height = 'wrap',
        {
            CardView;
            layout_margin = '8dp';
            layout_gravity = 'center';
            elevation = '5dp';
            layout_width = '90%w';
            layout_height = 'fill';
            CardBackgroundColor = '0xfffFFFFF';
            radius = '10dp';
            {
                LinearLayout,
                gravity = 'center';
                orientation = 'vertical',
                layout_width = 'fill',
                layout_height = 'wrap',
                background = '#00FFFFFF',
                {
                    TextView;
                    layout_margin = '4%w';
                    gravity = 'center';
                    layout_width = 'fill';
                    layout_height = 'wrap';
                    textColor = '#eb000000';
                    text = 标题;
                    textSize = '16dp';
                };
                {
                    LinearLayout,
                    layout_padding = '10%';
                    gravity = 'left|center';
                    orientation = 'vertical',
                    layout_width = 'fill',
                    layout_height = 高度,
                    background = '#ffffffff',
                    {
                        ScrollView;
                        layout_width = 'fill';
                        layout_height = '50%h';
                        verticalScrollBarEnabled = false,
                        overScrollMode = View.OVER_SCROLL_NEVER,
                        {
                            TextView;
                            padding = "20dp",
                            ellipsize = "end";
                            layout_width = 'fill';
                            layout_height = 'fill';
                            textColor = '#FF888888';
                            text = 内容;
                            textSize = '15dp';
                            gravity = 'center|left|top';
                            id = "内容",
                        };
                    };
                };
                {
                    TextView,
                    layout_width = "fill",
                    layout_height = "2px",
                    layout_gravity = "center",
                    backgroundColor = "#ffbebebe",
                };
                {
                    LinearLayout,
                    orientation = 'horizontal',
                    layout_width = 'fill',
                    layout_height = '13%w',
                    background = '#00FFFFFF',
                    {
                        LinearLayout,
                        orientation = 'vertical',
                        layout_width = '45%w',
                        layout_height = 'fill',
                        background = '#00FFFFFF',
                        {
                            TextView;
                            gravity = 'center';
                            layout_width = 'fill';
                            layout_height = 'fill';
                            textColor = '#eb000000';
                            text = 按钮1;
                            textSize = '16dp';
                            id = "取消"
                        };
                    };
                    {
                        TextView, --垂直分割线
                        layout_width = "2px", --布局宽度
                        layout_height = "fill",
                        layout_gravity = "center",
                        backgroundColor = "#ffbebebe",
                    };
                    {
                        TextView,
                        layout_width = "0px",
                        layout_height = "fill",
                        layout_gravity = "center",
                        backgroundColor = "#ffbebebe",
                    };
                    {
                        LinearLayout,
                        orientation = 'vertical',
                        layout_width = '45%w',
                        layout_height = 'fill',
                        background = '#00000000',
                        {
                            TextView;
                            gravity = 'center';
                            layout_width = 'fill';
                            layout_height = 'fill';
                            textColor = '#FF147CE4';
                            text = 按钮2;
                            textSize = '16dp';
                            id = "确认"
                        };
                    };
                };
            };
        };
    };
    xxx = AlertDialog.Builder(this)
    xxx.setView(loadlayout(弹窗框架))
    xxx.setCancelable(false)
    xxx = xxx.show()
    import "android.graphics.drawable.ColorDrawable"
    xxx.getWindow().setBackgroundDrawable(ColorDrawable(0x00000000))
    function 波纹特效v2(颜色)
        import "android.content.res.ColorStateList"
        return activity.Resources.getDrawable(activity.obtainStyledAttributes({ android.R.attr.selectableItemBackground --[[Borderless]] })
                                                      .getResourceId(0, 0))
                       .setColor(ColorStateList(int[0]
                .class { int {} }, int { 颜色 or 0x20000000 }))
    end

    确认.onClick = function()
        assert(loadstring(确认事件))()
    end;
    取消.onClick = function()
        assert(loadstring(取消事件))()
    end;
    确认.foreground = 波纹特效v2(0xFFCECECE)
    取消.foreground = 波纹特效v2(0xFFCECECE)
end

function 提示(text)
    Toast.makeText(activity, text, Toast.LENGTH_SHORT).show()
end

function 无网络()
    Toast.makeText(activity, "无法连接至服务器", Toast.LENGTH_SHORT).show()
end

function 服务器禁止通讯()
    Toast.makeText(activity, "服务器禁止通讯", Toast.LENGTH_SHORT).show()
end

function GetAppInfo(包名)
    import "android.content.pm.PackageManager"
    local pm = activity.getPackageManager();
    local 图标 = pm.getApplicationInfo(tostring(包名), 0)
    local 图标 = 图标.loadIcon(pm);
    local pkg = activity.getPackageManager().getPackageInfo(包名, 0);
    local 应用名称 = pkg.applicationInfo.loadLabel(activity.getPackageManager())
    local 版本号 = activity.getPackageManager().getPackageInfo(包名, 0).versionName
    local 最后更新时间 = activity.getPackageManager().getPackageInfo(包名, 0).lastUpdateTime
    local cal = Calendar.getInstance();
    cal.setTimeInMillis(最后更新时间);
    local 最后更新时间 = cal.getTime().toLocaleString()
    return 包名, 版本号, 最后更新时间, 图标, 应用名称
end

function 全局字体(path)
    function 字体()
        import "android.graphics.drawable.GradientDrawable"
        import "android.graphics.Typeface"
        import "java.io.File"
        return Typeface.createFromFile(File(activity.getLuaDir() .. path))
    end

    import "android.graphics.Typeface"
    font = 字体()
    function setFont(fonttext)
        if luajava.instanceof(fonttext, TextView) then
            fonttext.setTypeface(font)
        elseif luajava.instanceof(fonttext, ViewGroup) then
            for _FORV_4_ = 0, fonttext.getChildCount() - 1 do
                setFont(fonttext.getChildAt(_FORV_4_))
            end
        end
    end

    setFont(activity.getDecorView())
end

数据存储 = tostring("/data/data/" .. tostring(activity.getPackageName()) .. "/")
import "android.os.SystemProperties"
--print(SystemProperties.get("ro.product.cpu.abi"))--获取CPU主架构
--print(SystemProperties.get("ro.system.product.cpu.abilist"))--获取CPU架构列表
--print(SystemProperties.get("ro.system.product.cpu.abilist64"))--获取CPU64位架构
--print(SystemProperties.get("ro.system.product.cpu.abilist32"))--获取CPU32位架构
function 指定浏览器打开(包名, 链接)
    import "android.os.*"
    import "android.widget.*"
    import "android.view.*"
    import "android.text.*"
    import "android.content.*"
    intent = Intent("android.intent.action.VIEW")
    intent.setPackage(包名)
    intent.setData(Uri.parse(链接))
    this.startActivity(intent)
end

function 浏览器打开(链接)
    import "android.content.Intent"
    import "android.net.Uri"
    viewIntent = Intent("android.intent.action.VIEW", Uri.parse(链接))
    activity.startActivity(viewIntent)
end

function GoogleHorizontaldynamicloadbar()
    --Google水平动态加载条
    --半天找不到，只好自己做一个
    --作者:Duo  QQ:113530014

    --如果大家有这个东西的原生组件，欢迎你的分享！
    require "import"
    import "android.os.*"
    import "android.widget.*"
    import "android.view.*"
    h = activity.getHeight() --屏幕高
    w = activity.getWidth() --屏幕宽
    function 状态栏高度()
        if Build.VERSION.SDK_INT >= 19 then
            resourceId = activity.getResources().getIdentifier("status_bar_height", "dimen", "android")
            return activity.getResources().getDimensionPixelSize(resourceId)
        else
            return 0
        end
    end

    duo = {
        LinearLayout, --线性布局
        orientation = 'vertical', --方向
        layout_width = 'fill', --宽度
        layout_height = 'wrap', --高度
        background = '#00FFFFFF', --背景
        {
            FrameLayout, --帧布局
            layout_width = 'fill', --宽度
            layout_height = 'wrap', --高度
            background = '#FFFFFFFF', --背景
            --layout_marginTop=状态栏高度(),
            {
                LinearLayout, --线性布局
                orientation = 'vertical', --方向
                layout_width = 'fill', --宽度
                layout_height = '10', --高度
                background = '#03DAC5', --背景
                id = "Progress2",
            };
            {
                LinearLayout, --线性布局
                orientation = 'vertical', --方向
                layout_width = 'fill', --宽度
                layout_height = '10', --高度
                background = '#FFFFFFFF', --背景
                id = "Progress1",
            };

        };
    }
    webView.addView(loadlayout(duo))
    --activity.setContentView(loadlayout(duo))
    w = w * 1.3
    function Progress(x1, x2)
        --位置函数
        Progress1.setX(-(w - x1 * w))
        Progress2.setX(-(w - x2 * w))
    end

    dt = 0.003 --刷新频率
    t = 0 --初始化累计时间
    主频 = Ticker()
    主频.Period = dt * 1000
    主频.onTick = function()
        t = t + 0.98 * dt --累计时间
        Progress((t * 0.9) ^ 1.5005201314 - 1.40114514, t * 0.7) --设置动画
    end --皮一下(doge
    主频.start()
    辅助频 = Ticker()
    辅助频.Period = 2.3 * 1000 --周期
    辅助频.onTick = function()
        t = 0 --归零
    end
    辅助频.start()
    function onDestroy()
        主频.stop()
        辅助频.stop()
    end
end
function file_exists(path)
    local file = io.open(path, "r")
    if file ~= nil then
        io.close(file)
        return true
    else
        return false
    end
end
function Expert_web_sniffer()
    if off[1] then
        layouttc = {
            LinearLayout,
            orientation = 'vertical';
            layout_width = 'fill';
            layout_height = 'fill';
            background = '';
            {
                EditText,
                layout_width = "fill",
                layout_height = "wrap",
                hint = "输入内容",
                hintTextColor = '#90000000';
                textColor = '#d1000000';
                textSize = "15sp",
                imeOptions = "actionSearch",
                singleLine = true,
                id = "edits",
            },
            {
                Button;
                text = '确定';
                layout_width = '-2';
                layout_height = '-2';
                id = "button";
            };
        };
        AlertDialog.Builder(this).create()
                   .setView(loadlayout(layouttc))
                   .show()
        button.onClick = function()
            activity.newActivity("xiutan", { tostring(edits) })
        end
    else
        提示("有bug正在修")
    end
end
function haoqu(title)
    pcweb = { "http://tv.haoqu99.com/1/cctv1.html", "https://tv.cctv.com/live/cctv1/", "http://tv.haoqu99.com/1/347.html", "http://tv.haoqu99.com/1/cctv3.html", "http://tv.haoqu99.com/1/cctv4.html", "http://tv.haoqu99.com/1/cctv5.html", "http://tv.haoqu99.com/1/cctv6.html", "http://tv.haoqu99.com/1/cctv7.html", "http://tv.haoqu99.com/1/353.html", "http://tv.haoqu99.com/1/cctv9.html", "http://tv.haoqu99.com/1/cctv10.html", "http://tv.haoqu99.com/1/cctv11.html", "http://tv.haoqu99.com/1/cctv12.html", "http://tv.haoqu99.com/1/cctv13.html", "http://tv.haoqu99.com/1/cctv14.html", "http://tv.haoqu99.com/1/cctv15.html" }
    pctitle = { "cctv1", "cctv1（官方PCweb版）", "cctv2", "cctv3", "cctv4", "cctv5", "cctv6", "cctv7", "cctv8", "cctv9", "cctv10", "cctv11", "cctv12", "cctv13", "cctv14", "cctv15" }
    pcorbd = { true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true }
    if title ~= nil then
        for k, v in ipairs(pctitle) do
            if v == title then
                if pcorbd[k] then
                    --if io.popen("uname -m"):read("*l") == "x86_64" or io.popen("uname -m"):read("*l") == "x86" or io.popen("uname -m"):read("*l") == "x64" then
                    --    提示("无法在" .. io.popen("uname -m"):read("*l") .. "设备上播放视频")
                    --else
                    --    activity.newActivity("cctv", { pcweb[k] })
                    --end
                    import "android.net.Uri"
                    aa = LuaWebView(this)
                    aa.loadUrl(path)
                    aa.setWebViewClient {
                        onLoadResource = function(view, url)
                            if url:find("index.m3u8") or url:find("mnf.m3u8") or url:find(".m3u8") then
                                linkurl = tostring(Uri.parse(url))
                                activity.newActivity("lj", { linkurl })
                            else
                                提示("没有找到可以播放的源")
                            end
                            --print(url)
                        end
                    }
                elseif pcorbd[k] == false then
                    activity.newActivity("x5llq/pcua", { pcweb[k] })
                else
                    提示("未知问题")
                end
            end
        end
    end
end
function aliyunplay(linkurl)
    import "android.content.Intent"
    import "com.rxteam.MainActivity"
    intent = Intent();
    intent.putExtra(tostring(linkurl))
    intent.setClass(this, MainActivity().getClass())
    activity.startActivity(intent)
end

function okHttp(url, post, header, callback)
    import "okhttp3.*"--需要引入dex文件,手册已经内置了
    local req = Request.Builder()
    req.url(url)--设置url
    if post then
        --不为空则设置post表单
        local arr = FormBody.Builder()
        for str in (post .. "&"):gmatch("(.-)&") do
            local key, value = str:match("(.-)=(.+)")
            arr.add(key, value)
        end
        local requestBody = arr.build()
        req.post(requestBody)
    end
    if header then
        --不为空则设置请求头
        for key, value in pairs(header) do
            req.header(key, value)
        end
    end
    local request = req.build()
    --异步请求
    client = OkHttpClient()
    callz = client.newCall(request)
    callz.enqueue(Callback {
        onFailure = function(call, e)
            callback(-1, e, {})--错误时回调
        end,
        onResponse = function(call, response)
            local code = response.code()
            local content = response.body().string()
            local heafer = luajava.astable(response.headers())
            callback(code, content, heafer)--请求成功回调
        end
    })
end


----请求头和自带的http一样格式
--header={
--    ["User-Agent"]="Mozilla/5.0 (Linux; Android 9; STF-AL00 Build/HUAWEISTF-AL00; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/71.0.3578.99 Mobile Safari/537.36",
--    ["Referer"]="https://www.baidu.com",
--    ["Cookie"]="aaa=123;",
--}
--
--
----get请求
--okHttp("https://www.baidu.com/",nil,header,function(code,content,heafer)
--    print(content)
--end)
--
--
--
----post表单
--post="aaa=123&bbb=456&ccc=789"
--
----post请求
--okHttp("https://www.baidu.com/",post,header,function(code,content,heafer)
--    print(content)
--end)

function 隐藏标题栏_androidx()
    activity.getSupportActionBar().hide()
end
数据存储 = "/data/data/" .. tostring(activity.getPackageName()) .. "/"
数据存储 = activity.getCacheDir().toString()
APPassets目录 = activity.getLuaDir() .. "/"
--重写get_file_type方法
function get_file_type(file_name)
    local file_type = file_name:match("%.([^.]+)$")
    if file_type == "txt" or file_type == "mp4" or file_type == "m3u8" or file_type == "pdf" then
        return file_type
    else
        return ""
    end
end

