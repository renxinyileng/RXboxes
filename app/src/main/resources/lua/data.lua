require "import"
import "android.widget.*"
import "android.view.*"
import "android.content.*"
import "android.net.*"
import "android.provider.*"
import "java.io.File"
local data={}


data.requestPermission=function()
  local parse = Uri.parse("content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fdata");

  local intent = Intent("android.intent.action.OPEN_DOCUMENT_TREE");

  intent.setFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
  | Intent.FLAG_GRANT_WRITE_URI_PERMISSION
  | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
  | Intent.FLAG_GRANT_PREFIX_URI_PERMISSION);


  intent.putExtra("android.provider.extra.INITIAL_URI",DocumentsContract.buildDocumentUriUsingTree(parse, DocumentsContract.getTreeDocumentId(parse)));

  activity.startActivityForResult(intent, 11);

end


data.savePermission=function(requestCode, resultCode, data)
  if (data == nil) then
    return;
  end
  local uri = data.getData()
  local uri1 = "^content://com.android.externalstorage.documents/tree/.+%%3AAndroid%%2Fdata%%?2?F?$"
  if (tostring(uri):find(uri1) && requestCode == 11 && uri ~= nil) then
    activity.getContentResolver().takePersistableUriPermission(uri, data.getFlags() & (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION));--关键是这里，这个就是保存这个目录的访问权限
    return true
   else
    return false
  end
end


data.getSingleDoucmentFile=function(path)
  local path=String(path)
  if path.endsWith("/") then
    path = path.substring(0, path.length() - 1);
  end
  local path2 = path.replace("/storage/emulated/0/", ""):gsub("/sdcard/",""):gsub("/", "%%2F");
  return DocumentFile.fromSingleUri(activity, Uri.parse("content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fdata/document/primary%3A" .. path2));

end

data.getDoucmentFile=function(path)
  local path=path:gsub("/sdcard/Android/data",""):gsub("/storage/emulated/0/Android/data", "")
  if path:sub(1,1)=="/" then
    path=utf8.sub(path,2,utf8.len(path))
  end
  local pathTab=luajava.astable(String(path).split("/"))

  local doucmentfile=DocumentFile.fromTreeUri(activity, Uri.parse("content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fdata"));
  if utf8.len(path)==0 then
    return doucmentfile
  end
  
  for i=1,#pathTab do
    local doucmentfile2=doucmentfile.findFile(pathTab[i])

    if doucmentfile2==nil then
      if pathTab[i]:find("%.(.+)") then
        --    doucmentfile2=doucmentfile.createFile("*/*",pathTab[i])
       else
        --    doucmentfile2=doucmentfile.createDirectory(pathTab[i])
      end
    end

    doucmentfile=doucmentfile2

  end
  return doucmentfile
end

data.getFileLastModified=function(path)
  local file=File(path)
  local parentPath=file.parentFile.path
  local name=file.name

  return data.getDoucmentFile(parentPath).findFile(name).lastModified()
end


data.getFileLastModified=function(path)
  local file=File(path)
  local parentPath=file.parentFile.path
  local name=file.name

  return data.getDoucmentFile(parentPath).findFile(name).lastModified()
end


data.getFileList=function(path)
  local list=luajava.astable(data.getDoucmentFile(path).listFiles())
  local s=utf8.sub(path,-1)
  
  table.foreach(list,function(k,v)
    list[k]=path..(s=="/" and "" or "/")..v.name
  end)
  return list
end

data.exists=function(path)
  local file=File(path)
  local parentPath=file.parentFile.path
  local name=file.name

  return data.getDoucmentFile(parentPath).findFile(name).exists()

end

data.isDirectory=function(path)
  local file=File(path)
  local parentPath=file.parentFile.path
  local name=file.name
  return data.getDoucmentFile(parentPath).findFile(name).isDirectory()

end


data.isFile=function(path)
  local file=File(path)
  local parentPath=file.parentFile.path
  local name=file.name
  return data.getDoucmentFile(parentPath).findFile(name).isFile()
end


data.createFile=function(path)
  local file=File(path)
  local parentPath=file.parentFile.path
  local name=file.name
  return data.getDoucmentFile(parentPath).createFile("*/*",name)
end

data.isGrant=function()
  for k,uriPermission in pairs(luajava.astable(activity.getContentResolver().getPersistedUriPermissions())) do
    if (uriPermission.isReadPermission() && uriPermission.getUri().toString():find("content://com.android.externalstorage.documents/tree/primary%%3AAndroid%%2Fdata")) then
      return true;
    end
  end
  return false;
end


data.createDirectory=function(path)
  local file=File(path)
  local parentPath=file.parentFile.path
  local name=file.name
  return data.getDoucmentFile(parentPath).createDirectory(name)
end

data.renameTo=function(path,nameTo)
  local file=File(path)
  local parentPath=file.parentFile.path
  local name=file.name
  return data.getDoucmentFile(parentPath).findFile(name).renameTo(File(nameTo).name)
end

data.getFileLength=function(path)
  local singleDoucmentFile=data.getSingleDoucmentFile(path)
  return singleDoucmentFile.length()
end

data.deleteFile=function(path)
  local singleDoucmentFile=data.getSingleDoucmentFile(path)
  return singleDoucmentFile.delete()
end

data.getFileOutputStream=function(path)
  local singleDoucmentFile=data.getSingleDoucmentFile(path)
  return activity.getContentResolver().openOutputStream(singleDoucmentFile.uri)
end

data.getFileInputStream=function(path)
  local singleDoucmentFile=data.getSingleDoucmentFile(path)
  return activity.getContentResolver().openInputStream(singleDoucmentFile.uri)
end

return data