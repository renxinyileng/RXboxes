require "import"
function _long2str(v, w)
     local len = #v
     local n = bit.lshift((len - 1) , 2)
     if (w) then
          local m = v [len]
          if ((m < n - 3) or (m > n)) then
               return false
          end
          n = m
     end
     local s = {}
     for i = 1 , len do
          s [i] = string.packL(v[i])
     end
     if (w) then
          return string.sub(table.concat(s, ''), 0, n)
        else
          return table.concat(s, '')
     end
end
function _str2long(s, w)
     local v = string.unpackL(s .. string.rep("\0", (4 - bit.band((string.len(s) % 4) , 3))))
     if (w) then
          v [#v+1] = string.len(s)
     end
     return v
end
function _int32(n)
     while (n >= 2147483649) do
          n = n - 4294967296
     end
     while (n <= -2147483649) do
          n = n + 4294967296
     end
     return n
end


--print(_long2str(v, w))



--[[
<p>
<br>
</p>
 
<code class="language-bash hljs"><span class="hljs-keyword">function</span> security.xxTEAEncrypt(str, key, toBase64)  
  
  
    toBase64 = toBase64 or <span class="hljs-literal">true</span>  
    <span class="hljs-keyword">if</span> (str == <span class="hljs-string">""</span>) <span class="hljs-keyword">then</span>  
        <span class="hljs-built_in">return</span> <span class="hljs-string">""</span>  
    end  
    <span class="hljs-built_in">local</span> v = _str2long(str, <span class="hljs-literal">true</span>)  
    <span class="hljs-built_in">local</span> k = _str2long(key, <span class="hljs-literal">false</span>)  
  
  
    <span class="hljs-keyword">if</span> (<span class="hljs-comment">#k < 4) then</span>  
        <span class="hljs-keyword">for</span> i = <span class="hljs-comment">#k+1, 4, 1  do</span>  
        k [i] = 0  
        end  
    end  
    <span class="hljs-built_in">local</span> n = <span class="hljs-comment">#v</span>  
    <span class="hljs-built_in">local</span> z = v [n]  
    <span class="hljs-built_in">local</span> y = v [1]  
    <span class="hljs-built_in">local</span> delta = -0x61C88647  
    <span class="hljs-built_in">local</span> q = math.floor(6 + 52 / (n)) --设定加密轮数  
    <span class="hljs-built_in">local</span> <span class="hljs-built_in">sum</span> = 0  
  
  
    <span class="hljs-keyword">while</span> 0 < q <span class="hljs-keyword">do</span>  
        q = q -1  
        <span class="hljs-built_in">sum</span> = _int32(<span class="hljs-built_in">sum</span> + delta)  
        e = bit.band(bit.rshift(<span class="hljs-built_in">sum</span> , 2), 3)  
        <span class="hljs-built_in">local</span> p = 0  
        <span class="hljs-keyword">for</span> p = 0, n-2 <span class="hljs-keyword">do</span>  
        y = v [p + 2]  
            mx = bit.bxor(_int32(bit.bxor(bit.band(bit.rshift(z, 5), 0x07ffffff), bit.lshift(y , 2)) + bit.bxor(bit.band(bit.rshift(y, 3), 0x1fffffff), bit.lshift(z, 4))), _int32(bit.bxor(<span class="hljs-built_in">sum</span>, y) + bit.bxor(k[bit.bxor(bit.band((p), 3), e)+1], z)))  
            z  = _int32(v[p+1] + mx)  
            v [p+1]  = z  
        end  
  
  
        p = <span class="hljs-comment">#v - 1</span>  
        y = v [1]  
        mx = bit.bxor(_int32(bit.bxor(bit.band(bit.rshift(z, 5), 0x07ffffff), bit.lshift(y , 2)) + bit.bxor(bit.band(bit.rshift(y, 3), 0x1fffffff), bit.lshift(z, 4))), _int32(bit.bxor(<span class="hljs-built_in">sum</span>, y) + bit.bxor(k[bit.bxor(bit.band((p), 3), e)+1], z)))  
        z = _int32(v[n] + mx)  
        v [n] = z  
  
  
    end  
    <span class="hljs-keyword">if</span> (toBase64) <span class="hljs-keyword">then</span>  
        <span class="hljs-built_in">local</span> r = security.url_safe_base64_encode(_long2str(v, <span class="hljs-literal">false</span>))  
        <span class="hljs-built_in">return</span> r  
    end  
    <span class="hljs-built_in">return</span> _long2str(v, <span class="hljs-literal">false</span>)  
end  
<span class="hljs-keyword">function</span> security.xxTEADecrypt(str, key, toBase64)  
  
  
    toBase64 = toBase64 or <span class="hljs-literal">true</span>  
  
  
    <span class="hljs-keyword">if</span> (str == <span class="hljs-string">""</span>) <span class="hljs-keyword">then</span>  
        <span class="hljs-built_in">return</span> <span class="hljs-string">""</span>  
    end  
    -- <span style=<span class="hljs-string">"white-space:pre"</span>>  </span>logcat(str)  
    <span class="hljs-keyword">if</span> toBase64 <span class="hljs-keyword">then</span>  
        str = security.url_safe_base64_decode(str)  
    end  
  
  
    <span class="hljs-built_in">local</span> v = _str2long(str, <span class="hljs-literal">false</span>)  
    <span class="hljs-built_in">local</span> k = _str2long(key, <span class="hljs-literal">false</span>)  
    <span class="hljs-keyword">if</span> (<span class="hljs-comment">#k < 4) then</span>  
        <span class="hljs-keyword">for</span> i = <span class="hljs-comment">#k+1, 4, 1  do</span>  
            k [i] = 0  
        end  
    end  
  
  
    <span class="hljs-built_in">local</span> n = <span class="hljs-comment">#v - 1</span>  
    <span class="hljs-built_in">local</span> z = v [n]  
    <span class="hljs-built_in">local</span> y = v [1]  
    <span class="hljs-built_in">local</span> delta = -0x61C88647  
    <span class="hljs-built_in">local</span> q = math.floor(6 + 52 / (n+1)) --设定加密轮数  
    <span class="hljs-built_in">local</span> <span class="hljs-built_in">sum</span> = _int32(q * delta)  
    <span class="hljs-keyword">while</span> (<span class="hljs-built_in">sum</span> ~= 0) <span class="hljs-keyword">do</span>  
        e = bit.band(bit.rshift(<span class="hljs-built_in">sum</span> , 2), 3)  
--         <span style=<span class="hljs-string">"white-space:pre"</span>>       </span>test_result = test_result ..<span class="hljs-string">"e: "</span>..e..<span class="hljs-string">"\n"</span>  
--         <span style=<span class="hljs-string">"white-space:pre"</span>>       </span>logcat (<span class="hljs-string">"e: "</span>..e)  
        <span class="hljs-built_in">local</span> p = n   
        <span class="hljs-keyword">for</span> p = n, 1, -1 <span class="hljs-keyword">do</span>  
<span style=<span class="hljs-string">"white-space:pre"</span>>           </span>  
            z = v [p]  
--             <span style=<span class="hljs-string">"white-space:pre"</span>>         </span>test_result = test_result ..<span class="hljs-string">"z: "</span>..z..<span class="hljs-string">"p-1: "</span>..(p-1)..<span class="hljs-string">"\n"</span>  
--             <span style=<span class="hljs-string">"white-space:pre"</span>>         </span>logcat (<span class="hljs-string">"z: "</span>..z..<span class="hljs-string">"p-1: "</span>..p-1)  
--             <span style=<span class="hljs-string">"white-space:pre"</span>>         </span>test_result = test_result ..<span class="hljs-string">"y: "</span>..y..<span class="hljs-string">"\n"</span>  
--             <span style=<span class="hljs-string">"white-space:pre"</span>>         </span>logcat (<span class="hljs-string">"y: "</span>..y)  
--             <span style=<span class="hljs-string">"white-space:pre"</span>>         </span>test_result = test_result ..<span class="hljs-string">"p: "</span>..p..<span class="hljs-string">"\n"</span>  
--             <span style=<span class="hljs-string">"white-space:pre"</span>>         </span>logcat (<span class="hljs-string">"p: "</span>..p)  
--             <span style=<span class="hljs-string">"white-space:pre"</span>>         </span>test_result = test_result ..<span class="hljs-string">"k: "</span>..(k[bit.bxor(bit.band((p), 3), e)+1])..<span class="hljs-string">"\n"</span>  
--             <span style=<span class="hljs-string">"white-space:pre"</span>>         </span>logcat (<span class="hljs-string">"k: "</span>..k[bit.bxor(bit.band((p), 3), e)+1])  
            mx = bit.bxor(_int32(bit.bxor(bit.band(bit.rshift(z, 5), 0x07ffffff), bit.lshift(y , 2)) + bit.bxor(bit.band(bit.rshift(y, 3), 0x1fffffff), bit.lshift(z, 4))), _int32(bit.bxor(<span class="hljs-built_in">sum</span>, y) + bit.bxor(k[bit.bxor(bit.band((p), 3), e)+1], z)))  
--             <span style=<span class="hljs-string">"white-space:pre"</span>>         </span>test_result = test_result ..<span class="hljs-string">"mx: "</span>..mx..<span class="hljs-string">"\n"</span>  
--             <span style=<span class="hljs-string">"white-space:pre"</span>>         </span>logcat (<span class="hljs-string">"mx: "</span>..mx)  
            y  = _int32(v [p+1] - mx)  
--                         test_result = test_result ..<span class="hljs-string">"y: "</span>..y..<span class="hljs-string">"p: "</span>..p..<span class="hljs-string">"\n"</span>  
--             <span style=<span class="hljs-string">"white-space:pre"</span>>         </span>logcat (<span class="hljs-string">"y: "</span>..y..<span class="hljs-string">"p: "</span>..p)  
            v [p+1] = y  
  
  
        end  
  
  
        p = 0  
        z = v[n+1]  
--                 test_result = test_result ..<span class="hljs-string">"z2: "</span>..z..<span class="hljs-string">"\n"</span>  
--         <span style=<span class="hljs-string">"white-space:pre"</span>>       </span>logcat (<span class="hljs-string">"z2: "</span>..z)  
        mx = bit.bxor(_int32(bit.bxor(bit.band(bit.rshift(z, 5), 0x07ffffff), bit.lshift(y , 2)) + bit.bxor(bit.band(bit.rshift(y, 3), 0x1fffffff), bit.lshift(z, 4))), _int32(bit.bxor(<span class="hljs-built_in">sum</span>, y) + bit.bxor(k[bit.bxor(bit.band((p), 3), e)+1], z)))  
--                 test_result = test_result ..<span class="hljs-string">"mx2: "</span>..mx..<span class="hljs-string">"\n"</span>  
--         <span style=<span class="hljs-string">"white-space:pre"</span>>       </span>logcat (<span class="hljs-string">"mx2: "</span>..mx)  
        y = _int32(v[1] - mx)  
--         <span style=<span class="hljs-string">"white-space:pre"</span>>       </span>test_result = test_result ..<span class="hljs-string">"y2: "</span>..y..<span class="hljs-string">"\n"</span>  
--         <span style=<span class="hljs-string">"white-space:pre"</span>>       </span>logcat (<span class="hljs-string">"y2: "</span>..y)  
        v [1] = y  
        <span class="hljs-built_in">sum</span> = _int32(<span class="hljs-built_in">sum</span> - delta)  
    end  
  
  
    <span class="hljs-built_in">return</span> _long2str(v, <span class="hljs-literal">true</span>)  
end  
</code>  








PS: 由于不是纯LUA代码（为Xscript LUA脚本代码），所以需要修改部分代码才可以运行，需注意。
]]

