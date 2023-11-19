require "import"
import "Pen_fun_Pavilion.hs"
activity.getSupportActionBar().hide()
FavoritePath = "/storage/emulated/0/Android/data/" .. tostring(activity.getPackageName()) .. "/笔趣阁/"
activity.setTitle("阅读记录")
local array = this.getTheme().obtainStyledAttributes({
    android.R.attr.colorAccent,
    android.R.attr.colorBackgroundFloating,
})
colorAccent = array.getColor(0, 0)
colorBackgroundFloating = array.getColor(1, 0)

Keyword = "fill"
Scrolled = {}
layout = {
    LinearLayout;
    layout_height = "fill";
    layout_width = "fill";
    orientation = "vertical";
    {
        LinearLayout,
        orientation = "horizontal",
        layout_width = "fill",
        layout_height = "56dp",
        layout_marginTop = 高,
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
            text = "☌", --懒得去找图片了
            textSize = "38sp",
            textColor = 0xff222222,
            onTouchListener = 点击缩放,
            id = "搜索",
        },
        {
            TextView,
            layout_marginRight = "18dp",
            text = "✱",
            textSize = "32sp",
            textColor = 0xff222222,
            onTouchListener = 点击缩放,
            id = "sz",

        },
    };
    {
        SwipeRefreshLayout,
        layout_width = "fill";
        layout_weight = 1;
        layout_height = "fill";
        id = "sr",
        {
            ListView;
            layout_height = "fill";
            fastScrollEnabled = true,
            id = "listView",
            layout_width = "fill";
        };
    },
    {
        CardView;
        layout_width = "fill";
        visibility = View.GONE;
        radius = 0;
        id = "BottomToolbar",
        elevation = "8dp";
        {
            LinearLayout;
            orientation = "horizontal";
            layout_width = "fill";
            layout_gravity = "center";
            paddingTop = "4dp",
            paddingBottom = "4dp",
            paddingStart = "12dp",
            paddingEnd = "12dp",
            {
                Button;
                id = "SelectAll",
                style = "?android:attr/buttonBarButtonStyle";
                text = "全选";
            };
            {
                Button;
                id = "Reverseselection",
                style = "?android:attr/buttonBarButtonStyle";
                text = "反选";
            };
            {
                Button;
                id = "cancel",
                style = "?android:attr/buttonBarButtonStyle";
                text = "重选";
            };
            {
                Space,
                visibility = View.INVISIBLE,
                layout_weight = 1;
            },
            {
                Button;
                text = "删除";
                id = "delete";
            };
        }
    }
}
activity.setContentView(layout)
activity.getSupportActionBar().setDisplayHomeAsUpEnabled(true)

local optmenu = {}
function onCreateOptionsMenu(menu)
    loadmenu(menu, {
        {
            MenuItem,
            title = "搜索",
            id = "搜索",
        },
    }, optmenu)
    optmenu.搜索.setShowAsActionFlags(1)
end

function onOptionsItemSelected(item)
    local id = item.getItemId()
    if id == android.R.id.home then
        activity.finish()
    end
    local item = tostring(item)
    if item == "搜索" then
        searchActionMode()
    end
end

function searchActionMode()
    SaveScrolled()
    activity.startActionMode(luajava.new(ActionMode.Callback, {
        onCreateActionMode = function(_, __)
            local imm = activity.getSystemService(Context.INPUT_METHOD_SERVICE)
            imm.toggleSoftInput(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE,
                InputMethodManager.SHOW_FORCED)
            _.setCustomView(loadlayout({
                EditText,
                layout_width = "fill",
                Focusable = true,
                FocusableInTouchMode = true,
                imeOptions = "actionSearch",
                Hint = "输入关键词...",
                style = "?android:attr/windowTitleStyle",
                id = "searchEdit",
            }))
            searchEdit.requestFocus()
            searchEdit.addTextChangedListener({
                afterTextChanged = function(text)
                    if BottomToolbar.getVisibility() == View.VISIBLE then
                        show_visibility(View.VISIBLE)
                    end
                    if tostring(text) == "" then
                        Refresh("fill")
                    else
                        Refresh(tostring(text))
                    end
                end
            })
            return true
        end,
        onDestroyActionMode = function()
            if BottomToolbar.getVisibility() == View.VISIBLE then
                show_visibility(View.VISIBLE)
            end
            SaveScrolled()
            Refresh("fill")
            activity.getSystemService(Context.INPUT_METHOD_SERVICE).hideSoftInputFromWindow(searchEdit.getWindowToken(), 0)
        end
    }))
end

function SaveScrolled()
    local listviewChildView = listView.getChildAt(0)
    local scroll
    if listviewChildView then
        scroll = listviewChildView.getTop()
    else
        scroll = 0
    end
    Scrolled[Keyword] = { listView.getFirstVisiblePosition(), scroll }
end

