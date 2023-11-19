require "import"
activity.getSupportActionBar().hide()
import "Pen_fun_Pavilion.hs"
import "android.content.Intent"
this.getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
    View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR)
--设置常亮
this.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
name, path = ...
拼接 = "https://m.bqg90.com"
上 = ""
下 = ""
书名 = ""
作者 = ""
大小 = 16
hun = ""
x = 0
lds = 0
书名 = name:match([[【(.-)】]])
作者 = name:match([[《(.-)》]])
function 写入文件(路径, 内容)
    if File(路径).isFile() then
        io.open(路径, "w+"):write(内容):close()
    else
        local 父级目录 = File(路径).getParent()
        if File(父级目录).isDirectory() then
            io.open(路径, "w+"):write(内容):close()
        else
            File(父级目录).mkdirs()
            io.open(路径, "w+"):write(内容):close()
        end
    end
end

--问题是不知道如何判断这个读完了。
function 语音播报(x, y, z)
    import("android.speech.tts.*")
    mTextSpeech = TextToSpeech(activity, TextToSpeech.OnInitListener({
        onInit = function(bf)
            if bf == TextToSpeech.SUCCESS then
                result = mTextSpeech.setLanguage(Locale.CHINESE)
                if result == TextToSpeech.LANG_MISSING_DATA or result == TextToSpeech.LANG_NOT_SUPPORTED then
                    result = mTextSpeech.setLanguage(Locale.ENGLISH)
                    if result == TextToSpeech.LANG_MISSING_DATA or result == TextToSpeech.LANG_NOT_SUPPORTED then
                    else
                        mTextSpeech.setPitch(1)
                        mTextSpeech.setSpeechRate(1)
                        mTextSpeech.speak("", TextToSpeech.QUEUE_FLUSH, nil)
                    end
                else
                    mTextSpeech.setPitch(y)
                    mTextSpeech.setSpeechRate(z)
                    mTextSpeech.speak(x, TextToSpeech.QUEUE_FLUSH, nil)
                    -- print(1)
                end
            end
        end
    }))
end

