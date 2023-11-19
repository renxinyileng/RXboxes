require "import"
activity.getSupportActionBar().hide()
import "Pen_fun_Pavilion.hs"
this.getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
        View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR)
--写了两天，西拼东凑也算是功能比较齐全了。
话 = [==[
主界面顶栏有个放大镜，点它可以进行搜索

放大镜的右边有一个大*，点它可以看阅读记录

阅读记录长按适配器列表，可以选择删除记录

右上角顶栏也可以进行搜索，搜索阅读记录

阅读记录都储存在"/sdcard/Android/data/rx.team.renxinyileng.box/笔趣阁/"(该项目已更改)

在阅读界面点顶栏空白处可以切换昼夜模式还可以音量上下翻

别的不多说了♥
                              --2022.7.23
]==]
sb, sb1, sb2 = "", "", ""

高 = this.getResources().getDimensionPixelSize(luajava.bindClass("com.android.internal.R$dimen")().status_bar_height)

layout =
{
    LinearLayout,
    layout_width = "fill",
    layout_height = "fill",
    orientation = "vertical",
    {
        LinearLayout,
        orientation = "vertical",
        layout_width = "fill",
        layout_height = "wrap",
        background = "#fffffafa",
        elevation = "4dp",
        {
            LinearLayout,
            orientation = "horizontal",
            layout_width = "fill",
            layout_height = "56dp",
            layout_marginTop = 高 * 0.8,
            gravity = "left|center",
            {
                TextView,
                layout_marginLeft = "4%w",
                layout_weight = "1",
                text = "爬取全网小说",
                textSize = "18sp",
                textColor = 0xff222222,
                singleLine = true,
                typeface = Typeface.DEFAULT_BOLD,
            },
            {
                TextView,
                layout_marginRight = "18dp",
                text = "☌", --图片太占体积了
                textSize = "38sp",
                textColor = 0xff222222,
                onTouchListener = 点击缩放,
                id = "rh",
            },
            {
                TextView,
                layout_marginRight = "18dp",
                text = "✱",
                textSize = "32sp",
                textColor = 0xff222222,
                onTouchListener = 点击缩放,
                id = "jl",
            },
        },
    },
    {
        TextView,
        layout_margin = "8dp", --外↔边距
        text = 话,
        textSize = "22sp",
        textColor = 0xFF000000,
        id = "gs",
    },
    {
        TextView,
        text = "",
        textSize = "0",
        id = "key",
    },
    {
        ListView,
        layout_width = "fill",
        layout_height = "fill",
        id = "listzxx",
    },
}
activity.setContentView(loadlayout(layout))

--设置字体
gs.getPaint().setTypeface(Typeface.createFromFile(File(this.getLuaDir() .. "/ttf/zy.ttf")))

rh.setRotation(105)
itemzxx = {
    LinearLayout,
    gravity = "center",
    layout_width = "fill",
    layout_height = "fill",
    {
        CardView,
        layout_margin = '15dp',
        layout_gravity = 'center',
        Elevation = '3dp',
        layout_width = '96%w',
        layout_height = 'wrap',
        radius = '15dp',
        CardBackgroundColor = "#ffffff",
        {
            LinearLayout,
            gravity = "center",
            layout_width = "fill",
            layout_height = "fill",
            {
                ImageView,
                layout_width = '100dp',
                layout_height = '133dp',
                id = "封面",
                layout_margin = '5dp',
                scaleType = "fitXY",
            },
            {
                LinearLayout,
                Orientation = 'vertical',
                layout_gravity = 'right',
                layout_width = 'match_parent',
                layout_height = 'match_parent',
                layout_margin = "10dp",
                {
                    TextView,
                    layout_width = '0',
                    layout_height = '0',
                    id = "小说id",
                },
                {
                    LinearLayout,
                    layout_width = 'match_parent',
                    layout_height = '5%h',
                    {
                        TextView,
                        layout_marginTop = '1.5%h',
                        layout_width = 'match_parent',
                        layout_height = 'match_parent',
                        Gravity = 'left|center',
                        textColor = "#757575",
                        text = '',
                        id = "小说",
                        textSize = '20sp',
                        typeface = font,
                    },
                },
                {
                    LinearLayout,
                    layout_width = 'match_parent',
                    layout_height = '2%h',
                    layout_marginTop = '10dp',
                    {
                        TextView,
                        layout_width = 'match_parent',
                        layout_height = 'fill',
                        Gravity = 'left',
                        textColor = '#69000000',
                        textSize = '11sp',
                        id = "作者",
                        MaxLines = 1,
                        textColor = "#757575",
                    },
                },
                {
                    LinearLayout,
                    layout_width = 'match_parent',
                    layout_height = 'wrap',
                    {
                        TextView,
                        layout_width = 'match_parent',
                        layout_height = 'match_parent',
                        Gravity = 'left',
                        textColor = '#69000000',
                        textSize = '11sp',
                        id = "介绍",
                        --MaxLines=3,
                        textColor = "#757575",
                    },
                },
            },
        },
    },
}

