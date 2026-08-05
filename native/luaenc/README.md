# Lua 脚本加密

打包时把 `.lua` 换成密文，运行时在内存里透明解密，磁盘/APK 里不出现明文源码。

## 威胁模型（先说清楚能做到什么）

这是**混淆级**防护，不是数学级保密。解密密钥随 `.so` 出厂，有决心的逆向者
反汇编 `libluajava.so` 仍能取到密钥、进而解出全部脚本；即便不取密钥，也能
hook `luaL_loadbufferx` 在解密后的那一刻 dump 内存明文。

目标是把门槛从**「`unzip` 就能读源码」**抬到**「要会脱壳 + 逆向 native +
对抗反注入检测」**，挡住绝大多数人。想要更强只能靠服务端下发 + 远程鉴权，
那是另一套工程。

## 组成

| 文件 | 作用 |
|---|---|
| `androlua/src/main/jni/lua/luaenc.c` / `.h` | 设备端解密。含内置 SHA-256、**唯一真源的密钥（三表拆分）**、CTR-XOR 解密、常量池载荷盐、解密入口自校验 |
| `androlua/src/main/jni/lua/luaanti.c` / `.h` | 反 Frida / 反调试：maps 扫描、线程名、27042 D-Bus 握手、TracerPid（全 syscall 直读），命中即延迟自毁 |
| `androlua/src/main/jni/lua/ldump.c` / `lundump.c`（改动） | 字节码常量池载荷加密（字符串/数值 XOR 盐），两端对称 |
| `androlua/src/main/jni/lua/lauxlib.c`（改动） | 在 `luaL_loadfilex` / `luaL_loadbufferx` 里挂解密钩子 + 反注入检测 + 明文用完即擦 |
| `androlua/src/main/jni/lua/lopcodes.h` 等 4 文件（改动） | **定制 VM**：83 个 opcode 重排 + iABC 的 B/C 位域交换（见下） |
| `native/luaenc/gen_opcodes.py` | 定制 VM opcode 表生成器（固定种子可复现，换种子 = 换一套映射） |
| `native/luaenc/pack.py` | 打包端加密器，密钥直接从 `luaenc.c` 三表解析，两端不漂移；支持 `--lua` strip 编译 |
| `.github/workflows/android.yml`（改动） | 构建 host lua → strip 编译 → 签名前把 APK 内 `.lua` 全部改写成密文并校验 |

## 定制 VM（opcode 重排 + 位域盐）

- 83 个 opcode 按固定种子（`20260805`）重排，`OP_EXTRAARG` 保持末位；
  `lopcodes.h`/`ljumptab.h`/`lopnames.h`/`lopcodes.c` 由
  `python3 native/luaenc/gen_opcodes.py [--seed N]` 一次性同步生成
  （内含一致性断言，改种子 = 换一套映射，与旧字节码不兼容）。
- iABC 的 B/C 字段位置交换（`lopcodes.h` 的 `POS_B`/`POS_C` 宏）作位域盐，
  所有 `GETARG_*`/`SETARG_*`/`CREATE_*` 宏跟随，编译期自动一致、运行期零开销。
- 效果：`unluac`/`luadec` 按标准格式硬解码全部错位；配合阶段 A 的 strip，
  反编译回到"行为分析"级别。注意纯重排可被对照/统计方法恢复（见
  `ulua` 等工具），这是拖延层不是防线。

## 密文格式（无明文魔数）

```
nonce[8] = 每个文件随机（明文存放，让各文件密钥流互相独立）
tag[8]   = SHA256(KEY || nonce) 前 8 字节
ct[...]  = 明文 XOR 密钥流
```

**没有固定魔数**：整个头就是 nonce + tag，对没有 KEY 的人来说与随机字节
不可区分——grep 不到签名，打开文件也看不出用了什么方案。tag 同时充当
「是不是本方案加密的」判据和密钥/完整性校验：读头 16 字节，用 nonce 重算
SHA256(KEY||nonce)[:8] 与 tag 比对，命中才解密。

密钥流（CTR 模式，SHA-256 当 PRF）：
`block_j = SHA256(KEY(32) || nonce(8) || u64_le(j))`，`j = 0,1,2,…`

tag 输入是 `KEY||nonce`（40B），密钥流输入是 `KEY||nonce||ctr8`（48B），
长度不同 → tag 绝不撞任何密钥流块，天然域分离。明文脚本首 16 字节恰好通过
tag 校验的概率约 2^-64，可忽略，不会把明文误判成密文。

> 注：`.lua` 后缀仍保留在 APK 内。改后缀会牵动 AndroLua 的 require/doFile/
> newActivity 名称解析（硬编码 `.lua`）以及 Welcome 对 main.lua/init.lua 的
> 特判，回归面大而收益低（本就是明显的 AndroLua 应用），故未动。

## 密钥（三表拆分，防静态提取）

32 字节密钥不再以完整形态出现在 `.so` 里，而是拆成三张表
（`luaenc.c` 的 `LUAENC_KEY_BEGIN`/`END` 之间，唯一真源）：

```
SEGS[32] 乱序字节 + MASK[32] 异或掩码 + MAP[32] 位置映射（置换）
key[i] = SEGS[MAP[i]] ^ MASK[MAP[i]]   （运行时 luaEnc_getKey 重组）
```

`pack.py` 解析三表重建密钥（并校验 MAP 是置换），两端永不漂移。
换密钥 = 用相同逻辑重新生成三表（参考 git 历史中的生成方式）。

