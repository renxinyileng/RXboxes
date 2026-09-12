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
| `androlua/src/main/jni/lua/luaenc.c` / `.h` | 设备端解密。含内置 SHA-256、AES-256、**唯一真源的密钥（六表多级拆分）**、CTR-XOR 解密、常量池载荷盐、解密入口自校验 |
| `androlua/src/main/jni/lua/luaanti.c` / `.h` | 反 Frida / 反调试：maps 扫描、线程名、27042 D-Bus 握手、TracerPid（全 syscall 直读），命中即延迟自毁；特征串按 XOR 盐加密存放（防 `strings` 抖出方案） |
| `androlua/src/main/jni/lua/ldump.c` / `lundump.c`（改动） | 字节码常量池载荷加密（字符串/数值 XOR 盐），两端对称 |
| `androlua/src/main/jni/lua/lauxlib.c`（改动） | 在 `luaL_loadfilex` / `luaL_loadbufferx` 里挂解密钩子 + 反注入检测 + 明文用完即擦 |
| `androlua/src/main/jni/lua/lopcodes.h` 等 4 文件（改动） | **定制 VM**：83 个 opcode 重排 + iABC 的 B/C 位域交换（见下） |
| `native/luaenc/gen_opcodes.py` | 定制 VM opcode 表生成器（固定种子可复现，换种子 = 换一套映射） |
| `native/luaenc/gen_key.py` | 密钥六表混淆拆分生成器（据目标密钥反解，绝不打印明文；`--seed` 可复现，`--check` 只校验） |
| `native/luaenc/pack.py` | 打包端加密器，密钥直接从 `luaenc.c` 六表解析并按同款多级逻辑重组，两端不漂移；支持 `--lua` strip 编译 |
| `.github/workflows/android.yml`（改动） | 构建 host lua → strip 编译 → 签名前把 APK 内 `.lua` 全部改写成密文并校验 |

## 定制 VM（opcode 重排 + 位域盐）

- 83 个 opcode 按固定种子（`20260805`）重排，`OP_EXTRAARG` 保持末位；
  `lopcodes.h`/`ljumptab.h`/`lopnames.h`/`lopcodes.c` 由
  `python3 native/luaenc/gen_opcodes.py [--seed N]` 一次性同步生成
  （内含一致性断言，改种子 = 换一套映射，与旧字节码不兼容）。
- **重排约束**：`lcode.c` 的 `binopr2op`/`unopr2op` 用「枚举差值」推导
  opcode（`opr - baser + base`），以下原子组必须保持官方相对顺序连续，
  生成器按「组间洗牌、组内不动」处理（勿手工打散）：
  `ADD..SHR`、`ADDK..BXORK`、`UNM..LEN`、`LT/LE`、`LTI/LEI`、`GTI/GEI`。
- iABC 的 B/C 字段位置交换（`lopcodes.h` 的 `POS_B`/`POS_C` 宏）作位域盐，
  所有 `GETARG_*`/`SETARG_*`/`CREATE_*` 宏跟随，编译期自动一致、运行期零开销。
- 效果：`unluac`/`luadec` 按标准格式硬解码全部错位；配合阶段 A 的 strip，
  反编译回到"行为分析"级别。注意纯重排可被对照/统计方法恢复（见
  `ulua` 等工具），这是拖延层不是防线。

## 密文格式（无明文魔数）

```
nonce[8] = 每个文件随机（明文存放，让各文件密钥流互相独立）
tag[8]   = SHA256(KEY || nonce) 前 8 字节
ct[...]  = 明文 XOR AES-256-CTR 密钥流
```

**没有固定魔数**：整个头就是 nonce + tag，对没有 KEY 的人来说与随机字节
不可区分——grep 不到签名，打开文件也看不出用了什么方案。tag 同时充当
「是不是本方案加密的」判据和密钥/完整性校验：读头 16 字节，用 nonce 重算
SHA256(KEY||nonce)[:8] 与 tag 比对，命中才解密。

密码算法 **AES-256-CTR**：`key` = 拆分方案（SEGS/MASK/MAP）重组出的 32 字节；
`block_j(16B) = AES256(key, nonce(8) || u64_be(j))`，`j = 0,1,2,…`，明文逐 16
字节与密钥流异或。设备端 `luaenc.c` 自带一份 AES-256（该 so 没链 OpenSSL），
打包端 `pack.py` 用等价的纯 Python AES-256（不依赖 cryptography，避免其
`_cffi_backend` 在部分环境缺失），两端过 FIPS-197 已知答案向量对齐、并有
C↔Python round-trip 兜底。

