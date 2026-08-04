--[[
//‘饮用’了"訫念是你"的布局
//api是在某函里抓来的，不然真找不到这么好的网站😁
致力于打造一个万能的手册/滑稽/滑稽(｡>∀<｡)

By.碳昔
]]
require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.widget.LinearLayout"
import "android.app.AlertDialog"
import "com.androlua.Http"
import "java.lang.String"
import "android.widget.ArrayAdapter"
import "android.widget.CircleImageView"
import "android.view.View"
import "android.graphics.drawable.ColorDrawable"
import "android.widget.TextView"
import "android.widget.ListView"
import "com.androlua.LuaAdapter"
import "android.view.Gravity"
import "android.widget.ImageView"
import "android.widget.GridView"
import "android.widget.Toast"
import "android.graphics.drawable.GradientDrawable$Orientation"
import "android.widget.EditText"
import "android.graphics.drawable.GradientDrawable"
import "android.graphics.drawable.ColorDrawable"
--复制文本
function 复制文本(文本内容)
    import "android.content.Context"
    activity.getSystemService(Context.CLIPBOARD_SERVICE).setText(文本内容)
end

--JSON=require "cjson"
--截取万岁万岁万万岁😀
--activity.setTheme(R.Theme_Pink)
--activity.setTitle("漫画")
--图可能会加载不出来，不过链接有了≈水到渠成。
--我试过了，除fa2,用loadbitmap可能很慢but是可以加载出来的
--不过雀食可以支持所有环境
储存, xyycc = "", ""
lay = {
    LinearLayout,
    gravity = "center|top",
    layout_height = "fill",
    orientation = "vertical",
    layout_width = "fill",
    {
        LinearLayout,
        layout_height = "168dp",
        gravity = "center",
        orientation = "vertical",
        layout_width = "fill",
        {
            CardView, --卡片框控件
            layout_marginTop = "35dp", --外↑顶距
            layout_width = "80dp", --布局宽度
            layout_height = "80dp", --布局高度
            layout_margin = "8dp", --布局外边距
            cardElevation = "2dp", --卡片阴影层次
            cardBackgroundColor = "#eeffffff", --卡片背景色
            radius = "60dp", --卡片圆角
            {
                LinearLayout, --线性布局
                gravity = "center", --居中
                layout_width = "fill", --布局宽度
                layout_height = "fill", --布局高度
                orientation = "vertical", --方向
                background = "https://img1.baidu.com/it/u=2198167830,1954188447&fm=253&app=138&size=w931&n=0&f=JPEG&fmt=auto&maxorilen2heic=2000000",
                {
                    TextView, --文本框控件
                    text = "漫", --文本内容
                    textSize = "45sp", --文本大小
                    textColor = 0xff222222, --文本颜色
                },
            }, --线性布局结束
        }, --卡片框控件结束
    },
    {
        CardView,
        layout_height = "60dp",
        layout_width = "match_parent",
        id = "card_edit",
        layout_margin = "15dp",
        radius = "15dp",
        {
            LinearLayout,
            layout_height = "fill",
            gravity = "center",
            layout_width = "fill",
            layout_margin = "5dp",
            {
                EditText,
                backgroundColor = "#",
                id = "edit",
                layout_width = "72%w",
                layout_marginLeft = "10dp",
                singleLine = true,
            },
            {
                CircleImageView,
                -- 原来是 helloimg 上的一张远程图，图床已经挂了（真机日志里是
                -- getHttpBitmap -> FileNotFoundException），搜索按钮一直是空白。
                -- 换成随包走的本地图标，顺便省掉一次开屏网络请求。
                -- 相对路径由 loadbitmap 按 luadir 解析，luadir 是含 main.lua 的
                -- 那一层（即 files/），所以这里写 icon/ 而不是 ../icon/
                src = "icon/search.png",
                padding = "10dp",
                id = "start",
            },
        },
    },
    {
        ListView,
        layout_width = "fill",
        id = "list",
        DividerHeight = '0',
        layout_height = "fill",
        background = "#00ffffff",
        verticalScrollBarEnabled = false,
        overScrollMode = View.OVER_SCROLL_NEVER,
    },
}
activity.setContentView(loadlayout(lay))
--隐藏标题栏
--activity.ActionBar.hide()

function 卡片边框(控件ID, 边框宽度, 边框颜色, 背景颜色, 边框圆角)
    import "android.graphics.drawable.GradientDrawable"
    控件ID.setBackgroundDrawable(GradientDrawable()
            .setShape(GradientDrawable.RECTANGLE)
            .setStroke(边框宽度, tonumber(边框颜色))
            .setColor(tonumber(背景颜色))
            .setCornerRadius(边框圆角))
    return drawable
end

卡片边框(card_edit, 3, 0x40000000, 0xFFFFFFFF, 360)

function novel()
    asdp = LuaAdapter(activity, item)
    list.Adapter = asdp
    url = "https://m.imitui.com/search/?keywords=" .. edit.Text
    Http.get(url, function(a, b)
        for 链接, 图片, 名称, 作者, 类型, 时间 in b:gmatch([[<div class="itemImg">
        <a href="(.-)"><img src="(.-)" .-class="title" href=".-">(.-)</a>
        <p class="txtItme">(.-)<span class=".-"></span></p>
        <p class="txtItme">
            <span class=".-"></span>
            <span class="pd">(.-)</span>
        </p>
        <p class="txtItme">
            <span class=".-"></span>
            <span class="date">(.-)</span>
        </p>
    </div>]]) do
            asdp.add {
                小说 = 名称,
                作者 = "作者： " .. 作者,
                介绍 = "介绍： " .. 类型 .. "\n最后更新时间：" .. 时间,
                封面 = 图片,
                小说id = 链接,
            }

        end
    end)
