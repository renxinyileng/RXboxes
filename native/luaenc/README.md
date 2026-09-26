# Lua 脚本加密

源码在仓库中保持明文；Gradle 在打包及签名前自动加密两个模块的 assets 和
Java resources 中的 `.lua`。Debug、Release、APK、AAB 均启用，CI 不跳过。
运行时由 `luaL_loadfilex` / `luaL_loadbufferx` 在内存中认证、解密并加载。
加密任务是打包输入的必需依赖，失败会阻止打包。

## v2 认证加密格式

```
magic[8] = 1b 4c 45 4e 43 02 0d 0a
nonce[12] = 每个文件独立的安全随机数
 tag[32] = HMAC-SHA256(mac_key, magic || nonce || ciphertext)
ciphertext[...] = AES-256-CTR(enc_key, nonce || u32_be(counter), payload)
```

计数器从 0 开始，每块 16 字节，最多 `2^32` 块。主密钥仍从 `luaenc.c` 的
六张混淆表重组，Python 打包器直接读取同一份表。两类子密钥独立派生：

```
enc_key = HMAC-SHA256(master_key, "LUAENC2-ENC")
mac_key = HMAC-SHA256(master_key, "LUAENC2-MAC")
```

运行时先以固定长度比较验证完整 HMAC，成功后才分配并生成明文。
修改版本、nonce、认证值、密文，或截断、追加内容，都会导致加载失败。
带新协议前缀但头不完整、版本未知的文件也会被拒绝。明文缓冲、子密钥、
AES 轮密钥用完擦除；每个文件只展开一次 AES 轮密钥。

算法均由项目内实现；Python 只使用标准库，不依赖 `cryptography`。
新格式保留明确版本标识，方便可靠地区分协议和处理损坏文件。

### 兼容与迁移

旧格式为 `nonce[8] + SHA256(master_key || nonce)[:8] + ciphertext`，
其 tag 只校验 nonce，**不能检测载荷篡改**。新运行时保留旧格式读取能力，
`enc-file` / `enc-apk` 遇到旧密文会解密后升级为 v2；有效 v2 内容重复打包保持不变。
`verify-apk` 要求全部 `.lua` 都是认证有效的 v2 密文，旧包须先重新加密。

新密文需要同时发布本次编译的 `libluajava.so`，旧运行时不支持 v2。
旧格式的历史载荷无法补做可信认证；迁移应优先使用仓库内可信源码重新构建。
保留旧格式兼容意味着旧输入仍没有认证保护；v2 认证不会改变这个边界。

## 保护边界

这套方案保护 APK 内脚本，防止直接解包阅读，并检测未持有密钥时对 v2 文件的
修改。密钥随客户端分发，能提取密钥或读取运行时内存的人仍可能恢复脚本或
伪造认证值。它不提供来源签名、防回滚或动态内存绝对保密。

现有定制 VM、常量池混淆和反调试机制继续使用，本次没有更换主密钥、VM
映射或加强反调试。它们是提高分析成本的措施，不能保证反编译工具永远失效。

## 文件与加载入口

| 文件 | 作用 |
|---|---|
| `androlua/src/main/jni/lua/luaenc.c` / `.h` | AES、SHA-256、HMAC、密钥重组、v1/v2 读取与擦除 |
| `androlua/src/main/jni/lua/lauxlib.c` | 文件及内存加载前的认证解密 |
| `native/luaenc/pack.py` | 加密、旧格式迁移、无调试信息字节码编译、APK 校验 |
| `native/luaenc/test_pack.py` | Python/C 一致性、篡改拒绝、实际 Lua 加载与打包回归 |
| `gradle/lua-encryption.gradle` | 两个模块所有变体的打包输入转换任务 |
| `native/luaenc/build_inputs.py` | 加密 assets 目录和 Java resources，保留其他资源内容 |
| `.github/workflows/android.yml` | 同源 host Lua 构建、集成测试、签名前加密与校验 |

`doFile`、`require`、`dofile`、`loadfile` 最终经过文件加载钩子；
`LloadBuffer` 与 Lua 的 `load(string)` 经过内存加载钩子。
`load(reader_function)` 仍遵循 Lua 原始 reader 协议，不自动解密分段密文。
普通源码和定制 VM 字节码继续可读，加载模式 `t` / `b` 约束解密后的内容。
文件加载保留 BOM、首行 shebang 与行号语义，缓冲加载保留 Lua 的原始语义。

解密后直接交给解析器，禁止递归拆开多层密文。`.lua` 后缀保持不变，
以兼容 AndroLua 的文件名解析和入口约定。

## 定制 VM 与密钥维护

- 83 个 opcode 重排与 iABC 的 B/C 位域交换由 `gen_opcodes.py` 同步生成。
  `OP_EXTRAARG` 保持末位；算术、比较等依赖枚举差值的组保留组内连续顺序。
- `ldump.c` / `lundump.c` 对称处理字符串、数值常量载荷盐。
  编译字节码必须使用本仓库同源码构建的 host Lua，不能用系统标准 Lua 替代。
- 主密钥六表 A/B/C/R/P/W 通过置换、掩码、旋转与链式白化重组。
  `gen_key.py` 不带参数仅重新拆分现有密钥；`--seed` 可复现，`--check` 只校验。
  **只换拆分且主密钥相同不影响旧密文；换主密钥才影响密文兼容性。**
