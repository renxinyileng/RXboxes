------------------------------------
---aead+chacha20+poly1035-
---by.tosen 2022---------------
------------------------------------

import "acp"
import "java.io.File"
local defpass = "qwertyuiopasdfghjklzxcvbnmqwerty"
local key, nonce, expected, aad, iv, const, plain, exptag, encr, res, msg
key = "\x80\x81\x82\x81\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x90\x91\x92\x93\x93\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f"
nonce = "\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07"
aad = "\x50\x51\x52\x53\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7"
iv = "\x40\x41\x42\x43\x44\x45\x46\x47"
const = "\x07\x00\x00\x00"

local function keygen(inkey)
     acp.poly_keygen(inkey, nonce)
end


local function strEncrypt(str, skey)
     local inkey = skey or defpass
     if utf8.len(skey) < 32 then
          inkey = inkey .. defpass:sub(1, 32-utf8.len(skey))
     end
     encr, tag = acp.encrypt(aad, inkey, iv, const, str)
     return encr, tag
end


local function strDecrypt(str, skey, stag)
     local inkey = skey or defpass
     if utf8.len(skey) < 32 then
          inkey = inkey .. defpass:sub(1, 32-utf8.len(skey))
     end
     res, msg = acp.decrypt(aad, inkey, iv, const, str, stag)
     return res,msg
end



local function fileEncrypt(path, skey)
     local inkey = skey or defpass
     if utf8.len(skey) < 32 then
          inkey = inkey .. defpass:sub(1, 32-utf8.len(skey))
     end

     local l = io.open(path)
     local str = l:read("*a")
     local ens = false
     l:close()
     encr, tag = acp.encrypt(aad, inkey, iv, const, str)
     if encr then
          io.open(path,"w"):write(encr):close()
          return encr, tag
     end
     l:close()
end


local function fileDecrypt(path, skey, stag)
     local inkey = skey or defpass
     if utf8.len(skey) < 32 then
          inkey = inkey .. defpass:sub(1, 32-utf8.len(skey))
     end
     if File(path).exists() then
          local l = io.open(path)
          local str = l:read("*a")
          res, msg = acp.decrypt(aad, inkey, iv, const, str, stag)
          l:close()
          return res,msg
     end
end




return {
     string={
          keygen=keygen,
          encrypt=strEncrypt,
          decrypt=strDecrypt,
     },
     file={
          keygen=keygen,
          encrypt=fileEncrypt,
          decrypt=fileDecrypt,
     },
}