tag 仍用 SHA-256(KEY||nonce)[:8]，只作检测/校验，与密码算法无关。明文脚本
首 16 字节恰好通过 tag 校验的概率约 2^-64，可忽略，不会把明文误判成密文。

> 注：`.lua` 后缀仍保留在 APK 内。改后缀会牵动 AndroLua 的 require/doFile/
> newActivity 名称解析（硬编码 `.lua`）以及 Welcome 对 main.lua/init.lua 的
> 特判，回归面大而收益低（本就是明显的 AndroLua 应用），故未动。

## 密钥（六表多级拆分，防静态提取）

32 字节密钥不以完整形态、也不以「两表异或即得」的形式出现在 `.so` 里，
而是拆成 **6 张表**（`luaenc.c` 的 `LUAENC_KEY_BEGIN`/`END` 之间，唯一真源），
运行时用「置换 + 异或掩码 + 加法掩码 + 逐字节位旋转 + CBC 式链式白化」重组：

```
表：A[32] 段字节 · B[32] 异或掩码 · C[32] 加法掩码 · R[32] 旋转量(0..7)
    · P[32] 置换 · W[32] 白化掩码
阶段一（按置换收集，每字节混入 3 种运算）：
    j = P[i]; s[i] = rotl8( ((A[j] ^ B[j]) + C[j]) & 0xff , R[j] & 7 )
阶段二（链式白化，令每个输出字节耦合前一个）：
    prev = 0xA5; key[i] = s[i] ^ W[i] ^ prev; prev = key[i]
```

阶段二的链式白化是关键：每个输出字节都依赖前一个输出，单看任意几张表都
无法还原，破坏了旧方案「dump 两张数组一次异或就出密钥」的可分析性。

三处逻辑互为镜像、永不漂移：设备端 `luaEnc_getKey`（C 正向）、打包端
`pack.py` 的 `load_key`（Python 正向）、生成器 `gen_key.py` 的 `reconstruct`
（正向）+ 逆运算（据密钥反解 6 表）。改动任一处，`selftest` 与
C↔Python round-trip 都会立刻抓出不一致。

**换拆分 / 换密钥**：跑 `python3 native/luaenc/gen_key.py`（`--seed N` 可复现）。
不带参数时保持现有密钥值不变、只换一套混淆拆分；该脚本据目标密钥反解 6 表，
**绝不打印密钥明文**。改后必须重编 `libluajava.so` 并重新出包，旧包不兼容。

### 设备端重组的额外混淆（仅 C 侧，不改结果）

`luaEnc_getKey` 在六表重组之上再叠三层，只让设备侧难读，`pack.py`/`gen_key.py`
仍是干净镜像：

- **防常量折叠**：本文件在 ndk 侧以 `-O3 -flto` 编译、六表又全 `const`，编译器
  能把「const 表 → 成品密钥」整体折叠进 `.rodata`（拆表白拆）。挂一个 volatile
  锚点（运行期恒 `0xA5`、编译期不可知）参与重组，强制每次真跑一遍——实测 `-O3`
  产物里搜不到成品密钥的连续 32 字节。
- **碎片化**：阶段一单字节重组拆成 `__noinline__` 的 `luaEnc_stage1`。
- **MBA 恒等式**：`+`/`^` 改写成 `(a|b)-(a&b)` / `(a^b)+2*(a&b)`，抹掉「查表异或」
  的可辨模式；中间数组按步长 7 乱序填充，避开顺序循环。

成品密钥用完即擦（中间态与调用方 `keystream_block`/`compute_tag` 均 wipe）。

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

**特征串加密存放**：上述特征词（`frida`/`gum-js`/`pool-frida`/`TracerPid:`/
`REJECTED` 等、以及 `/proc` 路径与 AUTH 握手字节）不以明文入 `.so`，而是按
固定 XOR 盐存放、用时解到栈缓冲、用完即弃，避免 `strings | grep frida` 一下
就把检测方案抖搂干净。盐取自 volatile（否则 `-O3` 会在编译期把明文折叠回
`.rodata`）；`LUAANTI_TEST_MAIN` 自测逐条校验解出的明文，编码手误编译期即失败，
不会静默让某路检测失效。仅抬高静态阅读门槛，非密码学。

## 为什么钩这两个函数就够

所有落盘脚本的加载最终都经过 Lua 核心这两个函数，一处兜住全部：

- `doFile` → `LloadFile` → `luaL_loadfile` → **`luaL_loadfilex`**
- `require`（Lua 搜索器）、`dofile`、`loadfile` → **`luaL_loadfilex`**
- `LloadBuffer`（如 Welcome 加载 `update.lua`）→ `luaL_loadbuffer` → **`luaL_loadbufferx`**