- 改 VM 映射或常量盐后应重编运行时并重新编译所有字节码。

## 打包与校验

构建同源 host Lua（Linux）：

```bash
make -C androlua/src/main/jni/lua clean
make -C androlua/src/main/jni/lua all \
  MYCFLAGS="-std=c99 -D_GNU_SOURCE -DLUA_USE_LINUX" MYLIBS="-ldl"
```

`-D_GNU_SOURCE` 暴露 host 端需要的 POSIX 声明；`lbitlib.o` 必须保留在库中。
编译辅助脚本通过 `lua -E -` 从 stdin 执行，输入脚本仅加载、编译，绝不执行业务
代码；`-E` 忽略宿主机 `LUA_INIT` 等环境变量。

```bash
python3 native/luaenc/pack.py enc-file input.lua encrypted.lua
python3 native/luaenc/pack.py enc-apk input.apk output.apk \
  --lua androlua/src/main/jni/lua/lua
python3 native/luaenc/pack.py verify-apk output.apk \
  --lua androlua/src/main/jni/lua/lua
```

`enc-apk` 在目标同目录临时写包，完整校验成功后原子替换目标；输入输出可以同名。
`enc-file` 同样先写临时文件、刷盘并认证，再替换目标；写入或替换失败保留原文件。
失败时保留原文件并清理临时文件。保留其他条目内容、压缩方式、注释和元数据；
ZIP 偏移会变化，**必须在改写后重新 zipalign，再签名**。
含重名 ZIP 条目或已有 v1/v2/v3 签名的 APK 会被拒绝。
校验还会拒绝同一个 nonce 对应不同密文的 APK，避免 CTR 密钥流复用；
多个路径保存完全相同的加密脚本仍被允许。检查范围是单个 APK，不能检测跨包复用。
host Lua 辅助进程使用 UTF-8 输入输出，每次最多等待 60 秒，超时使打包失败并清理临时包。

`verify-apk` 总会校验完整性；带 `--lua` 时还用 C 加载入口逐个解密、解析，
不执行脚本。因此它不能代替 Android 真机上的 API、界面及依赖验证。

本地正常运行 `gradlew.bat assembleDebug`、`gradlew.bat assembleRelease` 或
`gradlew.bat bundleRelease` 即会自动加密，无须再手动运行 `enc-apk`。
Android Studio 构建也通过同一套 Gradle 依赖执行，签名覆盖的是加密后的内容。
生成的中间密文位于各模块 `build/intermediates` 下；不要直接修改这些文件。

集成使用 AGP 的 `SingleArtifact.ASSETS` 与项目范围 `ScopedArtifact.JAVA_RES`
转换接口；源码 resources 另外接入 `process<Variant>JavaRes` 的输出替换。
该适配使用 AGP 9.3.1 的内部 `JAVA_RES` artifact，升级 AGP 后必须重新验证任务
依赖和脚本数量。两个模块均注册，涵盖当前仓库的脚本来源。外部依赖自带的 Java
resources 不在项目范围转换内；CI 对最终 APK 的全量检查会拦截遗漏的明文 Lua。
AGP 9.3 的 Java 资源增量合并在密文目录替换后会出现 `Unknown file: lua/...`；
此处强制该合并步骤完整执行，加密任务仍保留增量检查。
参考：[AGP artifact API](https://developer.android.com/reference/tools/gradle-api/9.3/com/android/build/api/artifact/SingleArtifact)。

可用 `-PluaencPython=/path/to/python`、`-PluaencLua=/path/to/project/lua` 指定工具。
Windows 默认使用 `python`，其他平台默认使用 `python3`。显式指定不存在的 Lua
会使任务失败。默认未找到同源 host Lua 时直接加密源码；找到时先生成无调试信息
的字节码再加密。CI 在 Gradle 构建前编译同源 host Lua，并在打包后逐个认证和解析
最终 APK 中的 Lua。常规构建不再改写已生成的 APK，因此不会破坏其签名和 ZIP 对齐。

## 回归验证

```bash
python3 native/luaenc/pack.py selftest
python3 native/luaenc/test_pack_unit.py
python3 native/luaenc/gen_key.py --check
cc -std=c99 -D_GNU_SOURCE -O2 -DLUAENC_TEST_MAIN \
  androlua/src/main/jni/lua/luaenc.c -o /tmp/luaenc-test
python3 native/luaenc/test_pack.py \
  --lua androlua/src/main/jni/lua/lua --codec /tmp/luaenc-test
```

没有同源 host Lua 时，可用 `test_pack.py --codec /path/to/luaenc-test --codec-only`
单独运行 Python/C 一致性、篡改和截断拒绝检查。它不验证 Lua 加载或 Android 运行。
Windows 下 C 测试程序已将标准输入输出设为二进制，避免 CR/LF 转换及 `0x1a` 截断。

覆盖 AES-256 标准答案、Python/C 双向交叉校验、空脚本和多种长度、认证字段及
载荷篡改、截断、追加、错误密钥、旧格式迁移、文件/缓冲加载、`require`、
编译不执行业务代码、加载模式、嵌套密文拒绝、签名保护、同名输出、
失败后文件保留和 ZIP 元数据保留。自测日志不输出主密钥或密钥片段。
