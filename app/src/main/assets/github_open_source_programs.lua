require("import")
require("rxteam")
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
activity.setTitle("使用到的GitHub项目")
layout = {
    LinearLayout;
    orientation = "vertical";
    layout_width = "fill";
    background = "#ffeeeeee";
    layout_height = "fill";
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
activity.setContentView(loadlayout(layout))
layout2 = {
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
                textColor = "#000000";
                layout_width = "match_parent";
                layout_marginRight = "20dp";
                id = "标题";
                layout_marginTop = "20dp";
            };
            {
                TextView;
                textColor = "#000000";
                layout_width = "match_parent";
                id = "内容";
                layout_margin = "20dp";
            };
        };
    };
};
adp = LuaAdapter(activity, layout2)
local data = {
    
    { title = "aria2", content = "https://github.com/aria2/aria2" },
    { title = "AriaNg", content = "https://github.com/mayswind/AriaNg" },
    { title = "腾讯浏览服务", content = "https://x5.tencent.com/" },
    { title = "AndroLua_pro", content = "https://github.com/nirenr/AndroLua_pro" },
    { title = "iptv-org", content = "https://github.com/iptv-org/iptv" },
    { title = "RXbox", content = "https://github.com/renxinyileng/RXbox" },
    { title = "aria2NGandroid", content = "https://github.com/Xmader/aria-ng-gui-android/" },
    { title = "PdfViewPager", content = "https://github.com/voghDev/PdfViewPager" }
}

local function onItemClick(parent, view, position, id)
    local item = adp.getItem(position+1)
    local title = item.title
    local content = item.content
    提示("正在打开项目" .. title)
    浏览器打开(content)
end
for i=1,#data do
    adp.add{标题={text=data[i].title}, 内容={text=data[i].content}}
end
list.Adapter = adp
list.onItemClick = onItemClick
list.Adapter = adp