import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
--import "AndLua"
import "android.graphics.Typeface"
import "android.view.animation.DecelerateInterpolator"
import "android.graphics.drawable.ColorDrawable"
import "android.animation.ObjectAnimator"
import "android.widget.ArrayAdapter"
import "android.animation.AnimatorSet"
import "android.widget.TextView"
import "android.view.WindowManager"
import "android.animation.ObjectAnimator"
import "android.widget.Button"
import "android.graphics.drawable.GradientDrawable"
import "android.graphics.drawable.ColorDrawable"
import "android.app.AlertDialog"
import "android.widget.LinearLayout"
import "com.androlua.Http"
import "android.support.v4.widget.SwipeRefreshLayout"
import "java.io.File"
import "android.content.Context"
import "android.view.inputmethod.InputMethodManager"
import "com.androlua.LuaAdapter"
import "android.widget.ListView"
import "java.lang.String"
import "android.view.animation.AlphaAnimation"
import "android.view.animation.AnimationUtils"
import "android.animation.ObjectAnimator"
import "android.view.animation.AlphaAnimation"
import "android.graphics.Color"
import "android.animation.LayoutTransition"
--activity.setTheme(android.R.style.Theme_Material_Light)
activity.setTitle("")
activity.overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
local window = activity.getWindow()
window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS)
window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_STABLE)
window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
window.setStatusBarColor(Color.TRANSPARENT)
window.setNavigationBarColor(Color.parseColor("#fffffafa"))
高 = this.getResources().getDimensionPixelSize(luajava.bindClass("com.android.internal.R$dimen")().status_bar_height)

function qk(A, a)
    local B = string.gsub(A, "\n", a)
    local C = string.gsub(B, "          ", a)
    local D = string.gsub(C, "         ", a)
    local E = string.gsub(D, "        ", a)
    local F = string.gsub(E, "       ", a)
    local G = string.gsub(F, "      ", a)
    local H = string.gsub(G, "     ", a)
    local I = string.gsub(H, "    ", a)
    local J = string.gsub(I, "   ", a)
    local L = string.gsub(J, "  ", a)
    local N = string.gsub(L, " ", a)
    local I = string.gsub(N, [[
]]   , a)
    return I
end

function 复制文本(内容)
    activity.getSystemService(Context.CLIPBOARD_SERVICE).setText(内容)
end

function html转义(content)
    local content = content:gsub("amp;", "") or content;
    local content = content:gsub("&nbsp;", " ") or content;
    local content = content:gsub("&lt;", "<") or content;
    local content = content:gsub("&gt;", ">") or content;
    local content = content:gsub("&amp;", "&") or content;
    local content = content:gsub("&quot;", '"') or content;
    local content = content:gsub("&#39;", "'") or content;
    local content = content:gsub("&#47", "/") or content;
    local content = content:gsub("#x27", "\\") or content;
    local content = content:gsub("&#x60", "`") or content;
    local content = content:gsub("&copy", "©") or content;
    local content = content:gsub("<br%s+/>", "\n") or content;
    local content = content:gsub("</p><p>", "") or content;
    local content = content:gsub("<%/?p>", "") or content;
    local content = content:gsub("</div><div>", "") or content;
    local content = content:gsub("<%/?div>", "") or content;
    local content = content:gsub("<%/?span>", "") or content;
    return content
end

function 晃动动画(控件, 效果)
    local rotate = ObjectAnimator()
    if 效果 == "单" then
        rotate.ofFloat(控件, "scaleX", { 1, .9, 1.1, 1.2, .8, 1.1, .9, 1 }).start().setDuration(600)
    elseif 效果 == "双" then
        rotate.ofFloat(控件, "scaleX", { 1, .9, 1.1, 1.2, .8, 1.1, .9, 1 }).start()
        rotate.ofFloat(控件, "scaleY", { 1, .9, 1.1, 1.2, .8, 1.1, .9, 1 }).start().setDuration(1800)
    end
end

function 设置文本(控件ID, 内容, 大小, 颜色)
    控件ID.setText(内容)
    控件ID.setTextSize(大小)
    控件ID.setTextColor(颜色)
end

function 设置缩放(view, startscale, endscale, time)
    local animatorSetsuofang = AnimatorSet()
    local scaleX = ObjectAnimator.ofFloat(view, "scaleX", { startscale, endscale })
    local scaleY = ObjectAnimator.ofFloat(view, "scaleY", { startscale, endscale })
    animatorSetsuofang.setDuration(time)
    animatorSetsuofang.setInterpolator(DecelerateInterpolator())
    animatorSetsuofang.play(scaleX).with(scaleY)
    animatorSetsuofang.start()
end