adpzxx = LuaAdapter(this, itemzxx)
listzxx.setAdapter(adpzxx)
--书名="元尊"
z = 0
function 搜索(书名)
    Http.get("https://m.bqg90.com/s?q=" .. 书名, function(a, b)
        if a == 200 then
            z = 0
            范围 = b:match([[block so_list(.-)我的书架]])
            for a, b, c, d, e, f, g in 范围:gmatch([[href="(.-)"><img src="(.-)" alt="(.-)"></a></div><dl><dt><span>(.-)</span><a href="(.-)">(.-)</a></dt><dd>(.-)</dd></dl></div><div class="item"><div class="image"><a]]) do
                z = z + 1
                adpzxx.add {
                    小说id = "https://m.bqg90.com" .. a .. "list.html",
                    封面 = b,
                    小说 = c,
                    作者 = "作者：" .. d,
                    介绍 = "简介：" .. g
                }
            end
            设置文本(gs, "找到" .. z .. "个匹配的结果", 15, 0xfff35336)
        else
            --print("获取失败_状态码：" .. b)
        end
    end)
end

listzxx.onItemClick = function(a, b)
    --print("稍等")
    sb = b.Tag.小说.Text
    sb1 = b.Tag.作者.Text
    sb2 = b.Tag.小说id.Text
    function 检测()
        if File("/storage/emulated/0/Android/data/"..tostring(activity.getPackageName()).."/笔趣阁/" .. b.Tag.小说.Text .. ".lua").exists() then
            key.setText("0")
            jc = io.open("/storage/emulated/0/Android/data/"..tostring(activity.getPackageName()).."/笔趣阁/" .. b.Tag.小说.Text .. ".lua"):read("*a")
            --本来应该用表的
            named = jc:match([[<(.-)>]])
            段落 = jc:match([[@(.-)@]])
            url = jc:match([[url={(.-)}]])
            时间 = jc:match("([^\n]+)$")
            标题 = "重要提示"
            内容 = "检测到您有阅读过该小说的记录\n" .. 段落 .. "\n是否继续阅读"
            确认事件 = [[activity.newActivity("Pen_fun_Pavilion/ydq",android.R.anim.fade_in,android.R.anim.fade_out,{named,url})]]
            取消事件 = [[key.setText("1")]]
            弹出通知(标题, 内容, 确认事件, 取消事件)
        else
            key.setText("1")
        end
    end

    检测()

end
listzxx.onItemLongClick = function(a, b)
    ----print()

