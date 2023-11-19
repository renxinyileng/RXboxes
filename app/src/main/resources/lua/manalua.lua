require"import"

import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import"android.app.ActionBar$TabListener"
import"android.app.AlertDialog"
import"android.app.SearchManager"
import"android.animation.ObjectAnimator"
import"android.animation.ArgbEvaluator"
import"android.animation.ValueAnimator"
import"android.content.*"
import"android.content.DialogInterface"
import"android.content.Context"
import"android.content.Intent"
import"android.content.pm.PackageManager"
import"android.content.pm.ApplicationInfo"
import"android.content.res.*"
import"android.content.SharedPreferences"
import"android.graphics.*"
import"android.graphics.Bitmap"
import"android.graphics.Color"
import"android.graphics.drawable.*"
import"android.graphics.drawable.BitmapDrawable"
import"android.graphics.drawable.ColorDrawable"
import"android.graphics.drawable.GradientDrawable"
import"android.graphics.PorterDuff"
import"android.graphics.PorterDuffColorFilter"
import"android.graphics.Typeface"
import"android.graphics.Matrix"
import"android.graphics.Paint"
import"android.graphics.PorterDuffXfermode"
import"android.graphics.RectF"
import"android.graphics.PorterDuff$Mode"
import"android.graphics.Rect"
import"android.graphics.Canvas"
import"android.graphics.BitmapFactory"
import"android.media.MediaPlayer"
import"android.media.MediaMetadataRetriever"
import"android.net.*"
import"java.net.URLDecoder"
import"android.net.Uri"
import"android.net.TrafficStats"
import"android.os.Build"
import"android.opengl.*"
import"android.provider.MediaStore"
import"android.provider.Settings"
import"android.provider.Settings$Secure"
import"android.telephony.*"
import"android.text.Html"
import"android.text.format.Formatter"
import"android.text.SpannableString"
import"android.text.style.ForegroundColorSpan"
import"android.text.Spannable"
import"android.util.Config"
import"android.util.DisplayMetrics"
import"android.view.*"
import"android.view.animation.*"
import"android.view.animation.Animation$AnimationListener"
import"android.view.animation.AnimationUtils"
import"android.view.animation.LayoutAnimationController"
import"android.view.inputmethod.InputMethodManager"
import"android.view.View$OnFocusChangeListener"
import"android.webkit.MimeTypeMap"
import"android.widget.*"
import"android.widget.ArrayAdapter"
import"android.widget.LinearLayout"
import"android.widget.EditText"
import"android.widget.ListView"
import"android.widget.PullingLayout"
import"android.widget.TextView"
import"android.widget.TimePicker$OnTimeChangedListener"
import"java.io.File"
import"java.io.FileOutputStream"
import"java.lang.String"
import"java.util.zip.ZipFile"
import"android.graphics.drawable.ColorDrawable"

--ManaluaX所需的包
import"com.manalua.game.widget.ManaluaEditor"
import"com.manalua.game.widget.ManaluaAdapter"
import"com.yanzhenjie.kalle.download.Download"
import"com.yanzhenjie.kalle.Kalle"
import"com.yanzhenjie.kalle.download.Callback"

local  datas={}


--intent类操作(已整理)--20191222-----------------------------------------------------------------------------------
--1.调用系统发送短信
function datas.调用系统发送短信(内容1,号码1)
  uri = Uri.parse("smsto:"..号码1)
  intent = Intent(Intent.ACTION_SENDTO, uri)
  intent.putExtra("sms_body",内容1)
  intent.setAction("android.intent.action.VIEW")
  activity.startActivity(intent)
end
--2.加QQ群
function datas.加QQ群(群号)
  url="mqqapi://card/show_pslcard?src_type=internal&version=1&uin="..群号.."&card_type=group&source=qrcode"
  activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
end
--3.联系QQ
function datas.联系QQ(QQ号码)
  url="mqqwpa://im/chat?chat_type=wpa&uin="..QQ号码
  activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
end
--4.分享文件
function datas.分享文件(文件路径)
  FileName=tostring(File(文件路径).Name)
  ExtensionName=FileName:match("%.(.+)")
  Mime=MimeTypeMap.getSingleton().getMimeTypeFromExtension(ExtensionName)
  intent = Intent();
  intent.setAction(Intent.ACTION_SEND);
  intent.setType(Mime);
  file = File(文件路径);
  uri = Uri.fromFile(file);
  intent.putExtra(Intent.EXTRA_STREAM,uri);
  intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
  activity.startActivity(Intent.createChooser(intent, "分享到:"));
end
--5.分享文本
function datas.分享文本(文本内容)
  intent=Intent(Intent.ACTION_SEND);
  intent.setType("text/plain");
  intent.putExtra(Intent.EXTRA_SUBJECT, "分享");
  intent.putExtra(Intent.EXTRA_TEXT,文本内容);
  intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
  activity.startActivity(Intent.createChooser(intent,"分享到:"));
end
--6.调用系统浏览器搜索
function datas.调用系统浏览器搜索(搜索内容)
  intent = Intent()
  intent.setAction(Intent.ACTION_WEB_SEARCH)
  intent.putExtra(SearchManager.QUERY,搜索内容)
  activity.startActivity(intent)
end
--7.调用系统浏览器打开链接
function datas.调用系统浏览器打开链接(网页链接)
  viewIntent = Intent("android.intent.action.VIEW",Uri.parse(网页链接))
  activity.startActivity(viewIntent)
end
--8.打开程序
function datas.打开程序(程序包名)
  manager = activity.getPackageManager()
  open = manager.getLaunchIntentForPackage(程序包名)
  activity.startActivity(open)
end
--9.安装程序
function datas.安装程序(安装包路径)
  intent = Intent(Intent.ACTION_VIEW)
  intent.setDataAndType(Uri.parse("file://"..安装包路径), "application/vnd.android.package-archive")
  intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
  activity.startActivity(intent)
end
--10.卸载程序
function datas.卸载程序(包名)
  uri = Uri.parse("package:"..包名)
  intent = Intent(Intent.ACTION_DELETE,uri)
  activity.startActivity(intent)
end
--11.播放MP4
function datas.播放MP4(视频路径)
  intent = Intent(Intent.ACTION_VIEW)
  uri = Uri.parse("file://"..视频路径)
  intent.setDataAndType(uri,"video/mp4")
  activity.startActivity(intent)
end
--12.播放MP3
function datas.播放MP3(音乐路径)
  intent = Intent(Intent.ACTION_VIEW)
  uri = Uri.parse("file://"..音乐路径)
  intent.setDataAndType(uri,"audio/mp3")
  this.startActivity(intent)
end
--13.拨号
function datas.拨号(电话号码)
  uri = Uri.parse("tel:"..电话号码);
  intent = Intent(Intent.ACTION_CALL,uri);
  intent.setAction("android.intent.action.VIEW");
  activity.startActivity(intent);
