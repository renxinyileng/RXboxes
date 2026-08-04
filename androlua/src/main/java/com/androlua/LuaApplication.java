package com.androlua;

import android.app.Application;
import android.content.Context;
import android.content.FileProvider;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;
import android.os.Environment;
import android.preference.PreferenceManager;
import android.widget.Toast;

import com.luajava.LuaState;
import com.luajava.LuaTable;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

public class LuaApplication extends Application implements LuaContext {

    private static LuaApplication mApp;
    static private HashMap<String, Object> data = new HashMap<String, Object>();
    protected String localDir;
    protected String odexDir;
    protected String libDir;
    protected String luaMdDir;
    protected String luaCpath;
    protected String luaLpath;
    protected String luaExtDir;
    private boolean isUpdata;
    private SharedPreferences mSharedPreferences;

    public Uri getUriForPath(String path) {
        return FileProvider.getUriForFile(this, getPackageName(), new File(path));
    }

    public Uri getUriForFile(File path) {
        return FileProvider.getUriForFile(this, getPackageName(), path);
    }

    public String getPathFromUri(Uri uri) {

        String path = null;
        if (uri != null) {
            String[] p = {
                    getPackageName()
            };
            switch (uri.getScheme()) {
                case "content":
                    /*try {
						InputStream in = getContentResolver().openInputStream(uri);
					} catch (IOException e) {
						e.printStackTrace();
					}*/
                    Cursor cursor = getContentResolver().query(uri, p, null, null, null);

                    if (cursor != null) {
                        int idx = cursor.getColumnIndexOrThrow(getPackageName());
                        if (idx < 0)
                            break;
                        path = cursor.getString(idx);
                        cursor.moveToFirst();
                        cursor.close();
                    }
                    break;
                case "file":
                    path = uri.getPath();
                    break;
            }
        }
        return path;
    }


    public static LuaApplication getInstance() {
        return mApp;
    }

    @Override
    public ArrayList<ClassLoader> getClassLoaders() {
        // TODO: Implement this method
        return null;
    }

    @Override
    public void regGc(LuaGcable obj) {
        // TODO: Implement this method
    }

    @Override
    public String getLuaPath() {
        // TODO: Implement this method
        return null;
    }

    @Override
    public String getLuaPath(String path) {
        return new File(getLuaDir(), path).getAbsolutePath();
    }

    @Override
    public String getLuaPath(String dir, String name) {
        return new File(getLuaDir(dir), name).getAbsolutePath();
    }

    @Override
    public String getLuaExtPath(String path) {
        return new File(getLuaExtDir(), path).getAbsolutePath();
    }

    @Override
    public String getLuaExtPath(String dir, String name) {
        return new File(getLuaExtDir(dir), name).getAbsolutePath();
    }

    public int getWidth() {
        return getResources().getDisplayMetrics().widthPixels;
    }

    public int getHeight() {
        return getResources().getDisplayMetrics().heightPixels;
    }

    @Override
    public String getLuaDir(String dir) {
        // TODO: Implement this method
        return localDir;
    }

    @Override
    public String getLuaExtDir(String name) {
        File dir = new File(getLuaExtDir(), name);
        if (!dir.exists())
            if (!dir.mkdirs())
                return dir.getAbsolutePath();
        return dir.getAbsolutePath();
    }

    public String getLibDir() {
        // TODO: Implement this method
        return libDir;
    }

    public String getOdexDir() {
        // TODO: Implement this method
        return odexDir;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        mApp = this;
        CrashHandler crashHandler = CrashHandler.getInstance();
        // 注册crashHandler
        crashHandler.init(getApplicationContext());
        mSharedPreferences = getSharedPreferences(this);
        //初始化AndroLua工作目录
        if (Environment.getExternalStorageState().equals(Environment.MEDIA_MOUNTED)) {
            String sdDir = Environment.getExternalStorageDirectory().getAbsolutePath();
            luaExtDir = sdDir + "/AndroLua";
        } else {
            File[] fs = new File("/storage").listFiles();
            for (File f : fs) {
                String[] ls = f.list();
                if (ls == null)
                    continue;
                if (ls.length > 5)
                    luaExtDir = f.getAbsolutePath() + "/AndroLua";
            }
            if (luaExtDir == null)
                luaExtDir = getDir("AndroLua", Context.MODE_PRIVATE).getAbsolutePath();
        }

        File destDir = new File(luaExtDir);
        if (!destDir.exists()) {
            boolean b = destDir.mkdirs();
            if(!b){
                luaExtDir = this.getExternalFilesDir(null).getAbsolutePath() + "/AndroLua";
            }

        }
        destDir = new File(luaExtDir);
        if (!destDir.exists()) {
            destDir.mkdirs();
        }
        //定义文件夹
        localDir = getFilesDir().getAbsolutePath();
        odexDir = getDir("odex", Context.MODE_PRIVATE).getAbsolutePath();
        libDir = getDir("lib", Context.MODE_PRIVATE).getAbsolutePath();
        luaMdDir = getDir("lua", Context.MODE_PRIVATE).getAbsolutePath();
        luaCpath = getApplicationInfo().nativeLibraryDir + "/lib?.so" + ";" + libDir + "/lib?.so";
        //luaDir = extDir;
        luaLpath = luaMdDir + "/?.lua;" + luaMdDir + "/lua/?.lua;" + luaMdDir + "/?/init.lua;";
        //首次安装或版本升级时,把 APK 内 assets/lua 解压到工作目录(Welcome 不再作为启动入口,解压前移到这里)
        updateAssets();
    }