end

function 获取()
    if xyycc == "" then
        Http.get(储存, function(a, b)
            if a == 200 then
                bs = string.gsub(b, "-", "_")
                范围 = b:match([[page(.-)5px]])
                exwz = 范围:gmatch([[src="https://n(.-)" alt=]])
                额 = bs:match([[class="next_page"(.-)>]])
                xyy = 额:match([["(.-)"]])
                xyycc = xyy
                复制文本(xyycc)
                for result in exwz do
                    results = "https://n" .. result
                    --print(results)
                    adp.add {
                        --图=loadbitmap(results),
                        图 = (results),
                    }
                end
            end
        end)
    else
        Http.get(xyycc, function(a, b)
            if a == 200 then
                bs = string.gsub(b, "-", "_")
                范围 = b:match([[page(.-)5px]])
                exwz = 范围:gmatch([[src="https://n(.-)" alt=]])
                额 = bs:match([[class="next_chapter"(.-)>]])
                xyy = 额:match([["(.-)"]])
                xyycc = xyy
                复制文本(xyycc)
                for result in exwz do
                    results = "https://n" .. result
                    --print(results)
                    adp.add {
                        -- 图=loadbitmap(results),
                        图 = (results),
                    }
                end
            end
        end)
    end
end

function 加载图片()
    layout =
    {
        LinearLayout,
        orientation = "vertical",
        layout_width = "fill",
        layout_height = "fill",
        {
            LinearLayout,
            orientation = "vertical",
            layout_width = "fill",
            layout_height = "fill",
            layout_margin = "6dp",
            {
                GridView,
                layout_width = "fill",
                layout_height = "fill",
                gravity = "center",
                numColumns = "1",
                verticalScrollBarEnabled = false,
                id = "shows",
            },
        },
    }
    AlertDialog.Builder(this)
               .setTitle("可能加载不出来..")
               .setView(loadlayout(layout))
               .setPositiveButton("确定", function()
    end)
               .setNeutralButton("退出", nil)
               .show()
    bj =
    {
        LinearLayout,
        gravity = "center",
        orientation = "vertical",
        layout_width = "fill",
        layout_height = "fill",
        {
            ImageView,
            scaleType = "fitXY",
            src = "",
            id = "图",
        },
    }
    adp = LuaAdapter(activity, bj)
    shows.setAdapter(adp)
    获取()
    shows.setOnScrollListener {
        onScrollStateChanged = function(l, s)
            if shows.getLastVisiblePosition() == shows.getCount() - 1 then
                获取()
            end
        end
    }
end

item = {
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

start.onClick = function()
    储存, xyycc = "", ""
    novel()
end
list.onItemClick = function(a, b)
    --print(b.Tag.小说id.Text)
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
                        id = "gb",
                        onClick = function()
                            tcl.dismiss()
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
                    -- text="【"..sb.."】《"..sb1.."》",本来是用来储存内容的
                    textSize = "0sp",
                    id = "xx",
                },
                {
                    ListView,
                    layout_width = "fill",
                    layout_height = "fill",
                    dividerHeight = "1",
                    id = "lists",
                },
            },
        },
    }
    tcl = AlertDialog.Builder(this)
    tcl.setView(loadlayout(layout))
    tcl = tcl.show()
    tcl.getWindow().setBackgroundDrawable(ColorDrawable(0x00000000))
    function 更新数据(更新)
        adp = ArrayAdapter(activity, android.R.layout.simple_list_item_1, String(更新))
        lists.setAdapter(adp)
    end

    标题 = {}
    内容 = {}
    Http.get(b.Tag.小说id.Text, function(a, b)
        c = 0
        if a == 200 then
            b = b:match([[class="Drama(.-)title=]])
            取 = b:gmatch([[href="(.-)"(.-)<span>(.-)<]])
            for b, y, a in 取 do
                标题[#标题 + 1] = a
                内容[a] = b
                更新数据(标题)
            end
        else
            if a == -1 then
                --print("请检查网络是否开启")
            else
                --print("")
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
    lists.onItemClick = function(a, b)
        --本来这里就应该要跳转子界面了..
        --activity.newActivity("ydq",android.R.anim.fade_in,android.R.anim.fade_out,{xx.Text,内容[b.Text]})
        --为了应对环境，这边继续用弹窗
        --复制文本(内容[b.Text])不得不吐槽一下，
        --访问原站考察，搞的我一个男的都激动起来了
        储存 = 内容[b.Text]
        xyycc = 内容[b.Text]
        加载图片()
        --print(b.Text)--名称
        --print(内容[b.Text])--链接
        return true
    end
    lists.onItemLongClick = function(a, b)
        --print(b.Text)
        --print(内容[b.Text])
        return true
    end
    return true
end

参数 = 0
function onKeyDown(code, event)
    if string.find(tostring(event), "KEYCODE_BACK") ~= nil then
        if 参数 + 2 > tonumber(os.time()) then
            activity.finish()
        else
            Toast.makeText(activity, "再按一次返回键退出", Toast.LENGTH_SHORT)
                 .show()
            参数 = tonumber(os.time())
        end
        return true
    end
end
