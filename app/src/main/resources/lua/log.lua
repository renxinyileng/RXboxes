require 'init'
_G=_G
if this!=activity or !debugmode
  _G.safe_error=print
  _G.explain=print
  _G.info=print
  _G.warning=print
 else
  xpcall(function()
    activity.setTheme(R.AndLua1)
  end,function()
    activity.setTheme(android.R.style.Theme_Material_Light_DarkActionBar)
  end)
  _G.View=luajava.bindClass "android.view.View"
  local LinearLayout=luajava.bindClass "android.widget.LinearLayout"
  local Spannable=luajava.bindClass "android.text.Spannable"
  local Toast=luajava.bindClass "android.widget.Toast"
  local EditText=luajava.bindClass "android.widget.EditText"
  local InputMethodManager=luajava.bindClass "android.view.inputmethod.InputMethodManager"
  local Color=luajava.bindClass "android.graphics.Color"
  local WindowManager=luajava.bindClass "android.view.WindowManager"
  local TextView=luajava.bindClass "android.widget.TextView"
  local LuaAdapter=luajava.bindClass "com.androlua.LuaAdapter"
  local Gravity=luajava.bindClass "android.view.Gravity"
  local FrameLayout=luajava.bindClass "android.widget.FrameLayout"
  local Build=luajava.bindClass "android.os.Build"
  local Ticker=luajava.bindClass "com.androlua.Ticker"
  local System=luajava.bindClass "java.lang.System"
  local Context=luajava.bindClass "android.content.Context"
  local HapticFeedbackConstants=luajava.bindClass "android.view.HapticFeedbackConstants"
  local ListView=luajava.bindClass "android.widget.ListView"
  local ColorStateList=luajava.bindClass "android.content.res.ColorStateList"
  local ForegroundColorSpan=luajava.bindClass "android.text.style.ForegroundColorSpan"
  local PageView=luajava.bindClass "android.widget.PageView"
  local Window=luajava.bindClass "android.view.Window"
  local SimpleDateFormat=luajava.bindClass "java.text.SimpleDateFormat"
  local Configuration=luajava.bindClass "android.content.res.Configuration"
  local Dialog=luajava.bindClass "android.app.Dialog"
  local ScrollView=luajava.bindClass "android.widget.ScrollView"
  local SpannableStringBuilder=luajava.bindClass "android.text.SpannableStringBuilder"
  local typedValue = luajava.newInstance('android.util.TypedValue')
  luajava.getContext().getTheme().resolveAttribute(android.R.attr.colorAccent, typedValue, true);
  local dark=luajava.getContext().getResources().getConfiguration().uiMode& Configuration.UI_MODE_NIGHT_YES!=0
  local tcolor=typedValue.data
  local bcolor=0xfff1f3f6
  if dark
    local hsv=float[3]
    Color.colorToHSV(tcolor,hsv)
    hsv[1]=0.7
    hsv[2]=1
    tcolor=Color.HSVToColor(hsv)
    bcolor=0xfF2B303B
  end
  local ids={}
  local wm=activity.getSystemService(Context.WINDOW_SERVICE)
  local wp=WindowManager.LayoutParams()
  wp.width=-2
  wp.height=-2
  wp.gravity=Gravity.RIGHT | Gravity.CENTER
  wp.flags=WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE

  ids.btn={}
  local btn=loadlayout({
    LinearLayout;
    padding="2dp";
    paddingRight="0";
    backgroundColor=tcolor;
    id='root';
    {
      TextView;
      id='title';
      layout_height='50px';
      layout_width='100px';
      text="调试";
      textSize="11dp";
      textColor=tcolor;
      backgroundColor=bcolor;
      gravity='center';
    }
  },ids.btn)

  ids.btn.title.getPaint().setFakeBoldText(true)

  wm.addView(btn,wp)

  local function readlog(s)
    local p=io.popen("logcat -d -v long "..s)
    local s=p:read("*a")
    p:close()
    s=s:gsub("%-+ beginning of[^\n]*\n","")
    if #s==0 then
      s="<run the app to see its log output>"
    end
    return s
  end

  local function clearlog()
    local p=io.popen("logcat -c")
    local s=p:read("*a")
    p:close()
    return s
  end

  task(clearlog)

  local ti=Ticker()
  ti.Period=1000
  ti.onTick=function()
    local s=readlog('lua:* *:S')
    if s:find('Runtime%s-error')
      safe_error((s:gsub('^%[.+%]\n','')))
      ids.btn.title.setText('异常')
      ids.btn.root.setBackgroundColor(0xFFe90000)
      ids.btn.title.setTextColor(0xFFe90000)
      ti.stop()
    end
    if this.isFinishing() or this.isDestroyed()
      ti.stop()
    end
  end
  ti.start()



  local function 振动(v)
    v.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS,HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING)
  end


  ids.dia={}
  local dia=Dialog(this)
  dia.requestWindowFeature(Window.FEATURE_NO_TITLE)
  dia.setContentView(loadlayout({
    LinearLayout;
    orientation="vertical";
    layout_width="fill";
    layout_height="fill";
    backgroundColor="#e8e8ea";
    {
      LinearLayout;
      layout_height="35dp";
      layout_width="match_parent";
      {
        TextView;
        textSize="12dp";
        layout_weight="1";
        layout_height="match_parent";
        backgroundColor="#ffffff";
        text=" Prints ";
        gravity="center";
        textColor="#000000";
        id="prints";
      };
      {
        View;
        layout_width="2";
        backgroundColor="#dddddd";
      };
      {
        TextView;
        textSize="12dp";
        layout_height="match_parent";
        layout_weight="1";
        text="Variable";
        gravity="center";
        textColor="#000000";
        id="variable";
      };
      {
        View;
        layout_width="2";
        backgroundColor="#dddddd";
      };
      {
        TextView;
        textSize="12dp";
        layout_height="match_parent";
        layout_weight="1";
        text=" Logcat ";
        gravity="center";
        textColor="#000000";
        id="logcat";
      };
      {
        View;
        layout_width="2";
        backgroundColor="#dddddd";
      };
      {
        TextView;
        textSize="12dp";
        layout_height="match_parent";
        layout_weight="1";
        text="  Text  ";
        gravity="center";
        textColor="#000000";
        id="text";
      };
      {
        View;
        layout_width="2";
        backgroundColor="#dddddd";
      };
      {
        TextView;
        textSize="12dp";
        layout_height="match_parent";
        layout_weight="1";
        text="Control";
        gravity="center";
        textColor="#000000";
        id="control";
      };
    };
    {
      View;
      layout_height="2";
      backgroundColor="#dddddd";
    };
    {
      PageView;
      backgroundColor="#ffffff";
      layout_weight="1";
      id="page";
      overScrollMode="2";
      pages={
        {
          FrameLayout;
          layout_width="fill";
          layout_height="fill";
          {
            LinearLayout;
            layout_width="fill";
            id="print_empty";
            orientation="vertical";
            {
              TextView;
              textSize="12dp";
              paddingLeft="6dp";
              padding="5dp";
              layout_width="fill";
              text="<run the app to see its log output>";
              paddingRight="6dp";
              textColor="#808080";
            };
            {
              View;
              backgroundColor="#dddddd";
              layout_height="2";
            };
          };
          {
            ListView;
            overScrollMode="2";
            fastScrollEnabled=true;
            layout_width="match_parent";
            id="print_list";
            dividerHeight="2";
            layout_height="match_parent";
          };
        };
        {
          LinearLayout;
          orientation="vertical";
          layout_width="fill";
          layout_height="fill";
          {
            LinearLayout;
            orientation="vertical";
            layout_width="fill";
            {
              LinearLayout;
              focusable=true;
              layout_width="fill";
              focusableInTouchMode=true;
              {
                TextView;
                padding="5dp";
                paddingRight="0";
                textColor="#00a000";
                textSize="12dp";
                text="当前节点: /";
                id="variable_path";
                paddingLeft="6dp";
                id="variable_path";
              };
              {
                EditText;
                padding="5dp";
                paddingLeft="0";
                textColor="#00a000";
                textSize="12dp";
                backgroundColor="0";
                singleLine="true";
                paddingRight="6dp";
                id="variable_search";
                layout_width="fill";
                imeOptions="actionSearch";
              };
            };
            {
              View;
              backgroundColor="#dddddd";
              layout_height="2";
            };
          };
          {
            ListView;
            fastScrollEnabled=true;
            dividerHeight="2";
            overScrollMode="2";
            id="variable_list";
            layout_width="match_parent";
            layout_height="match_parent";
          };
        };
        {
          LinearLayout;
          layout_height="fill";
          orientation="vertical";
          layout_width="fill";
          {
            LinearLayout;
            layout_height="20dp";
            id="logcat_bar";
            gravity="center";
            layout_width="match_parent";
            {
              TextView;
              textSize="11dp";
              text="A";
              gravity="center";
              layout_weight="1";
            };
            {
              View;
              layout_width="2";
              backgroundColor="#cccccc";
            };
            {
              TextView;
              textSize="11dp";
              text="L";
              gravity="center";
              layout_weight="1";
            };
            {
              View;
              layout_width="2";
              backgroundColor="#cccccc";
            };
            {
              TextView;
              textSize="11dp";
              text="T";
              gravity="center";
              layout_weight="1";
            };
            {
              View;
              layout_width="2";
              backgroundColor="#cccccc";
            };
            {
              TextView;
              textSize="11dp";
              text="E";
              gravity="center";
              layout_weight="1";
            };
            {
              View;
              layout_width="2";
              backgroundColor="#cccccc";
            };
            {
              TextView;
              textSize="11dp";
              text="W";
              gravity="center";
              layout_weight="1";
            };
            {
              View;
              layout_width="2";
              backgroundColor="#cccccc";
            };
            {
              TextView;
              textSize="11dp";
              text="I";
              gravity="center";
              layout_weight="1";
            };
            {
              View;
              layout_width="2";
              backgroundColor="#cccccc";
            };
            {
              TextView;
              textSize="11dp";
              text="D";
              gravity="center";
              layout_weight="1";
            };
            {
              View;
              layout_width="2";
              backgroundColor="#cccccc";
            };
            {
              TextView;
              textSize="11dp";
              text="V";
              gravity="center";
              layout_weight="1";
            };
          };
          {
            View;
            layout_height="2";
            backgroundColor="#cccccc";
          };
          {
            ListView;
            overScrollMode="2";
            fastScrollEnabled=true;
            layout_width="match_parent";
            id="logcat_list";
            dividerHeight="2";
            layout_height="match_parent";
          };
        };

        {
          LinearLayout;
          layout_height="fill";
          layout_width="fill";
          focusable=true,
          focusableInTouchMode=true,
          {
            ScrollView;
            layout_width="fill";
            overScrollMode="2";
            {
              EditText;
              id="text_edit";
              textIsSelectable=true;
              hint="Please enter text...";
              textColor="#000000";
              layout_height="match_parent";
              layout_width="match_parent";
              textSize="12dp";
              backgroundColor="0";
              padding="8dp";
              gravity="start";
            };
          };
        };

        {
          LinearLayout;
          orientation="vertical";
          layout_width="fill";
          layout_height="fill";
          {
            LinearLayout;
            orientation="vertical";
            padding="10dp";
            layout_width="fill";
            {
              LinearLayout;
              layout_width="fill";
              {
                TextView;
                gravity="center";
                id="control_btn1";
                layout_height="30dp";
                layout_marginRight="5dp";
                backgroundColor="#e8e8ea";
                textColor="#000000";
                textSize="11dp";
                layout_weight="1";
                text="关闭当前界面";
                elevation="2";
              };
              {
                TextView;
                gravity="center";
                id="control_btn2";
                layout_height="30dp";
                elevation="2";
                textSize="11dp";
                textColor="#000000";
                backgroundColor="#e8e8ea";
                layout_weight="1";
                text="重构当前界面";
                layout_marginLeft="5dp";
              };
            };
            {
              LinearLayout;
              layout_width="fill";
              layout_marginTop="10dp";
              {
                TextView;
                gravity="center";
                id="control_btn3";
                elevation="2";
                layout_marginRight="5dp";
                backgroundColor="#e8e8ea";
                textColor="#000000";
                textSize="11dp";
                layout_weight="1";
                text="重启当前界面";
                layout_height="30dp";
              };
              {
                TextView;
                gravity="center";
                id="control_btn4";
                layout_height="30dp";
                elevation="2";
                textSize="11dp";
                textColor="#000000";
                backgroundColor="#e8e8ea";
                layout_weight="1";
                text="结束当前进程";
                layout_marginLeft="5dp";
              };
            };
          };
          {
            LinearLayout;
            gravity="center|bottom";
            orientation="vertical";
            layout_width="match_parent";
            layout_height="match_parent";
            {
              View;
              backgroundColor="#dddddd";
              layout_height="2";
            };
            {
              LinearLayout;
              layout_width="match_parent";
              minimumHeight="35dp";
              focusable=true,
              focusableInTouchMode=true,
              {
                EditText;
                backgroundColor="0";
                padding="10dp";
                textColor="#000000";
                layout_weight="1";
                textSize="11dp";
                hint="Lua code...";
                id="control_code";
              };
              {
                TextView;
                textSize="11dp";
                text="Run";
                gravity="center";
                textColor="#000000";
                backgroundColor="#e8e8ea";
                id="control_run";
                layout_width="50dp";
                layout_height="match_parent";
              };
            };
          };
        };

      };
    };
    {
      View;
      layout_height="2";
      backgroundColor="#cccccc";
    };
    {
      LinearLayout;
      id='bar';
      layout_height="35dp";
      layout_width="match_parent";
    };
  },ids.dia))

  local dw=dia.getWindow()
  local ab=dw.getAttributes()
  ab.width=-1
  ab.height=1000
  dw.gravity=Gravity.BOTTOM




  --Prints

  local print_text={}
  local print_data={}
  local print_adp=LuaAdapter(this,print_data,{
    TextView;
    layout_width='fill';
    textSize='12dp';
    padding="5dp";
    paddingLeft='6dp';
    paddingRight='6dp';
    --backgroundColor="#ffffff";
    id='txt';
  })

  ids.dia.print_list.setAdapter(print_adp)

  ids.dia.print_list.onItemClick=function(a,b,c,d)
    振动(b)
    ids.dia.text_edit.setText(print_text[d])
    ids.dia.page.setCurrentItem(3,false)
  end

  local date=SimpleDateFormat("HH:mm:ss.SSS: ")
  function log(color,is,...)
    local str={}
    local arg={...}

    ids.dia.print_empty.setVisibility(8)

    for k,v ipairs(arg)
      str[#str+1]=tostring(v)
      if k!=#arg
        str[#str+1]='   '
      end
    end

    local s=table.concat(str)
    local tag=s
    if utf8.len(s)>80
      s=string.sub(s,1,80)..'...'
    end

    if is
      s=date.format(System.currentTimeMillis())..s
    end

    print_adp.add{
      txt={
        text=s,
        textColor=color,
      }
    }
    print_text[#print_data]=tag
    return ...
  end

  function print(...)
    return log(tcolor,1,...)
  end

  function safe_error(...)
    return log(0xFFe90000,1,...)
  end

  function explain(...)
    return log(0xff808080,1,...)
  end

  function info(...)
    return log(0xFF00a000,1,...)
  end

  function warning(...)
    return log(0xFFE97E00,1,...)
  end

  local _err=error
  function error(a,b)
    _err(log(0xFFe90000,1,a),b)
  end

  local _ass=assert
  function assert(a,...)
    if !a
      log(0xFFe90000,1,...)
    end
    return _ass(a,...)
  end



  --variable

  local variable_path={}
  local flags=Spannable.SPAN_INCLUSIVE_INCLUSIVE
  local variable_kv={}
  local variable_span={}
  local variable_node={}
  local variable_data={}
  local variable_adp=LuaAdapter(this,variable_data,{
    TextView;
    layout_width='fill';
    textSize='12dp';
    padding="5dp";
    paddingLeft='6dp';
    paddingRight='16dp';
    singleLine='true';
    ellipsize="end";
    id='kv';
  })

  ids.dia.variable_list.setAdapter(variable_adp)


  local function add(tab,str)
    variable_data[#variable_data+1]={
      kv={
        text=str,
        textColor=0xff808080
      }
    }
    variable_kv[#variable_data]=tab
  end

  local color_span1=ForegroundColorSpan(0xFF00a000)
  local color_span2=ForegroundColorSpan(tcolor)
  local color_span3=ForegroundColorSpan(0xFF7F00FF)
  local color_span4=ForegroundColorSpan(0xFF00a000)
  local color_span5=ForegroundColorSpan(0xFFE97E00)

  local function tree()
    local tab=_ENV

    table.clear(variable_path)
    table.clear(variable_data)

    for k,v ipairs(variable_node)
      if type(tab[v])=='table'
        tab=tab[v]
       else
        variable_node[k]=nil
      end
    end

    local t={}
    for k,v ipairs(variable_node)
      t[k]=tostring(v)
    end

    local s=table.concat(t,'/')

    if #s>0
      s=s.."/"
    end

    ids.dia.variable_path.setText("当前节点: /"..s)


    table.clear(variable_data)
    if #variable_node!=0
      add(1,'返回父节点')
    end

    add(2,'序列化节点')

    for k,v pairs(tab)
      local _k,_v=k,v
      v=tostring(v)
      if utf8.len(v)>80
        v=utf8.sub(v,1,80)..'...'
      end
      when type(k)!='string' k=string.format('[%s]',tostring(k))
      when type(_v)=='string' v=string.format('"%s"',v)
      when type(_v)=='table' v=string.format('%s => {...}',v)


      local s=string.format('%s => %s',k,tostring(v))


      local span
      if variable_span[#variable_data+1]
        span=variable_span[#variable_data+1]
       else
        span=SpannableStringBuilder()
      end

      span.clearSpans()
      span.clear()
      span.append(s)

      local s1,e1=utf8.find(s,'=>')

      span.setSpan(color_span2, 0, utf8.len(k), flags)
      span.setSpan(color_span1, s1-1, e1, flags)

      if type(_v)=='table'
      if s:find('table')
        local s0,e0=utf8.find(s,'table:%s-0x%x+%s')
        span.setSpan(color_span3, s0-1, e0, flags)
        local s1,e1=utf8.find(s,'=>',e0)
        span.setSpan(color_span4, s1-1, e1, flags)
        local s2,e2=utf8.find(s,'{%.%.%.}',e1)
        span.setSpan(color_span5, s2-1, e2, flags)
        variable_path[tostring(_k)]=_k
      end
      end
      add({_k,_v},span)
    end
    variable_adp.notifyDataSetChanged()
    ids.dia.variable_list.setStackFromBottom(true)
    ids.dia.variable_list.setStackFromBottom(false)
  end



  ids.dia.variable_list.onItemClick=function(a,b,c,d)
    振动(b)
    local t=variable_kv[d]
    if t==1
      variable_node[#variable_node]=nil
      tree()
     elseif t==2
      local tab=_ENV
      for k,v ipairs(variable_node)
        tab=tab[v]
      end
      ids.dia.text_edit.setText(dump(tab))
      ids.dia.page.setCurrentItem(3,false)
     else
      if type(t[2])=="table"
        variable_node[#variable_node+1]=t[1]
        tree()
       else
        ids.dia.text_edit.setText(tostring(t[2]))
        ids.dia.page.setCurrentItem(3,false)
      end
    end
  end

  ids.dia.variable_list.onItemLongClick=function(a,b,c,d)
    振动(b)
    activity.getSystemService(Context.CLIPBOARD_SERVICE).setText(b.Text)
    return true
  end

  ids.dia.variable_search.onEditorAction=function(v,actionId,event)
    if actionId==0
      variable_node[#variable_node+1]=variable_path[v.text]
      v.setText('')
      activity.getSystemService(Context.INPUT_METHOD_SERVICE).toggleSoftInput(0,InputMethodManager.HIDE_NOT_ALWAYS)
      tree()
    end
    return false
  end


  --logcat
  local logcat_pos,show=1

  local items={"All","Lua","Tcc","Error","Warning","Info","Debug","Verbose"}
  local types={'',"lua:* *:S","tcc:* *:S","*:E","*:W","*:I","*:D","*:V"}

  local logcat_text={}
  local logcat_data={}
  local logcat_adp=LuaAdapter(this,logcat_data,{
    TextView;
    layout_width='fill';
    textSize='12dp';
    padding="5dp";
    paddingLeft='6dp';
    paddingRight='6dp';
    textColor=tcolor;
    id='txt';
  })

  ids.dia.logcat_list.setAdapter(logcat_adp)


  ids.dia.logcat_list.onItemClick=function(a,b,c,d)
    振动(b)
    ids.dia.text_edit.setText(logcat_text[d])
    ids.dia.page.setCurrentItem(3,false)
  end

  local function read()
    task(readlog,types[logcat_pos],function(str)
      table.clear(logcat_data)
      local t,n={},0
      str:gsub('[^\n\n]+',function(w)
        if n%2==0
          if !w:find('^%[')
            t[#t]=string.format('%s\n%s',t[#t],w)
           else
            t[#t+1]=w
            n=n+1
          end
         else
          t[#t]=string.format('%s\n%s',t[#t],w)
          n=n+1
        end
      end)
      for k,v ipairs(t)
        logcat_data[k]={
          txt={
            text=v:match('^(%[%s.+%s%])') or v,
          }
        }
        logcat_text[k]=v
      end
      logcat_adp.notifyDataSetChanged()
    end)
  end

  for i=0,7
    local v=ids.dia.logcat_bar.getChildAt(i*2)
    local i=i
    v.onClick=function(v0)
      振动(v0)
      logcat_pos=i+1
      for i=0,14,2
        local _v=ids.dia.logcat_bar.getChildAt(i)
        _v.setTextColor(0xff909090)
        _v.getPaint().setFakeBoldText(false)
      end
      v0.setTextColor(tcolor)
      v0.getPaint().setFakeBoldText(true)
      read()
    end
  end

  local v=ids.dia.logcat_bar.getChildAt(0)
  v.setTextColor(tcolor)
  v.getPaint().setFakeBoldText(true)

  ----
  ids.btn.root.onClick=function(v)
    振动(v)
    dia.show()
  end

  --底栏
  local bar={'prints', 'variable', 'logcat', 'text', 'control' }

  local btn_list={
    {
      'Clear',function(v)
        振动(v)
        print_adp.clear()
        table.clear(print_text)
        ids.dia.print_empty.setVisibility(0)
      end,
      'Hide',function(v)
        振动(v)
        dia.dismiss()
      end
    },
    {
      'Refresh',function(v)
        振动(v)
        tree()
      end,
      'Hide',function(v)
        振动(v)
        dia.dismiss()
      end
    },
    {
      'Clear',function(v)
        振动(v)
        task(clearlog,read)
      end,
      'Hide',function(v)
        振动(v)
        dia.dismiss()
      end
    },
    {
      'Copy',function(v)
        振动(v)
        activity.getSystemService(Context.CLIPBOARD_SERVICE).setText(ids.dia.text_edit.getText())
        Toast.makeText(activity, "复制成功",Toast.LENGTH_SHORT).show()
      end,
      'Paste',function(v)
        振动(v)
        ids.dia.text_edit.setText(activity.getSystemService(Context.CLIPBOARD_SERVICE).getText())
      end,
      'Clear',function(v)
        振动(v)
        ids.dia.text_edit.setText(nil)
      end,
      'Hide',function(v)
        振动(v)
        dia.dismiss()
      end
    },
    {
      'Hide',function(v)
        振动(v)
        dia.dismiss()
      end
    }
  }

  local btn_cache={}

  local attrsArray = {android.R.attr.selectableItemBackgroundBorderless}
  local typedArray =activity.obtainStyledAttributes(attrsArray)
  local ripple=typedArray.getResourceId(0,0)
  local function 波纹(id,color)
    local Pretend=activity.Resources.getDrawable(ripple)
    pcall(function()
      Pretend.setColor(ColorStateList(int[0].class{int{}},int{color or 0xffffffff}))
    end)
    if id
      return id.setBackground(Pretend)
     else
      return Pretend
    end
  end

  local p=-1
  ids.dia.page.addOnPageChangeListener{
    onPageScrolled=function(pos)
      if pos!=p
        p=pos
        if pos==1
          tree()
         elseif pos==2
          read()
        end
        for k,v ipairs(bar)
          if k==pos+1
            ids.dia[v].setBackgroundColor(0xffffffff)
            continue
          end
          ids.dia[v].setBackgroundColor(0)
        end
        ids.dia.bar.removeAllViews()
        ids.dia.bar.post(function()
          local tab=btn_list[pos+1]
          local n=0
          local width=ids.dia.bar.getWidth()/(#tab/2)
          for i=1,#tab,2
            n=n+1
            local lay
            if btn_cache[n]
              lay=btn_cache[n]
             else
              lay=loadlayout({
                TextView;
                gravity="center";
                layout_height="match_parent";
                textSize="12dp";
                text=tab[i];
                textColor="#000000";
              })
              波纹(lay)
              btn_cache[n]=lay
            end
            lay.setWidth(width)
            lay.setText(tab[i])
            lay.onClick=tab[i+1]
            ids.dia.bar.addView(lay)
            if n!=#tab/2
              ids.dia.bar.addView(loadlayout{
                View;
                layout_width="2";
                backgroundColor="#cccccc";
              })
            end
          end
        end)
      end
    end}

  for k,v ipairs(bar)
    ids.dia[v].onClick=function(v)
      振动(v)
      ids.dia.page.setCurrentItem(k-1,false)
    end
  end



  --Control

  ids.dia.control_btn1.onClick=function(v)
    振动(v)
    dia.dismiss()
    activity.finish()
  end

  ids.dia.control_btn2.onClick=function(v)
    振动(v)
    dia.dismiss()
    activity.recreate()
  end

  ids.dia.control_btn3.onClick=function(v)
    振动(v)
    dia.dismiss()
    activity.finish()
    this.startActivity(this.getIntent())
  end

  ids.dia.control_btn4.onClick=function(v)
    振动(v)
    dia.dismiss()
    os.exit()
  end

  ids.dia.control_run.onClick=function(v)
    振动(v)
    local f,e=load(ids.dia.control_code.text)
    if f
      local v,e=pcall(f)
      if v
        ids.dia.control_code.setText('')
       else
        safe_error(e)
        ids.dia.control_code.setError('程序出错')
      end
     else
      safe_error(e)
      ids.dia.control_code.setError('语法错误')
    end
  end
  -----
  local pkg=this.getPackageManager().getPackageInfo(this.getPackageName(),0)
  log(0xFF00a000,nil,
  string.format('System: %s, Android %s (SDK%s), %s %s',
  Build.MODEL,Build.VERSION.RELEASE,Build.VERSION.SDK,pkg.applicationInfo.loadLabel(this.getPackageManager())
  ,pkg.versionName))
  log(0xFF00a000,nil,'File: '..this.getLuaPath())
end
appname=nil
appver=nil
appcode=nil
appsdk=nil
packagename=nil
debugmode=nil
user_permission=nil
skip_compilation=nil
package.loaded.init=nil
