require("import")
require("rxteam")
import "android.view.*"
import "android.os.*"
import "android.widget.*"
import "android.app.*"
隐藏标题栏_androidx()
path=...
import "es.voghdev.pdfviewpager.library.PDFViewPager"
import "es.voghdev.pdfviewpager.library.adapter.PDFPagerAdapter"
import "es.voghdev.pdfviewpager.library.remote.DownloadFile"
layout = PDFViewPager(this,path);
--activity.setOrientation(ViewPager.VERTICAL);
activity.setContentView(layout)
--activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
-- create a dialog to show confirmation message when user tries to exit
local builder = AlertDialog.Builder(activity)
builder.setTitle("确认退出")
builder.setMessage("确定要退出吗？")
builder.setPositiveButton("确定", {
    onClick = function(v)
        activity.finish()
    end
})
builder.setNegativeButton("取消", nil)
local dialog = builder.create()

-- override onBackPressed to show the confirmation dialog
function onBackPressed()
    dialog.show()
end

-- Note: This code assumes that the Lua script is running in an Android app and that the activity variable is already defined.