end
--14.搜索应用
function datas.搜索应用(包名)
  intent = Intent("android.intent.action.VIEW")
  intent .setData(Uri.parse( "market://details?id="..包名))
  activity.startActivity(intent)
end
--14.调用系统打开文件
function datas.调用系统打开文件(path)
  FileName=tostring(File(path).Name)
  ExtensionName=FileName:match("%.(.+)")
  Mime=MimeTypeMap.getSingleton().getMimeTypeFromExtension(ExtensionName)
  if Mime then
    intent = Intent()
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    intent.setAction(Intent.ACTION_VIEW);
    intent.setDataAndType(Uri.fromFile(File(path)), Mime);
    activity.startActivity(intent)
    return true
   else
    return false
  end
end
--16.发送彩信
function datas.发送彩信(图片路径,邮件地址,邮件内容,类型)
  uri=Uri.parse("file://"..图片路径) --图片路径
  intent= Intent();
  intent.setAction(Intent.ACTION_SEND);
  intent.putExtra("address",邮件地址) --邮件地址
  intent.putExtra("sms_body",邮件内容) --邮件内容
  intent.putExtra(Intent.EXTRA_STREAM,uri)
  intent.setType(类型) --设置类型
  activity.startActivity(intent)
end
--17.调用系统设置
--ACTION_SETTINGS	系统设置
function datas.打开系统设置()
  local intent = Intent(Settings.ACTION_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_APN_SETTINGS APN设置
function datas.打开APN设置()
  local intent = Intent(Settings.ACTION_APN_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_LOCATION_SOURCE_SETTINGS 位置和访问信息
function datas.打开位置和访问信息设置()
  local intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_WIRELESS_SETTINGS 网络设置
function datas.打开网络设置()
  local intent = Intent(Settings.ACTION_WIRELESS_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_AIRPLANE_MODE_SETTINGS 无线和网络热点设置
function datas.打开无线和网络热点设置()
  local intent = Intent(Settings.ACTION_AIRPLANE_MODE_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_SECURITY_SETTINGS 位置和安全设置
function datas.打开位置和安全设置()
  local intent = Intent(Settings.ACTION_SECURITY_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_WIFI_SETTINGS 无线网WIFI设置
function datas.打开无线网WIFI设置()
  local intent = Intent(Settings.ACTION_WIFI_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_WIFI_IP_SETTINGS 无线网IP设置
function datas.打开无线网IP设置()
  local intent = Intent(Settings.ACTION_WIFI_IP_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_BLUETOOTH_SETTINGS 蓝牙设置
function datas.打开蓝牙设置()
  local intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_DATE_SETTINGS 时间和日期设置
function datas.打开时间和日期设置()
  local intent = Intent(Settings.ACTION_DATE_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_SOUND_SETTINGS 声音设置
function datas.打开声音设置()
  local intent = Intent(Settings.ACTION_SOUND_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_DISPLAY_SETTINGS 显示设置——字体大小等
function datas.打开显示设置()
  local intent = Intent(Settings.ACTION_DISPLAY_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_LOCALE_SETTINGS 语言设置
function datas.打开语言设置()
  local intent = Intent(Settings.ACTION_LOCALE_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_INPUT_METHOD_SETTINGS 输入法设置
function datas.打开输入法设置()
  local intent = Intent(Settings.ACTION_INPUT_METHOD_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_USER_DICTIONARY_SETTINGS 用户词典
function datas.打开用户词典()
  local intent = Intent(Settings.ACTION_USER_DICTIONARY_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_APPLICATION_SETTINGS 应用程序设置
function datas.打开应用程序设置()
  local intent = Intent(Settings.ACTION_APPLICATION_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_APPLICATION_DEVELOPMENT_SETTINGS 应用程序设置 开发设置
function datas.打开开发者选项()
  local intent = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_QUICK_LAUNCH_SETTINGS 快速启动设置
function datas.打开快速启动设置()
  local intent = Intent(Settings.ACTION_QUICK_LAUNCH_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_MANAGE_APPLICATIONS_SETTINGS 已下载（安装）软件列表
function datas.打开已下载软件列表()
  local intent = Intent(Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_SYNC_SETTINGS 应用程序数据同步设置
function datas.打开应用程序数据同步设置()
  local intent = Intent(Settings.ACTION_SYNC_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_NETWORK_OPERATOR_SETTINGS 可用网络搜索
function datas.打开可用网络搜索()
  local intent = Intent(Settings.ACTION_NETWORK_OPERATOR_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_DATA_ROAMING_SETTINGS 移动网络设置
function datas.打开移动网络设置()
  local intent = Intent(Settings.ACTION_DATA_ROAMING_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_INTERNAL_STORAGE_SETTINGS 默认存储设置
function datas.打开默认存储设置()
  local intent = Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS);
  activity.startActivity(intent);
end
--ACTION_MEMORY_CARD_SETTINGS 默认存储设置
function datas.打开SD卡存储设置()
  local intent = Intent(Settings.ACTION_MEMORY_CARD_SETTINGS);
  activity.startActivity(intent);
end
---------------------------------------------------------------------------------------

--仿FusionApp函数---------------------------------------------------
--进入子页面
function datas.进入子页面(页面,参数)
  if 参数==nil then
    activity.newActivity(页面)
   elseif 参数["链接"]==nil then
    activity.newActivity(页面)
   elseif 参数["标题"]==nil then
    链接=参数["链接"]
    标题=参数["标题"]
    activity.newActivity(页面,{链接,标题})
   else
    链接=参数["链接"]
    标题=参数["标题"]
    activity.newActivity(页面,{链接,标题})
  end
end
--加载Js
function datas.加载Js(kid,a)
  kid.loadJs(a)
end
function datas.删除网页元素(kid,m)
  --网页加载完成
  kid.loadJs([[
//创建广告类名字符串
var classNames=new Array(]]..m..[[);
//主要拦截广告函数
function datas.removeAD(){ 
  for(index=0;index<classNames.length;index++){  
    if (classNames[index].indexOf("@ID(")>=0){
     document.getElementById(classNames[index].substring(4,classNames[index].length-1)).style.display="none"      
      }else{
         var elements=document.getElementsByClassName(classNames[index])  
         for(i=0;i<elements.length;i++){ 
         elements[i].style.display="none"
        }                                                                                
     }                                          
   }                                           
}                   
//添加定时器
mInterval=window.setInterval(removeAD,0);
//添加一次性定时器
mTimeout=window.setTimeout(function(e){ 
  window.clearInterval(mInterval)
  window.clearTimeout(mTimeout) 
},5000);
//添加元素改变监听
window.addEventListener('DOMSubtreeModified',removeAD)]])

end
--加载网页
function datas.加载网页(kid,b)
  kid.loadUrl(b)
end
--刷新网页
function datas.刷新网页(kid)
  kid.loadUrl(kid.getUrl())
end
--网页前进
function datas.网页前进(kid)
  kid.goForward()
end
--网页后退
function datas.网页后退(kid)
  kid.goBack()
end
--停止加载
function datas.停止加载(kid)
  kid.stopLoading()
end
--退出程序
function datas.退出程序()
  os.exit()
end
--退出页面
function datas.退出页面()
  activity.finish()
end
-----------------------------------------------------------------

--文件操作---------------------------------------------------
--获取文件/文件夹大小
function datas.GetFileSize(path)
  size=File(tostring(path)).length()
  Sizes=Formatter.formatFileSize(activity, size)
  return Sizes
end
--文件是否存在
function datas.文件是否存在(id)
  return File(id).exists()
end
--文件夹是否存在
function datas.文件夹是否存在(id)
  return File(id).isDirectory()
end
--创建多级文件夹
function datas.创建多级文件夹(路径)
  File(路径).mkdirs()
end
--创建文件夹
function datas.创建文件夹(路径)
  File(路径).mkdir()
end
--创建文件
function datas.创建文件(id)
  return File(id).createNewFile()
end
--写入文件
function datas.写入文件(路径,内容)
  f=File(tostring(File(tostring(路径)).getParentFile())).mkdirs()
  io.open(tostring(路径),"w"):write(tostring(内容)):close()
end
--读取文件
function datas.读取文件(ml)
  return io.open(ml):read("*a")
end
--删除文件
function datas.删除文件(path)
  return LuaUtil.rmDir(File(tostring(path)))
end
--解压文件
function datas.解压文件(a,b)
  return ZipUtil.unzip(a,b)
end
--复制文件
function datas.复制文件(ak,ao)
  LuaUtil.copyDir(ak,ao)
end
-----------------------------------------------------------------

--实用函数--------------------------------------------------------------------------------------------------------------------------------------------------
--设备特征码/设备ID
function datas.获取设备ID()
  return Secure.getString(activity.getContentResolver(),Secure.ANDROID_ID)
end
--获取设备IMEI
function datas.获取设备IMEI()
  return activity.getSystemService(Context.TELEPHONY_SERVICE).getDeviceId()
end
--获取设备屏幕尺寸
function datas.获取设备屏幕尺寸(ctx)
  dm = DisplayMetrics();
  ctx.getWindowManager().getDefaultDisplay().getMetrics(dm);
  diagonalPixels = Math.sqrt(Math.pow(dm.widthPixels, 2) + Math.pow(dm.heightPixels, 2));
  return diagonalPixels / (160 * dm.density);
end
--后台发送短信
function datas.后台发送短信(内容,号码)
  SmsManager.getDefault().sendTextMessage(tostring(号码),nil,tostring(内容),nil,nil)
end
--获取剪切板内容
function datas.获取剪切板内容()
  return activity.getSystemService(Context.CLIPBOARD_SERVICE).getText()
end
--复制文本
function datas.复制文本(文本内容)
  activity.getSystemService(Context.CLIPBOARD_SERVICE).setText(文本内容)
end
--关闭WIFI
function datas.关闭WIFI()
  wifi = activity.Context.getSystemService(Context.WIFI_SERVICE)
  wifi.setWifiEnabled(false)
end
--打开WIFI
function datas.打开WIFI()
  wifi = activity.Context.getSystemService(Context.WIFI_SERVICE)
  wifi.setWifiEnabled(true)
end
-----------------------------------------------------------------

--基础，界面操作------------------------------------------------------------------------------
--APPLUA内置提示
function datas.APPLUA内置提示(str,a,b,c)
  toasts={
    CardView;
    id="toastb",
    CardElevation=c;
    radius="1dp";
    layout_width="fill";
    background=a;
    {
      TextView;
      layout_marginTop="12dp";
      layout_marginBottom="12dp";
      textSize="13sp";
      TextColor=b,
      layout_gravity="center";
      text="Hello Ori";
      id="mess",
    };
  };
  message=tostring(str)
  local toast=Toast.makeText(activity,"内容",Toast.LENGTH_SHORT);
  toast.setGravity(Gravity.BOTTOM|Gravity.FILL_HORIZONTAL, 0, 0)
  toast.setView(loadlayout(toasts))
  mess.Text=message
  toast.show()
end
--删除浏览器进度条
function datas.删除浏览器进度条(kid)
  kid.removeView(kid.getChildAt(0))
end
--设置图片src
function datas.设置图片src(id,id2)
  id.setImageBitmap(loadbitmap(id2))
end
--关闭弹窗
function datas.关闭弹窗(id)
  id.hide()
end
--跳转页面2
function datas.跳转页面2(id,id2)
  id.onClick=function()
    activity.newActivity(id2,android.R.anim.fade_in,android.R.anim.fade_out)
  end
end
--弹出菜单
function datas.弹出菜单(id)
  id.onClick=function()
    pop.show()
  end
end
--设置文本
function datas.设置文本(a,b)
  a.setText(b)
end
--获取屏幕宽
function datas.获取屏幕宽()
  return activity.getWidth()
end
--获取屏幕高
function datas.获取屏幕高()
  return activity.getHeight()
end
--获取文本
function datas.获取文本(id)
  return id.text
end
--编辑框颜色
function datas.编辑框颜色(id,cc)
  id.getBackground().setColorFilter(PorterDuffColorFilter(cc,PorterDuff.Mode.SRC_ATOP));
end
--进度条颜色
function datas.进度条颜色(id,cc)
  id.IndeterminateDrawable.setColorFilter(PorterDuffColorFilter(cc,PorterDuff.Mode.SRC_ATOP))
end
--控件颜色
function datas.控件颜色(id,cc)
  id.setBackgroundColor(cc)
end
--获取手机存储路径
function datas.获取手机存储路径()
  return Environment.getExternalStorageDirectory().toString()
end
--打印
function datas.打印(id)
  print(id)
end
--提示
function datas.提示(id)
  Toast.makeText(activity,id,Toast.LENGTH_SHORT).show()
end
--自定义位置提示
function datas.自定义位置提示(nr,a,b,c)
  Toast.makeText(activity,nr, Toast.LENGTH_LONG).setGravity(a, b, c).show()
end
--带图片的提示
function datas.带图片的提示(id,oe)
  图片=loadbitmap(oe)
  toast = Toast.makeText(activity,id, Toast.LENGTH_LONG)
  toastView = toast.getView()
  imageCodeProject = ImageView(activity)
  imageCodeProject.setImageBitmap(图片)
  toastView.addView(imageCodeProject, 0)
  toast.show()
end
--自定义提示
function datas.自定义提示(nr,id)
  import (id)
  布局=loadlayout(id)
  local toast=Toast.makeText(activity,nr,Toast.LENGTH_SHORT).setView(布局).show()
end
--控件高
function datas.控件高(id,id2)
  id.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT,id2))
end
--控件宽
function datas.控件宽(id,id2)
  id.setWidth(id2)
end
--文本颜色
function datas.文本颜色(id,id2)
  id.setTextColor(id2)
end
--导入包类
function datas.导入包类(a)
  return import(a)
end
--点击事件
function datas.点击事件(a,ok)
  a.onClick=ok
end
--长按事件
function datas.长按事件(a,ok)
  a.onLongClick=ok
end
--列表项目被单击
function datas.列表项目被单击(a,ok)
  a.onItemClick=ok
end
--列表项目被长按
function datas.列表项目被长按(a,ok)
  a.onItemLongClick=ok
end
--控件可视
function datas.控件可视(id)
  id.setVisibility(0)
end
--控件不可视
function datas.控件不可视(id)
  id.setVisibility(8)
end
--关闭侧滑
function datas.关闭侧滑(ch)
  ch.closeDrawer(3)
end
--打开侧滑
function datas.打开侧滑(ch)
  ch.openDrawer(3)
end
--关闭右侧滑
function datas.关闭右侧滑(ch)
  ch.closeDrawer(5)
end
--打开右侧滑
function datas.打开右侧滑(ch)
  ch.openDrawer(5)
end
--关闭左侧滑
function datas.关闭左侧滑(ch)
  ch.closeDrawer(3)
end
--打开左侧滑
function datas.打开左侧滑(ch)
  ch.openDrawer(3)
end
--设置主题
function datas.设置主题(theme)
  activity.setTheme(theme)
end
--设置标题栏标题
function datas.设置标题(标题)
  activity.setTitle(标题)
end
--隐藏标题栏
function datas.隐藏标题栏()
  activity.ActionBar.hide()
end
--设置布局
function datas.设置布局(a)
  activity.setContentView(loadlayout(a))
end
--布局内插入布局
function datas.布局内插入布局(控件,布局)
  控件.addView(loadlayout(布局))
end
--使弹出的输入法不影响布局
function datas.使弹出的输入法不影响布局()
  activity.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_PAN)
end

function datas.取消标题栏阴影()
  activity.ActionBar.setElevation(0)
end
function datas.编辑框光标颜色修改函数(id,Color)
  import 'android.graphics.Color'
  import 'android.graphics.PorterDuff'
  import 'android.graphics.PorterDuffColorFilter'
  local mEditorField = TextView.getDeclaredField('mEditor')
  mEditorField.setAccessible(true)
  local mEditor = mEditorField.get(id)
  local field = Editor.getDeclaredField('mCursorDrawable')
  field.setAccessible(true)
  local mCursorDrawable = field.get(mEditor)
  local mccdf = TextView.getDeclaredField('mCursorDrawableRes')
  mccdf.setAccessible(true)
  local mccd = activity.getResources().getDrawable(mccdf.getInt(id))
  mccd.setColorFilter(PorterDuffColorFilter(Color,PorterDuff.Mode.SRC_ATOP))
  mCursorDrawable[0] = mccd
  mCursorDrawable[1] = mccd  
end
--使弹出的输入法影响布局
function datas.使弹出的输入法影响布局()
  activity.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
end
--重置当前页面
function datas.重置当前页面()
  activity.recreate()
end
--波纹
function datas.波纹(id,颜色)
  if Build.VERSION.SDK_INT <= 19 then
    local pressed = android.R.attr.state_pressed;
    local sd = StateListDrawable()
    id.setBackgroundDrawable(sd)
    sd.addState({ pressed }, ColorDrawable(颜色))
    --sd.addState({ 0 }, cd1)
   elseif Build.VERSION.SDK_INT > 19 then
    import "android.content.res.ColorStateList"
    local attrsArray = {android.R.attr.selectableItemBackgroundBorderless}
    local typedArray =activity.obtainStyledAttributes(attrsArray)
    ripple=typedArray.getResourceId(0,0)
    aoos=activity.Resources.getDrawable(ripple)
    aoos.setColor(ColorStateList(int[0].class{int{}},int{颜色}))
    id.setBackground(aoos.setColor(ColorStateList(int[0].class{int{}},int{颜色})))
  end
end
--控件圆角
function datas.控件圆角(id,颜色,圆角)
  drawable = GradientDrawable()
  drawable.setShape(GradientDrawable.RECTANGLE)
  drawable.setColor(颜色)
  
  drawable.setCornerRadii({圆角,圆角,圆角,圆角,圆角,圆角,圆角,圆角});
  id.setBackgroundDrawable(drawable)
end
--设置按钮颜色
function datas.设置按钮颜色(aa,id)
  aa.getBackground().setColorFilter(PorterDuffColorFilter(id,PorterDuff.Mode.SRC_ATOP))
end
--定时器
function datas.stop(time,fun)
  t=Ticker()
  t.Period=time
  t.start()
  t.onTick=fun
end
--揭开动画
function datas.circleopen(v,centerX,centerY,startRadius,endRadius,time)
  animator = ViewAnimationUtils.createCircularReveal(v,centerX,centerY,startRadius,endRadius);
  animator.setInterpolator(AccelerateInterpolator());
  animator.setDuration(time);
  animator.start();
end
--两角圆弧
function datas.两角圆弧(id,颜色,角度)
  drawable = GradientDrawable()
  drawable.setColor(颜色)
  drawable.setCornerRadii({角度,角度,角度,角度,0,0,0,0});
  id.setBackgroundDrawable(drawable)
end
--渐变
function datas.渐变(left_jb,right_jb,id)
  drawable = GradientDrawable(GradientDrawable.Orientation.TR_BL,{
    right_jb,--右色
    left_jb,--左色
  });
  id.setBackgroundDrawable(drawable)
end
---------------------------------------------------------------------------------------
--导航栏，状态栏操作----------------------------------------------------------------------
--导航栏颜色
function datas.导航栏颜色(a)
  if Build.VERSION.SDK_INT >= 21 then
    activity.getWindow().setNavigationBarColor(a);
   else
  end
end
--通知栏颜色
function datas.通知栏颜色(id)
  if Build.VERSION.SDK_INT >= 21 then
    activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS).setStatusBarColor(id);
  end
end
--状态栏颜色
function datas.状态栏颜色(id)
  if Build.VERSION.SDK_INT >= 21 then
    activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS).setStatusBarColor(id);
  end
end
--沉浸状态栏
function datas.沉浸状态栏()
  if Build.VERSION.SDK_INT >= 19 then
    activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS);
  end
end
--状态栏亮色
function datas.状态栏亮色()
  if Build.VERSION.SDK_INT >= 23 then
    activity.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
    --activity.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN)
  end
end
--状态栏暗色
function datas.状态栏暗色()
  if Build.VERSION.SDK_INT >= 23 then
    --activity.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
    activity.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN)
  end
end
--获取状态栏高度
function datas.获取状态栏高度()
  if Build.VERSION.SDK_INT >= 19 then
    resourceId = activity.getResources().getIdentifier("status_bar_height", "dimen", "android")
    return activity.getResources().getDimensionPixelSize(resourceId)
   else
    return 0
  end
end
--隐藏状态栏
function datas.隐藏状态栏()
  activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
end
---------------------------------------------------------------------------------------

--系统函数配置------------------------------------------------------------------------------
--写入文件
function datas.WriteFile(path,str)
  str=str:match"^%s*(.-)%s*$"
  io.open(path,"w"):write(str):close()
  return true
end
--dp转px
function datas.dpTopx(sdp)
  dm=this.getResources().getDisplayMetrics()
  types={px=0,dp=1,sp=2,pt=3,["in"]=4,mm=5}
  n,ty=sdp:match("^(%-?[%.%d]+)(%a%a)$")
  return TypedValue.applyDimension(types[ty],tonumber(n),dm)
end
--将Svg转换成png格式并保存
function datas.SavePng(SvgObj,path)
  task(1,function()
    mBitmap = Bitmap.createBitmap(tonumber(PNG尺寸大小),tonumber(PNG尺寸大小),Bitmap.Config.ARGB_8888);
    mCanvas = Canvas(mBitmap)
    SvgObj.renderToCanvas(mCanvas)
    mBitmap.compress(Bitmap.CompressFormat.PNG,100,FileOutputStream(path))
  end)
end
--保存Svg格式
function datas.SaveSvg(SvgName,SvgStr,id)
  WriteFile(SVG下载地址..SvgName..id..".svg",SvgStr)
end
--修改Swich颜色
function datas.修改Swich颜色(id,ys)
  id.ThumbDrawable.setColorFilter(PorterDuffColorFilter(ys,PorterDuff.Mode.SRC_ATOP));
  id.TrackDrawable.setColorFilter(PorterDuffColorFilter(ys,PorterDuff.Mode.SRC_ATOP))
end
--其他函数---------------------------------------------------
--取色器(Pretend)
--按钮着色
function datas.DialogButtonFilter(dialog,button,WidgetColor)
  if Build.VERSION.SDK_INT >= 21 then
    if button==1 then
      dialog.getButton(dialog.BUTTON_POSITIVE).setTextColor(WidgetColor)
     elseif button==2 then
      dialog.getButton(dialog.BUTTON_NEGATIVE).setTextColor(WidgetColor)
     elseif button==3 then
      dialog.getButton(dialog.BUTTON_NEUTRAL).setTextColor(WidgetColor)
    end
  end
end
--获取颜色
function datas.获取颜色()
  return bjk.Text
end
--颜色选择器
function datas.颜色选择器(bt,ys,kop)
  InputLayout={
    ScrollView;
    layout_width="fill";
    layout_height="fill";
    background=主页类颜色();
    {
      LinearLayout;
      orientation="vertical";
      layout_height="fill";
      layout_width="fill";
      background=主页类颜色();
      {
        CardView;
        layout_margin="20dp";
        background=主页类颜色();
        layout_width="100dp";
        layout_height="100dp";
        cardElevation="2dp";
        layout_gravity="center";
        id="bj";
        radius="50dp";
      };
      {
        EditText;
        singleLine="true";
        background=主页类颜色();
        Focusable=false;
        text="#00000000";
        layout_gravity="center";
        id="bjk";
        layout_marginTop="-10dp";
        textColor=静态主字体类颜色();
      };
      {
        LinearLayout;
        layout_width="fill";
        layout_marginTop="-5dp";
        {
          TextView;
          layout_margin="16dp";
          singleLine="true";
          textColor=静态主字体类颜色();
          gravity="center";
          text="A";
          layout_gravity="center";
          textSize="15sp";
        };
        {
          SeekBar;
          id="ac";
          layout_gravity="center";
          layout_weight="1";
          layout_width="fill";
        };
        {
          TextView;
          layout_margin="16dp";
          gravity="center";
          text="0";
          layout_gravity="center";
          id="aa";
          textColor=静态主字体类颜色();
        };
      };
      {
        LinearLayout;
        layout_width="fill";
        layout_marginTop="-10dp";
        {
          TextView;
          layout_margin="16dp";
          singleLine="true";
          textColor=静态主字体类颜色();
          gravity="center";
          text="R";
          layout_gravity="center";
          textSize="15sp";
        };
        {
          SeekBar;
          id="bc";
          layout_gravity="center";
          layout_weight="1";
          layout_width="fill";
        };
        {
          TextView;
          layout_margin="16dp";
          gravity="center";
          text="0";
          layout_gravity="center";
          id="ba";
          textColor=静态主字体类颜色();
        };
      };
      {
        LinearLayout;
        layout_width="fill";
        layout_marginTop="-10dp";
        {
          TextView;
          layout_margin="16dp";
          singleLine="true";
          textColor=静态主字体类颜色();
          gravity="center";
          text="G";
          layout_gravity="center";
          textSize="15sp";
        };
        {
          SeekBar;
          id="cc";
          layout_gravity="center";
          layout_weight="1";
          layout_width="fill";
        };
        {
          TextView;
          layout_margin="16dp";
          gravity="center";
          text="0";
          layout_gravity="center";
          id="ca";
          textColor=静态主字体类颜色();
        };
      };
      {
        LinearLayout;
        layout_width="fill";
        layout_marginTop="-10dp";
        {
          TextView;
          layout_margin="16dp";
          singleLine="true";
          textColor=静态主字体类颜色();
          gravity="center";
          text="B";
          layout_gravity="center";
          textSize="15sp";
        };
        {
          SeekBar;
          id="dc";
          layout_gravity="center";
          layout_weight="1";
          layout_width="fill";
        };
        {
          TextView;
          layout_margin="16dp";
          gravity="center";
          text="0";
          layout_gravity="center";
          id="da";
          textColor=静态主字体类颜色();
        };
      };
      {
        LinearLayout;
        layout_width="fill";
        gravity="center";
        visibility="8";
        orientation="horizontal";
        layout_height="fill";
        {
          TextView;
          text="00";
          id="as";
          textColor=静态主字体类颜色();
        };
        {
          TextView;
          text="00";
          id="bs";
          textColor=静态主字体类颜色();
        };
        {
          TextView;
          text="00";
          id="cs";
          textColor=静态主字体类颜色();
        };
        {
          TextView;
          text="00";
          id="ds";
          textColor=静态主字体类颜色();
        };
      };
    };
  };
  AlertDialog.Builder(this)
  .setTitle(bt)
  .setView(loadlayout(InputLayout))
  .setPositiveButton("选择",{onClick=kop})
  .setNegativeButton("取消",nil)
  .show()

  bjk.setText(ys)
  bj.setBackgroundColor(int(ys))

  ac.setMax(255)
  bc.setMax(255)
  cc.setMax(255)
  dc.setMax(255)
  ac.setOnSeekBarChangeListener{
    onProgressChanged=function(seekbar,int2,boolean)
      aa.setText(int2.."")
      apps=string.format("%x",aa.Text)
      if tonumber(int2)<=tonumber(15) then
        as.setText("0"..apps)
       else
        as.setText(apps)
      end
      sjixsp="0xFFFFFF"..as.Text
      ac.ProgressDrawable.setColorFilter(PorterDuffColorFilter(0xfa383638,PorterDuff.Mode.SRC_ATOP))
      ac.Thumb.setColorFilter(PorterDuffColorFilter(0xfa383638,PorterDuff.Mode.SRC_ATOP))
      sjix="0x"..as.Text..bs.Text..cs.Text..ds.Text
      bj.setBackgroundColor(int(sjix))
      bjk.setText(sjix)
    end
    ,
  }

  bc.setOnSeekBarChangeListener{
    onProgressChanged=function(seekbar,int2,boolean)
      ba.setText(int2.."")
      apps=string.format("%x",ba.Text)
      if tonumber(int2)<=tonumber(15) then
        bs.setText("0"..apps)
       else
        bs.setText(apps)
      end
      sjixsp="0xFF"..bs.Text.."FFFF"
      bc.ProgressDrawable.setColorFilter(PorterDuffColorFilter(0xffff4700,PorterDuff.Mode.SRC_ATOP))
      bc.Thumb.setColorFilter(PorterDuffColorFilter(0xffff4700,PorterDuff.Mode.SRC_ATOP))
      sjix="0x"..as.Text..bs.Text..cs.Text..ds.Text
      bj.setBackgroundColor(int(sjix))
      bjk.setText(sjix)
    end
    ,
  }

  cc.setOnSeekBarChangeListener{
    onProgressChanged=function(seekbar,int2,boolean)
      ca.setText(int2.."")
      apps=string.format("%x",ca.Text)
      if tonumber(int2)<=tonumber(15) then
        cs.setText("0"..apps)
       else
        cs.setText(apps)
      end
      sjixsp="0xFFFF"..cs.Text.."FF"
      cc.ProgressDrawable.setColorFilter(PorterDuffColorFilter(0xfa5dda44,PorterDuff.Mode.SRC_ATOP))
      cc.Thumb.setColorFilter(PorterDuffColorFilter(0xfa5dda44,PorterDuff.Mode.SRC_ATOP))
      sjix="0x"..as.Text..bs.Text..cs.Text..ds.Text
      bj.setBackgroundColor(int(sjix))
      bjk.setText(sjix)
    end
    ,
  }

  dc.setOnSeekBarChangeListener{
    onProgressChanged=function(seekbar,int2,boolean)
      da.setText(int2.."")
      apps=string.format("%x",da.Text)
      if tonumber(int2)<=tonumber(15) then
        ds.setText("0"..apps)
       else
        ds.setText(apps)
      end
      --sjixsp="0xFFFFFF"..ds.Text
      dc.ProgressDrawable.setColorFilter(PorterDuffColorFilter(0xfa10b5ff,PorterDuff.Mode.SRC_ATOP))
      dc.Thumb.setColorFilter(PorterDuffColorFilter(0xfa10b5ff,PorterDuff.Mode.SRC_ATOP))
      sjix="0x"..as.Text..bs.Text..cs.Text..ds.Text
      bj.setBackgroundColor(int(sjix))
      bjk.setText(sjix)
    end
    ,
  }

  ak=string.sub(ys,3,4)
  ac.setProgress(tonumber(ak, 16))

  a2=string.sub(ys,5,6)
  bc.setProgress(tonumber(a2, 16))

  a3=string.sub(ys,7,8)
  cc.setProgress(tonumber(a3, 16))

  a4=string.sub(ys,9,10)
  dc.setProgress(tonumber(a4, 16))

  bjk.onClick=function()
    InputLayout={
      LinearLayout;
      orientation="vertical";
      Focusable=true,
      FocusableInTouchMode=true,
      {
        EditText;
        hint="请输入16进制颜色";
        layout_marginTop="5dp";
        layout_width="80%w";
        layout_gravity="center",
        id="edit";
      };
    };

    AlertDialog.Builder(this)
    .setTitle("自定义颜色")
    .setView(loadlayout(InputLayout))
    .setPositiveButton("确定",{onClick=function()

        ys=edit.Text
        ak=string.sub(ys,3,4)
        ac.setProgress(tonumber(ak, 16))

        a2=string.sub(ys,5,6)
        bc.setProgress(tonumber(a2, 16))

        a3=string.sub(ys,7,8)
        cc.setProgress(tonumber(a3, 16))

        a4=string.sub(ys,9,10)
        dc.setProgress(tonumber(a4, 16))

      end})
    .setNegativeButton("取消",nil)
    .show()
    edit.setText(bjk.Text)
  end
end

--窗口
function datas.windows(题目,内容,左按钮,右按钮,左按钮事件,右按钮事件)
  if Build.VERSION.SDK_INT <= 19 then
    lay={
      LinearLayout,
      orientation="vertical",
      {
        CardView;--卡片控件
        layout_marginBottom='0dp';--卡片边距
        layout_gravity='center';--重力属性
        elevation='0dp';--阴影属性
        layout_width='76%w';--卡片宽度
        CardBackgroundColor=主页类颜色();--卡片背景颜色
        layout_height='70%h';--卡片高度
        radius='12dp';--卡片圆角
        {
          LinearLayout;
          orientation='vertical';--重力属性
          layout_width='76%w';--布局宽度
          layout_height='120dp';--布局高度
          background='drawable/top.png';--布局背景颜色(或者图片路径)
          {
            TextView;--文本控件
            layout_width='76%w';--文本宽度
            layout_height='60dp';--文本高度
            gravity='center';--重力属性
            textColor='#FFFFFF';--文字颜色
            text=题目;--显示的文字
            textSize='24sp';--文字大小
            layout_marginTop="20dp";
          };
        };
        {
          LinearLayout;
          orientation='vertical';--重力属性
          layout_width='76%w';--布局宽度
          layout_height='50%h';--布局高度
          background=主页类颜色();--布局背景颜色(或者图片路径)
          layout_marginTop="130dp";

          {
            ScrollView,--纵向滚动
            layout_width='68%w';--宽
            layout_height='180dp';--高
            layout_marginTop="12dp";
            layout_marginLeft="4%w";
            {
              TextView;
              --Button;--纽扣控件
              text=内容;--要显示的文本
              textSize='13sp';--文字大小
              textColor=弹窗主文本颜色();--文字颜色
              backgroundColor=主页类颜色();--纽扣背景颜色
              layout_width='68%w';--纽扣宽度
              layout_height='195dp';--纽扣高度
              gravity="center|left";
              style="?android:attr/buttonBarButtonStyle";
            };
          }; --滚动结束
          {
            CardView;--卡片控件
            layout_marginTop='50dp';--卡片边距
            layout_marginLeft="19dp";
            layout_gravity='left';--重力属性
            elevation='0dp';--阴影属性
            layout_width='30%w';--卡片宽度
            CardBackgroundColor='#77AF9C';--卡片背景颜色
            layout_height='40dp';--卡片高度
            radius='20dp';--卡片圆角
            --layout_marginLeft="6%w";
            {
              Button;--纽扣控件
              text=左按钮;--要显示的文本
              textSize='12sp';--文字大小
              textColor='#FFFFFFFF';--文字颜色
              backgroundColor='#FFFFFFFF';--纽扣背景颜色
              layout_width='29.2%w';--纽扣宽度
              layout_height='38dp';--纽扣高度
              gravity="center";
              id="支持";
              onClick=左按钮事件;
            };
          };
          {
            CardView;--卡片控件
            layout_marginTop='-52dp';--卡片边距
            layout_gravity='right';--重力属性
            layout_marginRight="19dp";
            elevation='1dp';--阴影属性
            layout_width='30%w';--卡片宽度
            CardBackgroundColor='#77AF9C';--卡片背景颜色
            layout_height='40dp';--卡片高度
            radius='20dp';--卡片圆角
            --layout_marginLeft="6%w";
            {
              TextView;--文本控件
              layout_width='30%w';--文本宽度
              layout_height='40dp';--文本高度
              gravity='center';--重力属性
              textColor='#FFFFFFFF';--文字颜色
              text=右按钮;--显示的文字
              textSize='12sp';--文字大小
              id="好的";
              onClick=右按钮事件;
            };
          };
        }; --卡片线性布局结束
      };--卡片布局结束
      {
        ImageView;--图片控件
        src='drawable/rocket.png';--图片路径
        layout_width='50dp';--图片宽度
        layout_height='50dp';--图片高度
        layout_gravity="right";
        layout_marginTop="0dp";
        layout_marginRight="23dp";
        scaleType='fitXY';
        layout_marginTop="-70.5%h";
      };
    }; --总布局结束

    dialog= AlertDialog.Builder(this)
    update=dialog.show()
    update.getWindow().setContentView(loadlayout(lay));
    update.getWindow().setBackgroundDrawable(ColorDrawable(0x00000000));
    function datas.隐藏()
      update.dismiss()
    end
    --调用渐变函数
    渐变(0xFF7479FF,0xFF97C6FE,好的)
    --用法
    波纹(支持,0xFFF48FB1)
    波纹(好的,0xFFF48FB1)

   elseif Build.VERSION.SDK_INT > 19 then
    lay={
      LinearLayout,
      orientation="vertical",
      {
        CardView;--卡片控件
        layout_marginBottom='0dp';--卡片边距
        layout_gravity='center';--重力属性
        elevation='0dp';--阴影属性
        layout_width='76%w';--卡片宽度
        CardBackgroundColor='#FFFFFFFF';--卡片背景颜色
        layout_height='70%h';--卡片高度
        radius='12dp';--卡片圆角
        {
          LinearLayout;
          orientation='vertical';--重力属性
          layout_width='76%w';--布局宽度
          layout_height='120dp';--布局高度
          background='drawable/top.png';--布局背景颜色(或者图片路径)
          {
            TextView;--文本控件
            layout_width='76%w';--文本宽度
            layout_height='60dp';--文本高度
            gravity='center';--重力属性
            textColor='#FFFFFF';--文字颜色
            text=题目;--显示的文字
            textSize='24sp';--文字大小
            layout_marginTop="20dp";
          };
        };
        {
          LinearLayout;
          orientation='vertical';--重力属性
          layout_width='76%w';--布局宽度
          layout_height='50%h';--布局高度
          background='#FFFFFFFF';--布局背景颜色(或者图片路径)
          layout_marginTop="130dp";

          {
            ScrollView,--纵向滚动
            layout_width='68%w';--宽
            layout_height='180dp';--高
            layout_marginTop="12dp";
            layout_marginLeft="4%w";
            {
              TextView;
              --Button;--纽扣控件
              text=内容;--要显示的文本
              textSize='13sp';--文字大小
              textColor='#F3525252';--文字颜色
              backgroundColor='#FFFFFFFF';--纽扣背景颜色
              layout_width='68%w';--纽扣宽度
              layout_height='195dp';--纽扣高度
              gravity="center|left";
              style="?android:attr/buttonBarButtonStyle";
            };
          }; --滚动结束
          {
            CardView;--卡片控件
            layout_marginTop='50dp';--卡片边距
            layout_marginLeft="19dp";
            layout_gravity='left';--重力属性
            elevation='0dp';--阴影属性
            layout_width='30%w';--卡片宽度
            CardBackgroundColor='#77AF9C';--卡片背景颜色
            layout_height='40dp';--卡片高度
            radius='20dp';--卡片圆角
            --layout_marginLeft="6%w";
            {
              CardView;--卡片控件
              layout_marginTop='0dp';--卡片边距
              --layout_marginLeft="19dp";
              layout_gravity='center';--重力属性
              elevation='0dp';--阴影属性
              layout_width='29.2%w';--卡片宽度
              CardBackgroundColor='#FFFFFFFF';--卡片背景颜色
              layout_height='38dp';--卡片高度
              radius='18dp';--卡片圆角
              {
                Button;--纽扣控件
                text=左按钮;--要显示的文本
                textSize='12sp';--文字大小
                textColor='#FF7479FF';--文字颜色
                backgroundColor='#FFFFFFFF';--纽扣背景颜色
                layout_width='29.2%w';--纽扣宽度
                layout_height='38dp';--纽扣高度
                gravity="center";
                id="支持";
                onClick=左按钮事件;
              };
            };
          };
          {
            CardView;--卡片控件
            layout_marginTop='-40dp';--卡片边距
            layout_gravity='right';--重力属性
            layout_marginRight="19dp";
            elevation='1dp';--阴影属性
            layout_width='30%w';--卡片宽度
            CardBackgroundColor='#77AF9C';--卡片背景颜色
            layout_height='40dp';--卡片高度
            radius='20dp';--卡片圆角
            --layout_marginLeft="6%w";
            {
              TextView;--文本控件
              layout_width='30%w';--文本宽度
              layout_height='40dp';--文本高度
              gravity='center';--重力属性
              textColor='#FFFFFFFF';--文字颜色
              text=右按钮;--显示的文字
              textSize='12sp';--文字大小
              id="好的";
              onClick=右按钮事件;
            };
          };
        }; --卡片线性布局结束
      };--卡片布局结束
      {
        ImageView;--图片控件
        src='drawable/rocket.png';--图片路径
        layout_width='50dp';--图片宽度
        layout_height='50dp';--图片高度
        layout_gravity="right";
        layout_marginTop="0dp";
        layout_marginRight="23dp";
        scaleType='fitXY';
        layout_marginTop="-70.5%h";
      };
    }; --总布局结束

    dialog= AlertDialog.Builder(this)
    update=dialog.show()
    update.getWindow().setContentView(loadlayout(lay));
    update.getWindow().setBackgroundDrawable(ColorDrawable(0x00000000));
    function datas.隐藏()
      update.dismiss()
    end
    --调用渐变函数
    渐变(0xFF7479FF,0xFF97C6FE,好的)
    --用法
    波纹(支持,0xFFF48FB1)
    波纹(好的,0xFFF48FB1)
  end
end
W=activity.width
H=activity.height
function datas.arcMove(v,startX,startY,endX,endY,time)
  local arcPath=ArcMotion().getPath
  (startX,startY,endX,endY)
  ObjectAnimator
  .ofFloat(v,"x","y",arcPath)
  .setDuration(time).start()
end
--hw
function datas.hw(h)
  linearParams = card.getLayoutParams()
  linearParams.height =h
  linearParams.width =h
  card.setLayoutParams(linearParams)
end
--PretendInputView
function datas.PretendInputView(t)
  local lay=loadlayout{FrameLayout,
    {TextView,
      text=t.text or "Hint",
      SingleLine=true,
      textSize=t.textSize,
      layout_height=-1,
      gravity=80,
      paddingBottom="10dp",
      paddingLeft="5dp",
      textColor=0xff797979},
    {
      EditText,
      id=t.id,
      textSize=t.textSize,
      gravity=80,
      layout_width=-1,
      layout_height=-1,
      SingleLine=true}}
  lay.getChildAt(1).setOnFocusChangeListener{onFocusChange=function(v,Focus)
      if t.字体颜色==nil then
       else
        idkm=lay.getChildAt(1)
        idkm.setTextColor(t.字体颜色)
      end
      if t.编辑框颜色==nil then
       else
        idkm=lay.getChildAt(1)
        idkm.getBackground().setColorFilter(PorterDuffColorFilter(t.编辑框颜色,PorterDuff.Mode.SRC_ATOP));
      end
      if Focus then
        local id,h=lay.getChildAt(0),v.height//2
        id.TextColor=t.提示信息颜色
       else
        local id,h=lay.getChildAt(0),v.height//2
        id.TextColor=t.提示信息颜色2
      end
      if v.Text=="" then
        local id,h=lay.getChildAt(0),v.height//2
        if Focus then
          if t.textSize==nil or t.textSize2==nil then
            ObjectAnimator()
            .ofFloat(id,"textSize",{18,12}).setDuration(200).start()
            .ofFloat(id,"Y",{0,-h}).setDuration(200).start()
           else
            ObjectAnimator()
            .ofFloat(id,"textSize",{t.textSize,t.textSize2}).setDuration(200).start()
            .ofFloat(id,"Y",{0,-h}).setDuration(200).start()
          end
          if t.提示信息颜色==nil then
           else
            id.TextColor=t.提示信息颜色
            idkm=lay.getChildAt(1)
          end
         else
          if t.textSize==nil or t.textSize2==nil then
            ObjectAnimator()
            .ofFloat(id,"textSize",{12,18}).setDuration(200).start()
            .ofFloat(id,"Y",{-h,0}).setDuration(200).start()
           else
            ObjectAnimator()
            .ofFloat(id,"textSize",{t.textSize2,t.textSize}).setDuration(200).start()
            .ofFloat(id,"Y",{-h,0}).setDuration(200).start()
          end
          if t.提示信息颜色2==nil then
           else
            id.TextColor=t.提示信息颜色2
          end
        end
      end
    end}
  return function() return lay end
end
--PretendEditText
function datas.PretendEditText(t)
  local lay=loadlayout{
    FrameLayout,
    {
      RelativeLayout;
      layout_width="fill";
      focusableInTouchMode=true;
      focusable=true;
      layout_height="fill";
      {
        EditText;
        layout_height="wrap";
        layout_marginTop="56";
        layout_centerHorizontal="true";
        textColor=t.字体颜色 or "#000000";
        textSize="14dp";
        background="0";
        layout_marginLeft="10dp";
        layout_width="fill";
        layout_marginRight="10dp";
        id=t.id;
        password=t.password;
        singleLine="true";
      };
      {
        TextView;
        layout_height="2dp";
        layout_alignBottom=t.id;
        layout_centerHorizontal="true";
        layout_marginLeft="10dp";
        layout_width="fill";
        layout_marginRight="10dp";
        alpha="1";
        id=t.id2;
      };
      {
        TextView;
        layout_height="1dp";
        layout_alignBottom=t.id;
        layout_centerHorizontal="true";
        layout_marginLeft="10dp";
        layout_width="fill";
        layout_marginRight="10dp";
        alpha="0.2";
        id=t.id4;
      };
      {
        TextView;
        id=t.id3;
        layout_marginLeft="10dp";
        text=t.hint or "Pretend封装";
        layout_marginTop="-18dp";
        layout_alignTop=t.id;
        textColor="#ff8b8b8b";
        textSize="14dp";
      };
    };
  }
  值=true
  lay.getChildAt(0).getChildAt(1).setBackgroundColor(t.线的颜色1 or 0xff009688)
  lay.getChildAt(0).getChildAt(2).setBackgroundColor(t.线的颜色2 or 0xff000000)
  lay.getChildAt(0).getChildAt(0).setOnFocusChangeListener{
    onFocusChange=function( v, hasFocus)
      if hasFocus then
        lay.getChildAt(0).getChildAt(1).startAnimation(ScaleAnimation(0.0,1.0,1.0,1.0,1,0.5,1,0.5).setDuration(200))
        lay.getChildAt(0).getChildAt(1).setVisibility(View.VISIBLE)
        lay.getChildAt(0).getChildAt(3).setTextColor(t.hint颜色2 or 0xff009688)
       else
        lay.getChildAt(0).getChildAt(1).startAnimation(ScaleAnimation(1.0,0.0,1.0,1.0,1,0.5,1,0.5).setDuration(200))
        lay.getChildAt(0).getChildAt(1).setVisibility(View.INVISIBLE)
        lay.getChildAt(0).getChildAt(3).setTextColor(t.hint颜色1 or 0xff8b8b8b)
      end
    end}
  lay.getChildAt(0).getChildAt(1).setVisibility(View.INVISIBLE)
  function datas.取消焦点(app)
    app.setFocusable(false);
    app.setFocusableInTouchMode(true);
  end
  return function() return lay end
end
-----------------------------------------------------------------
function datas.px2dp(pxValue)
  local scale = this.getResources().getDisplayMetrics().density
  return (pxValue / scale)
end

function datas.dp2px(dpValue)
  local scale = this.getResources().getDisplayMetrics().density
  return (dpValue * scale)
end

function datas.sp2px(spValue)
  local fontScale = this.getResources().getDisplayMetrics().scaledDensity
  return (spValue * fontScale + 0.5)
end

function datas.大小转换(a)
  if a>=1024 then
    local b=tonumber(string.format("%.2f",a/1024))
    if b>=1024 then
      return string.format("%.2fMB",b/1024)
     else
      return b.."KB"
    end
   else
    return a.."B"
  end
end

function datas.转0x(j)
  if #j==7 then
    jj=j:match("#(.+)")
    jjj=tonumber("0xff"..jj)
   else
    jj=j:match("#(.+)")
    jjj=tonumber("0x"..jj)
  end
  return jjj
end

return datas