function Star(链接)
    Http.get(链接, function(a, b)
        path = 链接
        if a == 200 then
            hun = b:match([[ReadAjax_content">(.-)<p class]])
            sx = b:match([[Readpage pagedown(.-)>下一]])
            章节 = b:match([[class="title">(.-)_]])
            xr = string.gsub(链接, "https://m.bqg90.com", "")
            if hun then
                正文 = (html转义(hun))
                --[[ if string.find(正文,"手机版更新最快网址") then
          正文=string.gsub(正文,"手机版更新最快网址：","")
        end]]
                if x ~= 0 then
                    设置文本(zw, "\n                  " .. 章节 .. "\n" .. 正文, 大小, 0xFFF3f9f1)
                else
                    设置文本(zw, "\n                  " .. 章节 .. "\n" .. 正文, 大小, 0xFF524C4A)
                end
                f下 = sx:match([[目录(.-)pb_next]])
                上 = sx:match([[href="(.-)"]])
                下 = f下:match([[href="(.-)"]])
                import "java.io.File"
                --jqzj=string.sub(hun,1,150)
                时间 = os.date("%Y-%m-%d %H:%M:%S")
                task(1500, function()
                    写入文件("/storage/emulated/0/Android/data/"..tostring(activity.getPackageName()).."/笔趣阁/" .. 书名 .. ".lua",
                        "<" .. name .. ">@" .. 章节 .. ")@\nurl={" .. xr .. "}\n%" .. 时间 .. "%")
                end)
            else
                --print("截取方案失效！")
            end
        else
            --print("获取失败_状态码：" .. b)
        end
    end)
end

高 = this.getResources().getDimensionPixelSize(luajava.bindClass("com.android.internal.R$dimen")().status_bar_height)
layout = {
    LinearLayout,
    id = "jm",
    layout_width = "fill",
    layout_height = "fill",
    orientation = "vertical",
    background = "#ffffff",
    focusableInTouchMode = true,
    {
        LinearLayout,
        layout_width = "fill",
        layout_height = "wrap",
        orientation = "vertical",
        elevation = "4dp",
        background = "#fffffafa",
        id = "tx3",
        {
            LinearLayout,
            layout_width = "fill",
            layout_height = "54dp",
            layout_marginTop = 高 * 0.8,
            orientation = "horizontal",
            gravity = "center",
            background = "#fffffafa",
            id = "tx1",
            layoutTransition = LayoutTransition()
                .enableTransitionType(LayoutTransition.CHANGING)
                .setDuration(LayoutTransition.CHANGE_APPEARING, 100)
                .setDuration(LayoutTransition.CHANGE_DISAPPEARING, 100),
            {
                TextView,
                layout_marginLeft = "4%w",
                layout_weight = "1",
                text = 书名,
                textSize = "18sp",
                textColor = 0xff222222,
                singleLine = true,
                ellipsize = "end",
                id = "bt",
                typeface = Typeface.DEFAULT_BOLD,
            },

            {
                TextView,
                layout_marginRight = "18dp",
                text = "✱",
                textSize = "28sp",
                textColor = 0xff222222,
                onTouchListener = 点击缩放,
                id = "sz",
            },
            {
                TextView,
                layout_marginRight = "18dp",
                text = "⨯",
                textSize = "38sp",
                textColor = 0xff222222,
                onTouchListener = 点击缩放,
                id = "tc",
                onClick = function()
                    activity.finish()

                end,
            },
        },
    },
    {
        ScrollView,
        layout_width = "fill",
        layout_height = "fill",
        id = "hd",
        verticalScrollBarEnabled = true,
        {
            LinearLayout,
            layout_width = "fill",
            layout_height = "fill",
            orientation = "vertical",
            {
                CardView,
                layout_width = "fill",
                layout_height = "fill",
                layout_margin = "8dp",
                cardElevation = "2dp",
                cardBackgroundColor = "#eeffffff",
                radius = "8dp",
                id = "tx4",
                {
                    LinearLayout,
                    layout_width = "fill",
                    layout_height = "fill",
                    orientation = "vertical",
                    layoutTransition = LayoutTransition()
                        .enableTransitionType(LayoutTransition.CHANGING)
                        .setDuration(LayoutTransition.CHANGE_APPEARING, 800)
                        .setDuration(LayoutTransition.CHANGE_DISAPPEARING, 800),
                    {
                        TextView,
                        textIsSelectable = true,
                        text = "正在加载...",
                        textSize = "16dp",
                        textColor = "#222222",
                        id = "zw",
                    },
                    {
                        LinearLayout,
                        gravity = "center",
                        layout_width = "fill",
                        layout_height = "fill",
                        id = "tx5",
                        orientation = "horizontal",
                        {
                            Button,
                            text = "上一页",
                            onClick = function()
                                hd.fullScroll(View.FOCUS_UP)
                                Star(拼接 .. 上)
                                晃动动画(jm, "单")
                            end,
                        },
                        {
                            Button,
                            text = "下一页",
                            onClick = function()
                                hd.fullScroll(View.FOCUS_UP)
                                Star(拼接 .. 下)
                                晃动动画(jm, "单")
                            end,
                        },
                    },
                },
            },
        },
    },
}
activity.setContentView(loadlayout(layout))
function 扩散动画(a, b, c, d, e, f)
    local ksdh = ViewAnimationUtils.createCircularReveal(a, b, c, d, e)
    ksdh.setDuration(f).start()
end

Star(拼接 .. path)
zw.getPaint().setFakeBoldText(true)
bt.onClick = function()
    if x == 0 then
        扩散动画(jm, this.width, 0, 0, this.height, 450)
        activity.getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE)
        zw.setTextColor(0xfff3f9f1)
        tc.setTextColor(0xfff3f9f1)
        sz.setTextColor(0xfff3f9f1)
        bt.setTextColor(0xfff3f9f1)
        tx1.setBackgroundColor(0xFF524C4A)
        tx3.setBackgroundColor(0xFF524C4A)
        tx4.setBackgroundColor(0xFF524C4A)
        tx5.setBackgroundColor(0xFF524C4A)
        jm.setBackgroundColor(0xFF524C4A)
        扩散动画(tx1, this.width, 0, 0, this.height, 0, 450)
        x = x + 1
    else
        扩散动画(jm, this.width, 0, 0, this.height, 450)
        activity.getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
            View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR)
        zw.setTextColor(0xFF524C4A)
        tc.setTextColor(0xFF524C4A)
        sz.setTextColor(0xFF524C4A)
        bt.setTextColor(0xFF524C4A)
        tx1.setBackgroundColor(0xfff3f9f1)
        tx3.setBackgroundColor(0xfff3f9f1)
        tx4.setBackgroundColor(0xfff3f9f1)
        tx5.setBackgroundColor(0xfff3f9f1)
        jm.setBackgroundColor(0xfff3f9f1)
        扩散动画(tx1, this.width, 0, 0, this.height, 0, 450)
        x = x - 1
    end
end

bt.onLongClick = function()
    --print(作者)

end
--设置功能有待完善
sz.onClick = function()
    layout = {
        LinearLayout,
        layout_width = "fill",
        layout_height = "fill",
        orientation = "vertical",
        gravity = "center",
        {
            TextView,
            layout_width = "fill",
            layout_height = "100%h",
            layout_weight = 1,
            onClick = function()
                动画退出(l, dialog)

            end,
        },
        {
            LinearLayout,
            layout_width = "fill",
            layout_height = "560dp",
            orientation = "vertical",
            gravity = "center|top",
            BackgroundDrawable = 边框圆角(4, 0xffffffff, 0xffffffff, 40);
            id = "l",
            {
                TextView,
                text = "设置",
                textSize = "35sp",
                textColor = 0xff222222,
            },
            {
                TextView,
                text = "配置需要本地储存，懒得写了",
                textSize = "16sp",
                textColor = 0xff222222,
            },
            {
                EditText,
                layout_width = "fill",
                layout_height = "wrap",
                hint = "字体大小_1~∞_留空默认16dp",
                textSize = "16sp",
                textColor = 0xff222222,
                singleLine = true,
                inputType = "number",
                id = "ztdx",
            },
            {
                TextView,
                text = "屏幕亮度↓↓↓",
                textSize = "15sp",
                textColor = 0xff222222,
            },
            {
                LinearLayout,
                layout_width = "fill",
                layout_height = "120dp",
                gravity = "center|top",
                orientation = "horizontal",
                {
                    Button,
                    padding = "2dp",
                    text = "低",
                    textSize = "15sp",
                    textColor = 0xffffffff,
                    onClick = function()
                        window = activity.getWindow();
                        lp = window.getAttributes();
                        lp.screenBrightness = 25 / 255.0;
                        window.setAttributes(lp)
                    end,
                },
                {
                    Button,
                    padding = "2dp",
                    text = "中",
                    textSize = "15sp",
                    textColor = 0xffffffff,
                    onClick = function()
                        window = activity.getWindow();
                        lp = window.getAttributes();
                        lp.screenBrightness = 157 / 255.0;
                        window.setAttributes(lp)
                    end,
                },
                {
                    Button,
                    padding = "2dp",
                    text = "高",
                    textSize = "15sp",
                    textColor = 0xffffffff,
                    onClick = function()
                        window = activity.getWindow();
                        lp = window.getAttributes();
                        lp.screenBrightness = 220 / 255.0;
                        window.setAttributes(lp)
                    end,
                },
            },
            {
                TextView,
                text = "字体类型↓↓↓",
                textSize = "15sp",
                textColor = 0xff222222,
            },
            {
                LinearLayout,
                layout_width = "fill",
                layout_height = "60dp",
                gravity = "center|top",
                orientation = "horizontal",
                {
                    Button,
                    padding = "2dp",
                    text = "类型1",
                    textSize = "15sp",
                    textColor = 0xFF000000,
                    id = "zt1",
                    onClick = function()
                        zw.getPaint().setTypeface(Typeface.createFromFile(File(this.getLuaDir() .. "/ttf/tianzhen.ttf")))
                    end,
                },
                {
                    Button,
                    padding = "2dp",
                    text = "类型2",
                    textSize = "15sp",
                    textColor = 0xFF000000,
                    id = "zt2",
                    onClick = function()
                        zw.getPaint().setTypeface(Typeface.createFromFile(File(this.getLuaDir() .. "/ttf/zy.ttf")))
                    end,
                },
                {
                    Button,
                    padding = "2dp",
                    text = "类型3",
                    textSize = "15sp",
                    textColor = 0xFF000000,
                    id = "zt3",
                    onClick = function()
                        zw.getPaint().setTypeface(Typeface.createFromFile(File(this.getLuaDir() .. "/ttf/xyjz.ttf")))
                    end,
                },
            },
            {
                Button,
                padding = "2dp",
                text = "选择字体",
                textSize = "15sp",
                textColor = 0xffffffff,
                id = "xz",
                onClick = function()
                    列表 = [[
《类型1》
【zw.getPaint().setTypeface(Typeface.createFromFile(File(this.getLuaDir().."/ttf/tianzhen.ttf")))】
《类型2》
【zw.getPaint().setTypeface(Typeface.createFromFile(File(this.getLuaDir().."/ttf/zy.ttf")))】
《类型3》
【zw.getPaint().setTypeface(Typeface.createFromFile(File(this.getLuaDir().."/ttf/xyjz.ttf")))】
]]
                    储存表1 = {}
                    储存表2 = {}
                    for a, b in 列表:gmatch("《(.-)》\n【(.-)】") do
                        table.insert(储存表1, a)
                        table.insert(储存表2, b)
                    end
                    LuaDialog(this)
                        .setTitle("选择字体")
                        .setSingleChoiceItems(储存表1, -1)
                        .setOnItemClickListener(AdapterView.OnItemClickListener {
                            onItemClick = function(a, b, c, d)
                                点击标题 = 储存表1[d]
                                点击内容 = 储存表2[d]
                            end
                        })
                        .setButton("确定", function()
                            --print("设置成功，下一页即可生效")
                            assert(loadstring(点击内容))()
                        end)
                        .setNegativeButton("取消", nil)
                        .setNeutralButton("其他", nil)
                        .show()

                end,
            },
            {
                LinearLayout,
                layout_width = "fill",
                layout_height = "50dp",
                gravity = "center|top",
                orientation = "horizontal",
                {
                    Button,
                    padding = "2dp",
                    text = "关闭",
                    textSize = "15sp",
                    textColor = 0xffffffff,
                    onClick = function()
                        动画退出(l, dialog)
                    end,
                },
                {
                    Button,
                    padding = "2dp",
                    text = "保存",
                    textSize = "15sp",
                    textColor = 0xffffffff,
                    id = "bc",
                    onClick = function()
                        if ztdx.text ~= "" then
                            大小 = tonumber(ztdx.text)
                        end
                        动画退出(l, dialog)
                    end,
                },
            },
            {
                LinearLayout,
                layout_width = "fill",
                layout_height = "75dp",
                gravity = "center|top",
                orientation = "vertical",
                {
                    Button,
                    layout_marginRight = "18dp",
                    text = "朗读",
                    textSize = "28sp",
                    textColor = 0xffffffff,
                    onTouchListener = 点击缩放,
                    id = "ld",
                    onClick = function()
                        if lds == 0 then
                            语音播报(zw.text, 1, 1.0)
                            ld.setText("关闭")
                            lds = lds + 1
                        else
                            --print("已经关闭阅读模式，重新进入即可")
                            this.finish()
                            lds = lds - 1
                        end
                    end,
                },
                {
                    TextView,
                    layout_width = "fill",
                    layout_height = "fill",
                    gravity = "bottom|center",
                    textColor = "0xFF000000",
                    text = "Copyright © 2022 - 2099 By 碳昔. All Rights Reserved. ",
                    textSize = "12dp"
                },
            },
        },
    }
    dialog = AlertDialog.Builder(this)
    dialog.setView(loadlayout(layout))
    dialog.setCancelable(false)
    dialog = dialog.show()
    dialog.getWindow().setBackgroundDrawable(ColorDrawable(0x00000000))
    dialog.getWindow().getAttributes().width = activity.Width
    dialog.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
    动画显示(l)
    zt1.getPaint().setTypeface(Typeface.createFromFile(File(this.getLuaDir() .. "/ttf/tianzhen.ttf")))
    zt2.getPaint().setTypeface(Typeface.createFromFile(File(this.getLuaDir() .. "/ttf/zy.ttf")))
    zt3.getPaint().setTypeface(Typeface.createFromFile(File(this.getLuaDir() .. "/ttf/xyjz.ttf")))

end

import "android.view.KeyEvent"
function onKeyDown(keyCode, event)
    if keyCode ~= KeyEvent.KEYCODE_BACK then
        if keyCode == KeyEvent.KEYCODE_VOLUME_DOWN then
            if i ~= 0 then
                hd.arrowScroll(ScrollView.FOCUS_DOWN)
                --音量下翻页
            end
        else
            if ii ~= 1 then
                hd.arrowScroll(ScrollView.FOCUS_UP)
                --音量上翻页
            end
        end
    end
end

--[[function onStop()
  print("防删进程重构")
  activity.finish()
end
]]
