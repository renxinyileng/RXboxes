require "import"
import "java.io.File"



--iApp函数库
--荼山 2879700093
--GameLua+交流群：704194917
--游戏开发交流群：776020460
--更新日期：2021-10-17


--提示内容，显示位置，x偏移，y偏移
function tw(s,l,x,y)
  if not s then return end
  if not l then
    l = Gravity.BOTTOM
    x, y = 0, 0
  end
  if type(x) ~= "number" then x = 0 end
  if type(y) ~= "number" then y = 0 end
  Toast.makeText(activity,tostring(s), Toast.LENGTH_LONG).setGravity(l, x, y).show()
  return true
end







--删除文件
--文件路径，返回执行结果 true/false
function fd(p)
  if not File(p).isFile() then return end
  if File(p).delete() then return true else
    if os.remove(p) then return true else
      local o = os.execute("rm -r "..tostring(p))
      return o
    end
  end
end





--文件(夹)是否存在，返回true/false
function fe(p)
  return File(p).exists()
end




--文件大小
--文件路径，返回文件大小 number
function fs(p)
  import "android.text.format.Formatter"
  size=File(tostring(p)).length()
  Sizes=Formatter.formatFileSize(activity, size)
  return Sizes
end



--读取文件
--文件路径，返回文件内容
function fr(p)
  return io.open(p):read("*a")
end




--复制文件
--文件路径，目标路径(要复制到的路径)， 返回结果 true/false
function fc(p1, p2)
  return LuaUtil.copyDir(p1, p2)
end





--写入文件
--文件路径，写入内容，返回结果
function fw(p,s)
  local f = File(tostring(File(tostring(p)).getParentFile())).mkdirs()
  local o = io.open(tostring(p),"w"):write(tostring(s)):close()
  return o
end





--文件列表
--路径
function fl(p)
  return luajava.astable(File(p).listFiles())
end





--文件转移
--文件路径，目标路径(要转移到的路径)
function ft(p1, p2)
  if File(p1).renameTo(File(p2)) then return true else
    local o = os.execute("mv "..tostring(p1).." "..tostring(p2))
    return o
  end
end



--获取sd卡根目录
--返回sd卡根目录
function fdir()
  return Environment.getExternalStorageDirectory().toString()
end



--解压zip
--zip路径，解压路径，返回执行结果
function fuzs(z,p)
  local o = ZipUtil.unzip(tostring(z),tostring(p))
  return o
end





--压缩文件
--要压缩的文件(夹)，压缩文件到目录，返回执行结果
function fj(z,p)
  local o = ZipUtil.zip(z,p)
  return o
end





--打开文件
--文件路径
function fo(p)
  import "android.webkit.MimeTypeMap"
  import "android.content.Intent"
  import "android.net.Uri"
  import "java.io.File"
  FileName=tostring(File(path).Name)
  ExtensionName=FileName:match("%.(.+)")
  Mime=MimeTypeMap.getSingleton().getMimeTypeFromExtension(ExtensionName)
  if Mime then
    intent = Intent();
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    intent.setAction(Intent.ACTION_VIEW);
    intent.setDataAndType(Uri.fromFile(File(p)), Mime);
    activity.startActivity(intent);
   else
    tw("找不到可以用来打开此文件的程序")
  end
end





--字符替换
--字符，替换前字符，替换后字符
function sr(s,ss,se)
  return string.gsub(s,ss,se)
end




--获取字符长度
--字符
function slg(s)
  return utf8.len(s)
end





--去除头尾空格
--字符
function strim(s)
  return string.gsub(s, "^[%s]*(.-)[%s]*$", "%1")
end






--转为小写
--字符
function slower(s)
  return string.lower(s)
end




--转为大写
--字符
function supper(s)
  return string.upper(s)
end






--产生范围随机数
--最小数，最大数
function sran(n1,n2)
  return math.random(n1,n2)
end






--获取网页源码
--网址
function hs(u)
  local body,cookie,code,headers=http.get(u)
  return body
end







--下载文件
--网址，保存路径
function hd(u,p)
  local o = http.download(u,p)
  return o
end



--上传文件
--网址，文件标题，文件路径
function fu(u,t,p)
  local o = http.upload(u,{title=t,msg="上传文件"},{file1=p})
  return o
end




--提交数据
--网址，数据
function hp(u,d)
  local body,cookie,code,headers=http.post(u,d)
  return body
end