## 常量池载荷盐

`string.dump`/`luac -s` 产出的字节码里，字符串与数值常量载荷在
`ldump.c` 写入时被 8 字节循环掩码异或（`luaEnc_constMask()`，唯一真源），
`lundump.c` 读取时对称还原。配合定制 VM，静态阅读/工具化反编译进一步受阻。
仅防直接阅读，非密码学。

## 反注入 / 反调试（luaanti.c）

解密钩子在命中密文时调用 `luaAnti_check()`，四路检测（全 syscall 直读，
绕过 libc hook）：

- `/proc/self/maps` 找 `frida` 特征（frida-agent/gadget）
- `/proc/self/task/*/comm` 找 `gum-js`/`pool-frida` 线程名
- `127.0.0.1:27042` connect + D-Bus AUTH 握手（REJECTED/OK/DATA/ERROR）
- `/proc/self/status` 的 `TracerPid` 非 0

命中即**延迟自毁**（随机 1-5 秒后 abort，增加检测点被定位难度）；检测结果
3 秒节流缓存。此外 `luaEnc_decrypt` 入口自校验（首调快照 + 每次比对），
入口被 inline hook 改写即拒绝解密。均为拖延层：Frida 改名/换端口/重编译
可绕过，2025 年起 KPM（内核级）可屏蔽 TracerPid 读取。

## 为什么钩这两个函数就够

所有落盘脚本的加载最终都经过 Lua 核心这两个函数，一处兜住全部：

- `doFile` → `LloadFile` → `luaL_loadfile` → **`luaL_loadfilex`**
- `require`（Lua 搜索器）、`dofile`、`loadfile` → **`luaL_loadfilex`**
- `LloadBuffer`（如 Welcome 加载 `update.lua`）→ `luaL_loadbuffer` → **`luaL_loadbufferx`**

只在检测到魔数头时改道解密；普通脚本、字节码文件走原逻辑不变（向后兼容，
未加密的包也能跑）。解出来的明文不带魔数，递归回来不会二次解密。

## 为什么放在 CI 签名前，而不是 Gradle 里

`.lua` 源码始终以**明文**留在仓库(可读、可改、可 diff)；加密只发生在打包
管线。放在 CI 签名步骤前对最终 APK 的 zip 条目改写，好处是**与 AGP 版本
无关**、只动 `.lua` 条目、`.so`/manifest/resources 逐字节原样，改完再
`zipalign` + 签名。

**注意**：本地 `./gradlew assembleRelease` 不经过这一步，产物里的 `.lua`
是明文。对外分发一律走 CI 产物。若要本地也加密，可在 `app/build.gradle` 注册
一个 finalize `mergeReleaseAssets` 的 task 调用 `pack.py`（未做，因无法离线
验证 AGP 集成，留作后续）。

## 阶段 A：strip 编译（unluac 失效）

CI 在加密前先用**与设备同一份源码**（含定制 VM 重排与常量盐）编译 host
lua，再对每个 `.lua` 执行 `string.dump(f, true)`（等价 `luac -s`）生成
**剥离调试信息**的字节码，之后才加密。`unluac` 依赖调试信息，strip 后直接
失效；`luadec` 不支持 5.4。host lua 构建：

```bash
make -C androlua/src/main/jni/lua all MYCFLAGS="-std=c99 -DLUA_USE_LINUX" MYLIBS="-ldl"
```

本地复现：`python3 native/luaenc/pack.py enc-apk in.apk out.apk --lua androlua/src/main/jni/lua/lua`

## 自测

```bash
python3 native/luaenc/pack.py selftest            # 加解密 round-trip
python3 native/luaenc/gen_opcodes.py              # 定制 VM 表重排（幂等，可复现）
# 交叉验证 python 加密 ↔ C 解密：
gcc -DLUAENC_TEST_MAIN -O2 -o /tmp/luaenc native/../androlua/src/main/jni/lua/luaenc.c
python3 native/luaenc/pack.py enc-file X.lua /tmp/e.bin && /tmp/luaenc dec </tmp/e.bin | diff - X.lua
# host lua 完整链路（CI 同款）：构建 → strip 编译 → 加密 → 校验
make -C androlua/src/main/jni/lua all MYCFLAGS="-std=c99 -DLUA_USE_LINUX" MYLIBS="-ldl"
python3 native/luaenc/pack.py enc-apk app.apk app-enc.apk --lua androlua/src/main/jni/lua/lua
python3 native/luaenc/pack.py verify-apk app-enc.apk
```

## 换密钥 / 换 opcode 映射

- **换密钥**：重新生成 `luaenc.c` 的 `LUAENC_KEY_SEGS/MASK/MAP` 三张表
  （保证 `key[i] = SEGS[MAP[i]] ^ MASK[MAP[i]]` 成立即可）；`pack.py` 自动
  读到新值。改后必须重编 `libluajava.so` 并重新出包，旧包与新密钥不兼容。
- **换 opcode 映射**：`python3 native/luaenc/gen_opcodes.py --seed N` 换种子
  重排；同样必须重编 so 并出包。同版本发布即可，无历史兼容包袱。

## 如何加固（可选，按需）

- 把密文本身也 `xxd -i` 进 `.so`，APK 里连密文文件都没有。
- 密钥拆成多段、运行时拼接 / 从设备指纹派生，抬高静态取密钥的成本。
- 关键脚本改走服务端下发 + 一次性 token，才是质变。