点击缩放 = {
    onTouch = function(a, b)
        if b.action == 0 then
            设置缩放(a, 1, 0.95, 250)
        else
            设置缩放(a, 0.90, 1, 250)
        end
    end
}
--[[
function 全局字体(A0_8)
  function 字体()
    import "android.graphics.drawable.GradientDrawable"
    import "android.graphics.Typeface"
    import "java.io.File"
    return Typeface.createFromFile(File(activity.getLuaDir() .. A0_8))
  end
  import "android.graphics.Typeface"
  font = 字体()
  function setFont(A0_9)
    if luajava.instanceof(A0_9, TextView) then
      A0_9.setTypeface(font)
     elseif luajava.instanceof(A0_9, ViewGroup) then
      for _FORV_4_ = 0, A0_9.getChildCount() - 1 do
        setFont(A0_9.getChildAt(_FORV_4_))
      end
    end
  end
  setFont(activity.getDecorView())
end
--调用示范
全局字体("/ttf/zy.ttf")--这里调路径
]]
function Customfillet(Control, Color, Upperleft, Upperright, Lowerright, Lowerleft)
    import "android.graphics.drawable.GradientDrawable"
    drawable = GradientDrawable()
    drawable.setShape(GradientDrawable.RECTANGLE)
    drawable.setColor(Color)
    drawable.setCornerRadii({ Upperleft, Upperleft, Upperright, Upperright, Lowerright, Lowerright, Lowerleft, Lowerleft })
    Control.setBackgroundDrawable(drawable)
end

edrawable = GradientDrawable()
edrawable.setShape(GradientDrawable.RECTANGLE)
edrawable.setColor(0xFFA19FA0)
edrawable.setColor(0xfff5f2e9)
edrawable.setCornerRadii({ 24, 24, 24, 24, 24, 24, 24, 24 });
edrawable.setStroke(3, 0xFF000000, 0, 0)
Transparency = AlphaAnimation(0, 1)
Transparency.setDuration(800)
function 边框圆角(边宽度, 边框色, 背景色, 圆角度)
    import "android.graphics.drawable.GradientDrawable"
    drawable = GradientDrawable()
    drawable.setShape(GradientDrawable.RECTANGLE)
    drawable.setStroke(边宽度, tonumber(边框色))
    drawable.setColor(tonumber(背景色))
    drawable.setCornerRadius(圆角度)
    return drawable
end

function 复制文本(内容)
    activity.getSystemService(Context.CLIPBOARD_SERVICE).setText(内容)
end

function 弹出通知(标题, 内容, 事件, 事件1)
    弹窗框架 =
    {
        LinearLayout, --线性布局
        orientation = 'vertical', --方向
        layout_width = 'fill', --宽度
        layout_height = 'wrap', --高度
        background = '#00FFFFFF', --背景颜色或图片路径
        {
            CardView; --卡片控件
            layout_margin = '8dp'; --边距
            layout_gravity = 'center'; --重力
            --左:left 右:right 中:center 顶:top 底:bottom
            elevation = '5dp'; --阴影
            layout_width = '75%w'; --宽度
            layout_height = '45%w'; --高度
            CardBackgroundColor = '#ffffffff'; --颜色
            radius = '10dp'; --圆角
            {
                LinearLayout, --线性布局
                gravity = 'center'; --重力属性
                --左:left 右:right 中: 顶:top 底:bottom
                orientation = 'vertical', --方向
                layout_width = 'fill', --宽度
                layout_height = 'wrap', --高度
                background = '#00FFFFFF', --背景颜色或图片路径
                {
                    TextView; --文本控件
                    layout_marginTop = '5%w'; --顶距
                    gravity = 'center'; --重力
                    --左:left 右:right 中:center 顶:top 底:bottom
                    layout_width = 'fill'; --宽度
                    layout_height = 'wrap'; --高度
                    textColor = '#eb000000'; --文字颜色
                    text = 标题; --显示文字
                    textSize = '16dp'; --文字大
                };
                {
                    LinearLayout, --线性布局
                    gravity = 'center'; --重力属性
                    --左:left 右:right 中: 顶:top 底:bottom
                    orientation = 'vertical', --方向
                    layout_width = 'fill', --宽度
                    layout_height = '20%w', --高度
                    background = '#00ffffff', --背景颜色或图片路径
                    {
                        TextView; --文本控件
                        padding = "6dp", --往内部元素的填充一定边距
                        MaxLines = 3; --设置最大输入行数
                        ellipsize = "end";
                        gravity = 'center'; --重力
                        --左:left 右:right 中:center 顶:top 底:bottom
                        layout_width = 'fill'; --宽度
                        layout_height = 'fill'; --高度
                        textColor = '#FF888888'; --文字颜色
                        text = 内容; --显示文字
                        textSize = '13dp'; --文字大小
                    };

                };
                {
                    TextView, --水平分割线
                    layout_width = "fill", --布局宽度
                    layout_height = "2px", --布局高度
                    layout_gravity = "center", --重力居中
                    backgroundColor = "#ffbebebe", --背景色
                };

                {
                    LinearLayout, --线性布局
                    orientation = 'horizontal', --方向
                    layout_width = 'fill', --宽度
                    layout_height = '15%w', --高度
                    background = '#00FFFFFF', --背景颜色或图片路径
                    {
                        LinearLayout, --线性布局
                        orientation = 'vertical', --方向
                        layout_width = '37%w', --宽度
                        layout_height = 'fill', --高度
                        background = '#00FFFFFF', --背景颜色或图片路径
                        {
                            TextView; --文本控件
                            gravity = 'center'; --重力
                            --左:left 右:right 中:center 顶:top 底:bottom
                            layout_width = 'fill'; --宽度
                            layout_height = 'fill'; --高度
                            textColor = '#eb000000'; --文字颜色
                            text = '取消'; --显示文字
                            textSize = '18dp'; --文字大小
                            id = "取消"
                        };
                    };
                    {
                        TextView, --垂直分割线
                        layout_width = "2px", --布局宽度
                        layout_height = "fill", --布局高度
                        layout_gravity = "center", --重力居中
                        backgroundColor = "#ffbebebe", --背景色
                    };
                    {
                        LinearLayout, --线性布局
                        orientation = 'vertical', --方向
                        layout_width = '37%w', --宽度
                        layout_height = 'fill', --高度
                        background = '#00FFFFFF', --背景颜色或图片路径
                        {
                            TextView; --文本控件
                            gravity = 'center'; --重力
                            --左:left 右:right 中:center 顶:top 底:bottom
                            layout_width = 'fill'; --宽度
                            layout_height = 'fill'; --高度
                            textColor = '#FF147CE4'; --文字颜色
                            text = '跳转'; --显示文字
                            textSize = '18dp'; --文字大小
                            id = "确认"
                        };
                    };
                };
            };
        };
    };
    hhh = AlertDialog.Builder(this)
    hhh.setView(loadlayout(弹窗框架))
    --hhh.setCancelable(false)--禁用返回键
    hhh = hhh.show()
    --背景透明
    import "android.graphics.drawable.ColorDrawable"
    hhh.getWindow().setBackgroundDrawable(ColorDrawable(0x00000000))
    function 波纹特效v2(颜色)
        import "android.content.res.ColorStateList"
        return activity.Resources.getDrawable(activity.obtainStyledAttributes({ android.R.attr.selectableItemBackground --[[Borderless]] })
            .getResourceId(0, 0))
            .setColor(ColorStateList(int[0]
                .class { int {} }, int { 颜色 or 0x20000000 }))
    end

    --调用方法
    确认.onClick = function() --点击事件
        hhh.dismiss() --关闭
        assert(loadstring(事件))()
    end;
    取消.onClick = function() --点击事件
        hhh.dismiss() --关闭
        assert(loadstring(事件1))()
    end;
    确认.foreground = 波纹特效v2(0xFFCECECE)
    取消.foreground = 波纹特效v2(0xFFCECECE)
