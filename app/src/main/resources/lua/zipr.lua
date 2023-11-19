require "import"
import "java.io.File"
import "org.manalua.util.zip4j"
import "java.io.FileOutputStream"
import "java.util.zip.ZipFile"
import "java.io.InputStreamReader"
import "java.util.zip.ZipFile"
import "java.io.BufferedReader"

--zip操作类封装库
--集成：zip、zip4j
--荼山 2879700093
--2022-03-23






local manaluaZip = zip4j()
local zipr = {

  --解压zip：要解压的文件,解压到的路径,密码   返回 true/false
  unzip=function(i,o,p)
    if p == nil then
      return manaluaZip.解压(i,o,nil) else
      return manaluaZip.解压(i,o,p)
    end
  end,

  --压缩zip：要压缩的路径,压缩到的路径,密码   返回 true/false
  zip=function(i,o,p)
    if p == nil then
      return manaluaZip.压缩(i,o,nil) else
      return manaluaZip.压缩(i,o,p)
    end
  end,

  --解压单文件：要解压的zip,要解压的文件名,解压到的文件夹,密码   返回 true/false
  unzips=function(i,f,o,p)
    if r == nil then
      return manaluaZip.单个解压(i,f,o,nil) else
      return manaluaZip.单个解压(i,f,o,p)
    end
  end,

  --zip压缩包路径  返回 true/false
  haspass=function(file)
    return manaluaZip.是否有密码(file)
  end,


  --zip列表：zip路径
  list=function(zipfile)
    local zipfile = ZipFile(File(tostring(zipfile)))
    local entries = zipfile.entries()
    local files ={}
    while entries.hasMoreElements() do
      entry=entries.nextElement();
      --合约0.1资源
      files[#files+1] = entry--通过getName()可以得到文件名称
      --a=("文件大小:"..entry.getSize())--得到文件大小
    end
    zipfile.close()
    return files
  end,


  --获取文件大小：zip路径，文件路径
  size=function(zipfile,file)
    local zipfile = ZipFile(File(tostring(zipfile)))
    local entries = zipfile.entries()
    while entries.hasMoreElements() do
      entry = entries.nextElement();
      if tostring(entry) == file then
        return entry.getSize()
      end
    end
    zipfile.close()
    return entry.getSize()
  end,

  --压缩文件或文件夹，from 源路径，dir 目标文件夹，name zip文件名称。
  zipn = function(from,dir,name)
    return LuaUtil.zip(from,dir,name)
  end,

  --获取文件内容：zip路径，文件路径，编码方式(默认 utf-8 )
  read=function(zipfile,file,code)
    local zipfile,file = ZipFile(File(tostring(zipfile))),tostring(file)
    local entries = zipfile.entries()
    local str = {}
    while entries.hasMoreElements() do
      entry = entries.nextElement();
      if tostring(entry) == file then
        local br = BufferedReader(InputStreamReader(zipfile.getInputStream(entry),code or "utf-8"));
        local line = br.readLine()
        while line ~= nil do
          str[#str+1] = line
          line = br.readLine();
        end
        break
      end
    end
    zipfile.close()
    return table.concat(str,"\n")
  end,
}



return zipr