--调用浏览器打开网页
--网址
function hws(u)
  import "android.content.Intent"
  import "android.net.Uri"
  viewIntent = Intent("android.intent.action.VIEW",Uri.parse(u))
  activity.startActivity(viewIntent)
end






--跳转界面
--界面名称，参数
function uigo(u,d)
  activity.newActivity(u,d)
end






--关闭界面
function uiend()
  activity.finish()
end




--程序最小化
function uiends()
  import "android.content.Intent"
  intent=Intent();
  intent.setAction("android.intent.action.MAIN");
  intent.addCategory("android.intent.category.HOME");
  activity.startActivity(intent)
end




--获取当前时间戳
function time()
  return os.time()
  --[[返回一个指定时间点的UNIX时间戳，如不带参数调用的话，就返回当前时间点的UNIX时间戳。
参数table字段包括{
year  年份
month  月份(01-12)
day  天(01-31)
hour  时(00-23)
min  分(00-59)
sec  秒(00-59)
isdst  布尔值，true表示夏令时
其中，year、month、day 三个字段是必须的，其它字段默认取 12:00:00
}]]
end



--获取当前时间
--时间格式，格式化
function date(a,b)
  return os.date(a,b)
end





--判断路径是否是文件架
--路径
function fi(p)
  return File(p).isDirectory()
end




--获取屏幕分辨率
function swh(l)
  if l == "w" then
    return activity.getWidth()
  end
  if l == "h" then
    return activity.getHeight()
  end
end




--隐藏状态栏
--true 隐藏状态栏，false显示
function uycl(b)
  if b then
    activity.getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,WindowManager.LayoutParams.FLAG_FULLSCREEN)
   else
    activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
  end
end





--设置横竖屏
--true 横屏，false竖屏
function ushsp(b)
  if b then
    activity.setRequestedOrientation(0)
   else
    activity.setRequestedOrientation(1)
  end
end








--卸载应用app
--包名
function uninapp(b)
  import "android.net.Uri"
  import "android.content.Intent"
  uri = Uri.parse("package:"..tostring(b))
  intent = Intent(Intent.ACTION_DELETE,uri)
  activity.startActivity(intent)
end







--写入剪切板
--内容
function sxb(s)
  import "android.content.*"
  activity.getSystemService(Context.CLIPBOARD_SERVICE).setText(s)
end




--获取剪切板
function shb()
  import "android.content.Context"
  return activity.getSystemService(Context.CLIPBOARD_SERVICE).getText()
end





--手机休眠
--false 常亮，true 休眠
function usjxm(b)
  import "android.content.Context"
  if b then
    this.getSystemService(Context.POWER_SERVICE).newWakeLock(PowerManager.SCREEN_DIM_WAKE_LOCK,"MyTag").release()
   else
    this.getSystemService(Context.POWER_SERVICE).newWakeLock(PowerManager.SCREEN_DIM_WAKE_LOCK,"MyTag").acquire()
  end
end




--跳转界面动画
--动画，默认淡出淡入
function lan(a)
  if not a then
    a = android.R.anim.fade_in,android.R.anim.fade_out
  end
  activity.overridePendingTransition(a)
end




--背景调控器
--控件id，边框宽度，圆角度数，内部颜色，边框颜色
function ngde(view,Thickness,radiu,InsideColor,FrameColor)
  import "android.graphics.drawable.GradientDrawable"
  drawable = GradientDrawable()
  drawable.setShape(GradientDrawable.RECTANGLE)
  drawable.setStroke(Thickness, FrameColor)
  drawable.setColor(InsideColor)
  drawable.setCornerRadii({radiu,radiu,radiu,radiu,radiu,radiu,radiu,radiu});
  view.setBackgroundDrawable(drawable)
end




--背景调控器2
--控件id，边框宽度，各个圆角度数，内部颜色，边框颜色
function ngdes(view,Thickness,r1,r2,r3,r4,r5,r6,r7,r8,InsideColor,FrameColor)
  import "android.graphics.drawable.GradientDrawable"
  drawable = GradientDrawable()
  drawable.setShape(GradientDrawable.RECTANGLE)
  drawable.setStroke(Thickness, FrameColor)
  drawable.setColor(InsideColor)
  drawable.setCornerRadii({r1,r2,r3,r4,r5,r6,r7,r8});
  view.setBackgroundDrawable(drawable)
end







--@荼山 2879700093
--QQ群：704194917


