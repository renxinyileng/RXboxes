require "import"
urlpatn = ...
if string.sub(urlpatn, 1, 7) == "file://" then
-- First, we need to import the necessary modules
local activity = luajava.bindClass("com.androlua.LuaActivity")
local uri = luajava.bindClass("android.net.Uri")
local mediaController = luajava.bindClass("android.widget.MediaController")
local videoView = luajava.bindClass("android.widget.VideoView")
-- Then, we need to create a new VideoView object
local vv = videoView(activity)
-- Set the MediaController to the VideoView
vv:setMediaController(mediaController(activity))
-- Set the URI of the video to be played
vv:setVideoURI(uri:parse(urlpatn))
-- Start playing the video
vv:start()
-- We can check if the video is a local file or a network file by checking if the URL starts with "file://"
elseif urlpatn:find("http://") or urlpatn:find("https://") then
    local 难忘的旋律播放器=require "XLPlayer"
    难忘的旋律播放器(filename,"本地视频",nil,false)
    else
        print("无法播放")
end