end
rh.onClick = function()

    layout =
    { --布局命名
        LinearLayout, --线性布局
        layout_width = "fill", --布局宽度
        layout_height = "fill", --布局高度
        orientation = "vertical", --方向
        gravity = "center", --布局重力
        {
            LinearLayout, --线性布局
            layout_width = "fill", --布局宽度
            layout_height = "260dp", --布局高度
            orientation = "vertical", --方向
            gravity = "center", --布局重力
            BackgroundDrawable = 边框圆角(4, 0xffffffff, 0xffffffff, 40);
            id = "ckou", --控件ID
            {
                TextView, --文本框控件
                text = "查找小说", --文本内容
                textSize = "25sp", --文本大小
                textColor = 0xff222222, --文本颜色
            },
            {
                EditText, --输入框控件
                layout_margin = "18dp", --外↔边距
                layout_marginTop = "18dp", --外↑顶距
                backgroundDrawable = edrawable,
                layout_width = "fill", --布局宽度
                layout_height = "wrap", --布局高度
                hint = "搜索书名或作者，可以少，但别错字。",
                textSize = "16sp", --文本大小
                textColor = 0xff222222, --文本颜色
                singleLine = true, --单行模式
                id = "shuming",
            },
            {
                LinearLayout, --线性布局
                layout_width = "fill", --布局宽度
                layout_height = "fill", --布局高度
                orientation = "horizontal", --方向
                gravity = "center", --布局重力
                {
                    Button, --纽扣控件
                    layout_marginTop = "8dp", --外↑顶距
                    padding = "2dp", --内边距
                    layout_margin = "8dp", --外↔边距
                    BackgroundDrawable = 边框圆角(4, 0xFF000000, 0x1DFFFFFF, 40);
                    text = "关闭", --文本内容
                    textSize = "15sp", --文本大小
                    textColor = 0xff000000, --文本颜色
                    onClick = function() --点击事件
                        动画退出(ckou, dialog)
                    end,
                },
                {
                    Button, --纽扣控件
                    layout_marginTop = "8dp", --外↑顶距
                    padding = "2dp", --内边距
                    layout_margin = "8dp", --外↔边距
                    BackgroundDrawable = 边框圆角(4, 0xFF000000, 0x1DFFFFFF, 40);
                    text = "开始", --文本内容
                    textSize = "15sp", --文本大小
                    textColor = 0xff000000, --文本颜色
                    onClick = function() --点击事件
                        adpzxx.clear()
                        搜索(shuming.Text)
                        动画退出(ckou, dialog)
                    end,
                },
            }, --线性布局结束
        }, --线性布局结束
    } --线性布局结束
    dialog = AlertDialog.Builder(this) --对话框
    dialog.setView(loadlayout(layout)) --装载布局
    dialog.setCancelable(false) --禁用返回键
    dialog = dialog.show() --显示
    dialog.getWindow().setBackgroundDrawable(ColorDrawable(0x00000000)) --窗口背景透明
    --窗口宽度
    dialog.getWindow().getAttributes().width = activity.Width
    dialog.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
    --启用动画
    动画显示(ckou)

end