只在检测到魔数头时改道解密；普通脚本、字节码文件走原逻辑不变（向后兼容，
未加密的包也能跑）。解出来的明文不带魔数，递归回来不会二次解密。

## 在哪一步加密

`.lua` 源码始终以**明文**留在仓库(可读、可改、可 diff)；加密只发生在打包时，
对最终 APK 的 zip 条目改写——**与 AGP 版本无关**、只动 `.lua` 条目、
`.so`/manifest/resources 逐字节原样。选 APK 层而非 sourceSet 层，是因为构建
app 时 AGP 会把 androlua 模块的 `resources/lua` 也并进 APK，只有在 APK 层
改写才能把各模块的 `.lua` 一网打尽。

两处都会加密，互为双保险（`pack.py` 幂等，先跑到的那次生效，另一次空操作）：

1. **本地 `./gradlew assembleRelease`** —— `app/build.gradle` 注册的
   `encryptReleaseLua` 作为 `assembleRelease` 的 finalizer，对产出的**未签名**
   release APK 跑 `pack.py enc-apk`。缺 python3 只告警不失败；APK 若已签名则
   跳过（改写会破坏签名，`pack.py` 直接拒绝）。正常本地流程：出未签名包→
   自动加密→再签名。debug 包不加密（保留可调试）。
2. **CI** —— 在签名前额外跑一遍 `enc-apk` + `verify-apk`。因为 gradle 那步
   已经加密，这里通常是空操作，但 `verify-apk` 会硬断言 APK 内每个 `.lua`
   都是密文，是最终防线。

## 阶段 A：strip 编译（unluac 失效）

CI 在加密前先用**与设备同一份源码**（含定制 VM 重排与常量盐）编译 host
lua，再对每个 `.lua` 执行 `string.dump(f, true)`（等价 `luac -s`）生成
**剥离调试信息**的字节码，之后才加密。`unluac` 依赖调试信息，strip 后直接
失效；`luadec` 不支持 5.4。host lua 构建：

```bash
make -C androlua/src/main/jni/lua all MYCFLAGS="-std=c99 -D_GNU_SOURCE -DLUA_USE_LINUX" MYLIBS="-ldl"
```

本地复现：`python3 native/luaenc/pack.py enc-apk in.apk out.apk --lua androlua/src/main/jni/lua/lua`

## 自测

```bash
python3 native/luaenc/pack.py selftest            # 加解密 round-trip
python3 native/luaenc/gen_key.py --check          # 校验 luaenc.c 六表能重组出密钥
python3 native/luaenc/gen_opcodes.py              # 定制 VM 表重排（幂等，可复现）
# 交叉验证 python 加密 ↔ C 解密（同时验证 C 的 luaEnc_getKey 与 pack.py 密钥一致）：
gcc -DLUAENC_TEST_MAIN -std=c99 -D_GNU_SOURCE -O2 -o /tmp/luaenc androlua/src/main/jni/lua/luaenc.c
/tmp/luaenc enc <X.lua >/tmp/e.bin && python3 -c "import sys;sys.path.insert(0,'native/luaenc');import pack;\
open('/tmp/d.bin','wb').write(pack.decrypt(open('/tmp/e.bin','rb').read(),pack.load_key()))" && diff /tmp/d.bin X.lua
# host lua 完整链路（CI 同款）：构建 → strip 编译 → 加密 → 校验
make -C androlua/src/main/jni/lua all MYCFLAGS="-std=c99 -D_GNU_SOURCE -DLUA_USE_LINUX" MYLIBS="-ldl"
python3 native/luaenc/pack.py enc-apk app.apk app-enc.apk --lua androlua/src/main/jni/lua/lua
python3 native/luaenc/pack.py verify-apk app-enc.apk
```

## 换密钥 / 换 opcode 映射

- **换密钥 / 换拆分**：跑 `python3 native/luaenc/gen_key.py`（`--seed N` 可复现）
  重新生成 `luaenc.c` 的 6 张表（A/B/C/R/P/W）。不带参数时保持现有密钥值不变、
  只换一套混淆拆分；该脚本据目标密钥反解、**绝不打印明文**，`pack.py` 自动读到
  新表。改后必须重编 `libluajava.so` 并重新出包，旧包与新表不兼容。
- **换 opcode 映射**：`python3 native/luaenc/gen_opcodes.py --seed N` 换种子
  重排；同样必须重编 so 并出包。同版本发布即可，无历史兼容包袱。

## 如何加固（可选，按需）

- 把密文本身也 `xxd -i` 进 `.so`，APK 里连密文文件都没有。
- 密钥拆成多段、运行时拼接 / 从设备指纹派生，抬高静态取密钥的成本。
- 关键脚本改走服务端下发 + 一次性 token，才是质变。
