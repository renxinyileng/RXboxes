# CLAUDE.md

给未来在本仓库工作的 Claude 的导航说明。**用中文注释/提交**（全仓库一致）。

## 这是什么

**RX盒子**：基于 AndroLua+ 的 Android 应用，界面与业务逻辑几乎全用 Lua 写，
Java 只提供壳与 JNI 桥。两个 Gradle 模块：

- `app/` —— 应用壳。Lua 业务脚本在 `app/src/main/assets/**/*.lua`，
  下载页是一个 WebView 加载 `app/src/main/assets/aria2NGGUI/`（AriaNg 前端）。
- `androlua/` —— AndroLua+ 运行时库。Lua 5.4.8 内核 + luajava + 16 个原生
  模块（socket/zip/tcc/…）的**源码**在 `androlua/src/main/jni/`，随工程编译，
  不再用预编译 .so。通用 Lua 脚本在 `androlua/src/main/resources/lua/`。

`settings.gradle`：`include ':app',':androlua'`，`rootProject.name = "RX盒子"`。

## 工具链（改动前先确认版本约束）

| 项 | 版本 | 备注 |
|---|---|---|
| Gradle | 9.6.1 | `Project.exec`/`Task.exec` 已移除，要用注入的 `ExecOperations`；配置缓存关（只开 `org.gradle.caching`） |
| AGP | 9.3.1 | |
| JDK | 17 | |
| compileSdk | 37 | Glide 5 / Material 1.14 要求 ≥37 |
| minSdk | 23 | Material 1.14 要求 |
| targetSdk | **29** | 大量 Lua 直接读写外部存储，靠 `requestLegacyExternalStorage`；提到 30+ 会触发分区存储导致功能失效，**别动** |
| NDK | 27.3.13750724 | GitHub runner 自带 |

版本集中在根 `build.gradle` 的 `buildscript.ext`。

## 常用命令

```bash
./gradlew assembleDebug assembleRelease --console=plain   # 构建（CI 同款）
# 原生 Lua 模块单独校验（16 个模块 + libluajava 导出符号）：见 .github/workflows/native.yml
```

- **debug 包不加密** Lua（保留可调试）；**release 包**在打包/CI 里会把 `.lua`
  改写成密文（见下）。
- 本地 `assembleRelease` 的 finalizer `encryptReleaseLua`（`app/build.gradle`）
  对未签名 release APK 跑 `pack.py`；`CI=true` 时跳过（交给 CI 专用步骤）。

## Lua 脚本加密（混淆级，非数学级）

完整说明见 `native/luaenc/README.md`。要点：

- `.lua` 源码在仓库里**始终明文**（可读、可 diff）；加密只在打包时对 APK 的
  zip 条目改写，只动 `.lua`，`.so`/manifest/resources 逐字节不变。
- 密文格式：`nonce[8] + tag[8] + ct`，**无明文魔数**（对没密钥的人与随机字节
  不可区分）。`tag = SHA256(KEY||nonce)[:8]` 只作检测/校验。
- 密码算法 **AES-256-CTR**：设备端 `luaenc.c` 自带一份 AES-256，打包端
  `pack.py` 用等价的**纯 Python** AES-256（**不要**引 `cryptography`——其
  `_cffi_backend` 在部分环境缺失）。两端过 FIPS-197 KAT + C↔Python round-trip 对齐。
- **唯一真源的密钥**在 `luaenc.c`（**六表多级拆分** A/B/C/R/P/W：置换 + 异或掩码
  + 加法掩码 + 位旋转 + CBC 式链式白化，破坏「两表异或即得」）。`pack.py` 直接
  解析并按同款逻辑重组，两端永不漂移。换拆分/换密钥跑 `native/luaenc/gen_key.py`
  （据密钥反解、绝不打印明文），改后必须重编 so。
- 定制 VM（opcode 重排 + 位域盐）由 `native/luaenc/gen_opcodes.py` 生成；
  CI 用 host lua `string.dump(f,true)` strip 调试信息（unluac 失效）。
- 反注入/反调试在 `luaanti.c`（Frida maps/线程名/27042/TracerPid，全 syscall 直读）。

**改 luaenc.c 或 pack.py 后必做的自检**（两端漂移会静默出坏包）：

```bash
python3 native/luaenc/pack.py selftest              # AES round-trip
make -C androlua/src/main/jni/lua all MYCFLAGS="-std=c99 -D_GNU_SOURCE -DLUA_USE_LINUX" MYLIBS="-ldl"
# 然后 enc-apk --lua + verify-apk（CI 的“加密 Lua 脚本”步骤同款）
```

### host lua 构建的坑（已在 makefile / android.yml 修好，别回退）

- host 端 glibc 在 `-std=c99` 下会隐藏 POSIX/BSD 声明
  （`clock_gettime`/`CLOCK_MONOTONIC` —— luaanti.c；`st_mtim`/`st_atim` —— liolib.c），
  **必须加 `-D_GNU_SOURCE`**；设备端 bionic 默认已有、无副作用。
- host `makefile` 的 `LIB_O` 必须含 `lbitlib.o`，否则链接期 `luaopen_bit/bit32` 未定义。
- `pack.py` 的 `strip_compile` 用**环境变量**（`LUAENC_SRC/LUAENC_DST`）传路径，
  不能走位置参数：`lua -e chunk src dst` 会把 src 当成待执行脚本（arg[0]=src）。

## 下载核心 aria2（进程内 JNI）

- `native/aria2/` —— `build.sh`（交叉编译）、`aria2jni.cpp`（JNI 桥）、
  `verify.sh`（离线校验）、`host-probe.sh`（无真机 RPC 行为验证）。
- 引擎默认 **`next`**（[aria2-next](https://github.com/AnInsomniacy/aria2-next) `v2.5.5`，
  上游 1.37.0 已停更）；`ARIA2_ENGINE=upstream` 可切回。`WORK`/`OUT` 按引擎分目录。
- 产物 `libaria2jni.so` 提交在 `app/src/main/jniLibs/arm64-v8a/`（**只有 arm64-v8a**）。
  经 CMake 构建，静态链接依赖，NEEDED 里没有 `libz.so`（合理差异）。
- `Aria2.java` / `aria2NGGUI/**` / `main.lua` 的 WebView+8080 端口部分**无需改动**。

## CI 工作流（`.github/workflows/`）

- `android.yml` —— 主构建。assembleDebug/Release → 校验 native 库进 APK +
  extractNativeLibs=true + 16KB 页对齐 → 构建 host lua → strip 编译 + AES 加密 +
  verify-apk → （有 KEYSTORE secret 时）zipalign + apksigner 签名。
- `aria2.yml` —— aria2 引擎矩阵（upstream/next），编译 + verify + host RPC probe；
  `publish` job 单独提交 `.so`（`git revert` 即回滚）。
- `native.yml` —— ndk-build 校验 16 个 Lua 原生模块 + libluajava 导出符号。

推 `main` / `claude/**` / PR 到 main / 手动 dispatch 都会触发 `android.yml`。

## 分支与提交约定

- 开发分支：`claude/update-dependencies-lua-z9okd8`（用户会经 PR 合进 `main`）。
- 提交/PR/代码注释一律中文；不要把模型标识符写进任何推到仓库的产物。
- **不要主动开 PR**，除非用户明确要求。