end

function 扩散动画(a, b, c, d, e, f)
    local ksdh = ViewAnimationUtils.createCircularReveal(a, b, c, d, e)
    ksdh.setDuration(f).start()
end

function 控件圆角(颜色, 圆角1, 圆角2, 圆角3, 圆角4)
    local 圆角a = GradientDrawable()
    圆角a.setShape(GradientDrawable.RECTANGLE)
    圆角a.setColor(颜色)
    圆角a.setCornerRadii({ 圆角1, 圆角1, 圆角2, 圆角2, 圆角3, 圆角3, 圆角4, 圆角4 })
    return 圆角a
end

--[[防止小牛马二改
import "android.content.pm.PackageManager"
local pm = activity.getPackageManager();
local pm=pm.getPackageInfo(activity.getPackageName(),PackageManager.GET_SIGNATURES).signatures[0].hashCode()
pms=-1142147188
if pm~=pms then
  ----print("")
  task(1000,function()
    os.exit()
  end)
end]]
function 动画显示(控件)
    ObjectAnimator.ofFloat(控件, "translationY", { activity.getWidth(), 0 }).setDuration(300).start()
end

function 动画退出(控件1, 控件2)
    ObjectAnimator.ofFloat(控件1, "translationY", { 0, activity.getWidth() }).setDuration(300).start()
    task(200, function()
        控件2.dismiss() --去除
    end)
end

function print(内容)
    to = {
        LinearLayout;
        layout_height = "fill";
        layout_width = "fill";
        {
            RelativeLayout;
            layout_height = "match_parent";
            gravity = "center";
            layout_width = "match_parent";
            {
                LinearLayout;
                background = "res/tb.png";
                {
                    TextView;
                    gravity = "center";
                    id = "text";
                    layout_marginLeft = "25dp";
                    layout_marginTop = "20dp";
                    layout_width = "match_parent";
                    layout_height = "match_parent";
                    layout_marginRight = "20dp";
                    layout_marginBottom = "15dp";
                    textColor = "#030000";
                };
            };
        };
    };
    local toast = Toast.makeText(activity, "内容", Toast.LENGTH_SHORT).setView(loadlayout(to))
    text.Text = tostring(内容)
    toast.show()
end

参数 = 0
function onKeyDown(code, event)
    if string.find(tostring(event), "KEYCODE_BACK") ~= nil then
        if 参数 + 2 > tonumber(os.time()) then
            activity.finish()
        else
            --print("请再按一次退出")
            参数 = tonumber(os.time())
        end
        return true
    end
end