key.addTextChangedListener {
    onTextChanged = function(a)
        if key.text == "0" then
        else
            layout =
            {
                LinearLayout,
                orientation = "vertical",
                layout_width = "fill",
                layout_height = "fill",
                gravity = "center",
                focusableInTouchMode = true,
                {
                    CardView,
                    layout_width = "88%w",
                    layout_height = "wrap",
                    cardBackgroundColor = "#ffffff",
                    cardElevation = "0dp",
                    radius = "8dp",
                    {
                        LinearLayout,
                        orientation = "vertical",
                        layout_width = "fill",
                        layout_height = "fill",
                        {
                            LinearLayout,
                            orientation = "horizontal",
                            layout_width = "fill",
                            layout_height = "46dp",
                            gravity = "left|center",
                            {
                                TextView,
                                layout_marginLeft = "4%w",
                                layout_weight = "1",
                                text = "章节选择",
                                textSize = "18sp",
                                textColor = "#222222",
                                singleLine = true,
                            },
                            {
                                TextView,
                                layout_marginRight = "12dp",
                                text = "×",
                                textSize = "30sp",
                                textColor = 0xff222222,
                                onTouchListener = 点击缩放,
                                id = "gb",
                                onClick = function()
                                    txx.dismiss()
                                end,
                            },
                        },
                        {
                            TextView,
                            layout_width = "fill",
                            layout_height = "1px",
                            backgroundColor = "#bebebe",
                        },
                        {
                            CardView,
                            layout_margin = "10dp",
                            layout_width = "fill",
                            layout_height = "38dp",
                            cardElevation = "0dp",
                            cardBackgroundColor = "#fff0f0f0",
                            radius = "4dp",
                            {
                                EditText,
                                layout_width = "fill",
                                layout_height = "fill",
                                gravity = "left|center",
                                padding = "2dp",
                                background = "#00000000",
                                hint = " 输入关键字搜索...",
                                textSize = "16sp",
                                singleLine = true,
                                id = "edit",
                            },
                        },
                        {
                            TextView, --文本框控件
                            text = "【" .. sb .. "】《" .. sb1 .. "》", --文本内容
                            textSize = "0sp", --文本大小
                            textColor = 0xff222222, --文本颜色
                            id = "xx",
                        },
                        {
                            ListView,
                            layout_width = "fill",
                            layout_height = "fill",
                            dividerHeight = "1",
                            id = "liebiao",
                            layoutTransition = LayoutTransition()
                                    .enableTransitionType(LayoutTransition.CHANGING)
                                    .setDuration(LayoutTransition.CHANGE_APPEARING, 800)
                                    .setDuration(LayoutTransition.CHANGE_DISAPPEARING, 800),

                        },
                    },
                },
            }
            txx = AlertDialog.Builder(this)
            txx.setView(loadlayout(layout))
            txx = txx.show()
            import "android.graphics.drawable.ColorDrawable"
            txx.getWindow().setBackgroundDrawable(ColorDrawable(0x00000000))
            function 更新数据(更新源)
                adp = ArrayAdapter(activity, android.R.layout.simple_list_item_1, String(更新源))
                liebiao.setAdapter(adp)
            end

            标题 = {}
            内容 = {}
            Http.get(sb2, function(a, b)
                c = 0
                if a == 200 then
                    b = b:match([[style="color:Red(.-)text/javascript]])
                    截取内容 = b:gmatch([[<dd><a href ="(.-)">(.-)<]])
                    for b, a in 截取内容 do
                        标题[#标题 + 1] = a
                        内容[a] = b
                        更新数据(标题)
                    end
                else
                    if a == -1 then
                        --print("请检查网络是否开启")
                    else
                        --print("获取失败_状态码：" .. b)
                        ----print("")
                    end
                end
            end)
            edit.addTextChangedListener {
                onTextChanged = function(v)
                    local 储存表 = {}
                    for a, b in pairs(标题) do
                        if string.lower(tostring(b)):find(string.lower(tostring(v)), 1, true) then
                            储存表[#储存表 + 1] = b
                        end
                    end
                    更新数据(储存表)
                end,
            }
            liebiao.onItemClick = function(a, b)
                activity.newActivity("Pen_fun_Pavilion/ydq", android.R.anim.fade_in, android.R.anim.fade_out, { xx.Text, 内容[b.Text] })
                --print(b.Text)
                --print(内容[b.Text])
            end
            liebiao.onItemLongClick = function(a, b)
                --print(b.Text)
                --print(内容[b.Text])
            end
        end
    end,
}
jl.onClick = function()
    activity.newActivity("Pen_fun_Pavilion/ydjl")
end

参数 = 0
function onKeyDown(code, event)
    --if string.find(tostring(event), "KEYCODE_BACK") ~= nil then
    --    if 参数 + 2 > tonumber(os.time()) then
    --        tx.stop()
    --        if (mp.isPlaying()) then
    --            mp.pause()
    --        end
    --        activity.finish()
    --    else
    --        --print("请再按一次退出")
    --        参数 = tonumber(os.time())
    --    end
    --end
end
