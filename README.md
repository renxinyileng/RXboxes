# RX盒子
#  介绍
    使用androlua+框架开发
    该工程使用众多开源项目
#   更新内容
    2026年7月31日
    1.Lua 解释器由 Lua 5.3.3 升级到 Lua 5.4.8，并改为随工程从源码编译
      （源码在 androlua/src/main/jni，不再使用预编译 .so）
    2.构建工具链升级：Gradle 9.6.1、AGP 9.3.1、JDK 17、compileSdk 37
    3.第三方依赖升级到当前最新：appcompat 1.7.1、material 1.14.0、
      constraintlayout 2.2.2、PdfViewPager 1.1.3、AliyunPlayer 7.16.0-full、
      jsoup 1.23.1、zip4j 2.11.6、Glide 5.0.9
    4.内置的 okhttp/okio/jsoup/zip4j/glide jar 改为 Maven 依赖
    5.移除已下线的 jcenter / bintray 仓库
    6.minSdk 21 -> 23（Material 1.14 的要求），targetSdk 保持 29
    7.GitHub Actions 工作流更新，并新增原生模块编译校验

    2023年11月20日
    1.去除冗余项目
    2.修复正式版打包报错

##  关于 Lua 解释器

工程内的 Lua 解释器与各原生模块（libluajava、socket、zip、tcc 等共 16 个 .so）
现在由 `androlua/src/main/jni` 下的源码编译产生：

- 模块骨架取自 AndroLua+ 5.0.20 源码，与原先随包的 5.0.22 预编译产物
  在 JNI 接口（118 个方法）和模块构成上完全一致
- Lua 内核与 luajava 采用移植到 Lua 5.4.8 的版本
- AndroLua+ 独有的扩展全部保留：`defer` 关键字、`setmetamethod`、
  `io.readall/ls/mkdir/isdir/info`、`debug.getfenv/setfenv`、`bit32`、
  `string.gfind`、`table.gfind/const/clone`、非 ASCII（中文）标识符等
- 同时保留 Lua 5.1 兼容层（`module`、`unpack`、`loadstring`、
  `table.foreach`），工程自带的 json.lua、base64.lua 等仍是 5.1 写法

`.github/workflows/native.yml` 会单独跑一次 ndk-build，校验 16 个模块都能编出来、
且 libluajava.so 的导出符号相对旧版没有缺失。