    private void updateAssets() {
        try {
            String ver = getPackageManager().getPackageInfo(getPackageName(), 0).versionName;
            String old = mSharedPreferences.getString("versionName", "");
            if (!ver.equals(old)) {
                unApk("assets", localDir);
                unApk("lua", luaMdDir);
                mSharedPreferences.edit().putString("versionName", ver).apply();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void unApk(String dir, String extDir) throws IOException {
        int i = dir.length() + 1;
        ZipFile zip = new ZipFile(getApplicationInfo().publicSourceDir);
        Enumeration<? extends ZipEntry> entries = zip.entries();
        while (entries.hasMoreElements()) {
            ZipEntry entry = entries.nextElement();
            String name = entry.getName();
            if (name.indexOf(dir) != 0)
                continue;
            String path = name.substring(i);
            if (entry.isDirectory()) {
                File f = new File(extDir + File.separator + path);
                if (!f.exists()) {
                    //noinspection ResultOfMethodCallIgnored
                    f.mkdirs();
                }
            } else {
                String fname = extDir + File.separator + path;
                File ff = new File(fname);
                File temp = new File(fname).getParentFile();
                if (!temp.exists()) {
                    if (!temp.mkdirs()) {
                        throw new RuntimeException("create file " + temp.getName() + " fail");
                    }
                }
                try {
                    if (ff.exists() && entry.getSize() == ff.length() && LuaUtil.getFileMD5(zip.getInputStream(entry)).equals(LuaUtil.getFileMD5(ff)))
                        continue;
                } catch (NullPointerException ignored) {
                }
                FileOutputStream out = new FileOutputStream(extDir + File.separator + path);
                InputStream in = zip.getInputStream(entry);
                byte[] buf = new byte[4096];
                int count;
                while ((count = in.read(buf)) != -1) {
                    out.write(buf, 0, count);
                }
                out.close();
                in.close();
            }
        }
        zip.close();
    }

    private static SharedPreferences getSharedPreferences(Context context) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            Context deContext = context.createDeviceProtectedStorageContext();
            if (deContext != null)
                return PreferenceManager.getDefaultSharedPreferences(deContext);
            else
                return PreferenceManager.getDefaultSharedPreferences(context);
        } else {
            return PreferenceManager.getDefaultSharedPreferences(context);
        }
    }

    @Override
    public String getLuaDir() {
        // TODO: Implement this method
        return localDir;
    }

    @Override
    public void call(String name, Object[] args) {
        // TODO: Implement this method
    }

    @Override
    public void set(String name, Object object) {
        // TODO: Implement this method
        data.put(name, object);
    }

    @Override
    public Map getGlobalData() {
        return data;
    }


    @Override
    public Object getSharedData(String key) {
        return mSharedPreferences.getAll().get(key);
    }

    @Override
    public Object getSharedData(String key, Object def) {
        Object ret = mSharedPreferences.getAll().get(key);
        if (ret == null)
            return def;
        return ret;
    }

    @Override
    public boolean setSharedData(String key, Object value) {
        SharedPreferences.Editor edit = mSharedPreferences.edit();
        if (value == null)
            edit.remove(key);
        else if (value instanceof String)
            edit.putString(key, value.toString());
        else if (value instanceof Long)
            edit.putLong(key, (Long) value);
        else if (value instanceof Integer)
            edit.putInt(key, (Integer) value);
        else if (value instanceof Float)
            edit.putFloat(key, (Float) value);
        else if (value instanceof Set)
            edit.putStringSet(key, (Set<String>) value);
        else if (value instanceof LuaTable)
            edit.putStringSet(key, (HashSet<String>) ((LuaTable) value).values());
        else if (value instanceof Boolean)
            edit.putBoolean(key, (Boolean) value);
        else
            return false;
        edit.apply();
        return true;
    }

    public Object get(String name) {
        // TODO: Implement this method
        return data.get(name);
    }

    public String getLocalDir() {
        // TODO: Implement this method
        return localDir;
    }


    public String getMdDir() {
        // TODO: Implement this method
        return luaMdDir;
    }

    @Override
    public String getLuaExtDir() {
        // TODO: Implement this method
        return luaExtDir;
    }

    @Override
    public void setLuaExtDir(String dir) {
        // TODO: Implement this method
        if (Environment.getExternalStorageState().equals(Environment.MEDIA_MOUNTED)) {
            String sdDir = Environment.getExternalStorageDirectory().getAbsolutePath();
            luaExtDir = new File(sdDir , dir).getAbsolutePath();
        } else {
            File[] fs = new File("/storage").listFiles();
            for (File f : fs) {
                String[] ls = f.list();
                if (ls == null)
                    continue;
                if (ls.length > 5)
                    luaExtDir = new File(f, dir).getAbsolutePath() ;
            }
            if (luaExtDir == null)
                luaExtDir = getDir(dir, Context.MODE_PRIVATE).getAbsolutePath();
        }
    }

    @Override
    public String getLuaLpath() {
        // TODO: Implement this method
        return luaLpath;
    }

    @Override
    public String getLuaCpath() {
        // TODO: Implement this method
        return luaCpath;
    }

    @Override
    public Context getContext() {
        // TODO: Implement this method
        return this;
    }

    @Override
    public LuaState getLuaState() {
        // TODO: Implement this method
        return null;
    }

    @Override
    public Object doFile(String path, Object[] arg) {
        // TODO: Implement this method
        return null;
    }

    @Override
    public void sendMsg(String msg) {
        // TODO: Implement this method
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();

    }

    @Override
    public void sendError(String title, Exception msg) {

    }


} 