function Refresh(Keyword)
    sr.Refreshing = true
    activity.newTask(function(FavoritePath, Keyword)
        require "import"
        import "java.io.File"
        import "android.view.View"

        function 取文件名无后缀(path)
            return tostring(tostring(path):match(".+/(.+)%..+$"))
        end

        local FavoriteList = File(FavoritePath).listFiles()
        if FavoriteList ~= nil then
            FavoriteList = luajava.astable(File(FavoritePath).listFiles())
        else
            local FavoriteList = {}
        end

        local data = {}

        for index =# FavoriteList, 1, -1 do
            if Keyword then
                if Keyword == "fill" then
                    table.insert(data, {
                        标题 = 取文件名无后缀(FavoriteList[index]),
                        路径 = FavoriteList[index],
                        选择框 = { Checked = false, visibility = View.GONE }
                    })
                else
                    if string.find(取文件名无后缀(FavoriteList[index]), Keyword) then
                        table.insert(data, {
                            标题 = 取文件名无后缀(FavoriteList[index]),
                            路径 = FavoriteList[index],
                            选择框 = { Checked = false, visibility = View.GONE }
                        })
                    end
                end
            end
        end

        return data, Keyword
    end, function(data, Keyword)
        _G.data = data
        _G.Keyword = Keyword

        if adp then
            luajava.clear(adp)
        end
item={
    LinearLayout;
    layout_width="-1";
    padding="16dp";
    {
        LinearLayout;
        layout_weight=1;
        orientation="vertical";
        layout_gravity="center";
        {
            TextView;
            layout_marginRight="16dp";
            style="?android:attr/textStyle";
            id="标题";
        };
        {
            TextView;
            Visibility=View.GONE,
            id="路径";
        };
        {
            TextView;
            Visibility=View.GONE,
            id="内容";
        };
        {
            TextView;
            Visibility=View.GONE,
            id="作者";
        };

    },
    {
        CheckBox;
        layout_gravity="center";
        id="选择框";
        layout_marginLeft="16dp";
        focusable=false;
        clickable=false;
    };
};
        adp = LuaAdapter(activity, data, item)
        listView.Adapter = adp

        local scrolled = Scrolled[Keyword]
        if scrolled then
            listView.setSelectionFromTop(scrolled[1], scrolled[2])
        end

        sr.Refreshing = false
    end
    ).execute({ FavoritePath, Keyword })
end

function show_visibility(check)
    if check == View.GONE then
        sr.Enabled = false
        BottomToolbar.Visibility = View.VISIBLE
        for k = #data, 1, -1 do
            data[k].选择框.Checked = false
            data[k].选择框.visibility = View.VISIBLE
        end
        return true
    else
        sr.Enabled = true
        BottomToolbar.Visibility = View.GONE
        for k = #data, 1, -1 do
            data[k].选择框.Checked = false
            data[k].选择框.visibility = View.GONE
        end
        return false
    end
    adp.notifyDataSetChanged()
end

listView.onItemClick = function(l, v, p, i)
    -- print(data[i].路径)
    jc = io.open(tostring(data[i].路径)):read("*a")
    named = jc:match([[<(.-)>]])
    段落 = jc:match([[@(.-)@]])
    url = jc:match([[url={(.-)}]])
    时间 = jc:match("([^\n]+)$")
    标题 = "重要提示"
    内容 = "检测到您有阅读过该小说的记录\n" .. 段落 .. "\n是否继续阅读"
    确认事件 = [[activity.newActivity("Pen_fun_Pavilion/ydq",{named,url})]]
    取消事件 = [[b=1]]
    弹出通知(标题, 内容, 确认事件, 取消事件)
    if data[i].选择框.visibility == View.VISIBLE then
        if data[i].选择框.Checked then
            data[i].选择框.Checked = false
        else
            data[i].选择框.Checked = true
        end
        adp.notifyDataSetChanged()
    else

    end
    return true
end

listView.onItemLongClick = function(l, v, p, i)
    show_visibility(data[i].选择框.visibility)
    data[i].选择框.Checked = true
    return true
end

--全选
SelectAll.onClick = function()
    for n = #data, 1, -1 do
        data[n].选择框.Checked = true
    end
    adp.notifyDataSetChanged()
end

--反选
Reverseselection.onClick = function()
    for n = #data, 1, -1 do
        if data[n].选择框.Checked then
            data[n].选择框.Checked = false
        else
            data[n].选择框.Checked = true
        end
    end
    adp.notifyDataSetChanged()
end

--取消全部
cancel.onClick = function()
    for n = #data, 1, -1 do
        data[n].选择框.Checked = false
    end
    adp.notifyDataSetChanged()
end

--删除
delete.onClick = function()
    for n = #data, 1, -1 do
        if data[n].选择框.Checked then
            os.remove(tostring(data[n].路径))
            adp.remove(n - 1)
            if #data == 0 then
                show_visibility(View.VISIBLE)
            end
        end
    end
end

sr.setColorSchemeColors({ colorAccent })
sr.setProgressBackgroundColorSchemeColor(colorBackgroundFloating)
sr.setOnRefreshListener(SwipeRefreshLayout.OnRefreshListener {
    onRefresh = function()
        Scrolled[Keyword] = nil
        Refresh(Keyword)
    end
})
sr.post(Runnable {
    run = function()
        sr.setRefreshing(true)
        Scrolled[Keyword] = nil
        Refresh(Keyword)
    end
})

function onKeyUp(KeyCode, event)
    if KeyCode == KeyEvent.KEYCODE_BACK then
        if BottomToolbar.getVisibility() == View.VISIBLE then
            show_visibility(View.VISIBLE)
            return true
        end
    end
end
