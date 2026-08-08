# Lua 脚本加密

打包时把 `.lua` 换成密文，运行时在内存里透明解密，磁盘/APK 里不出现明文源码。

## 威胁模型（先说清楚能做到什么）

这是**混淆级**防护，不是数学级保密。解密密钥随 `.so` 出厂，有决心的逆向者
反汇编 `libluajava.so` 仍能取到密钥、进而解出全部脚本；即便不取密钥，也能
hook `luaL_loadbufferx` 在解密后的那一刻 dump 内存明文。

目标是把门槛从**「`unzip` 就能读源码」**抬到**「要会脱壳 + 逆向 native」**，
挡住绝大多数人。想要更强只能靠服务端下发 + 远程鉴权，那是另一套工程。

## 组成

| 文件 | 作用 |
|---|---|
| `androlua/src/main/jni/lua/luaenc.c` / `.h` | 设备端解密。含内置 SHA-256、**唯一真源的密钥**、CTR-XOR 解密 |
| `androlua/src/main/jni/lua/lauxlib.c`（改动） | 在 `luaL_loadfilex` / `luaL_loadbufferx` 里挂解密钩子 |
| `native/luaenc/pack.py` | 打包端加密器，密钥直接从 `luaenc.c` 解析，两端不漂移 |
| `.github/workflows/android.yml`（改动） | 签名前把 APK 内 `.lua` 全部改写成密文并校验 |

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

## 自测

```bash
python3 native/luaenc/pack.py selftest            # 加解密 round-trip
# 交叉验证 python 加密 ↔ C 解密：
gcc -DLUAENC_TEST_MAIN -O2 -o /tmp/luaenc native/../androlua/src/main/jni/lua/luaenc.c
python3 native/luaenc/pack.py enc-file X.lua /tmp/e.bin && /tmp/luaenc dec </tmp/e.bin | diff - X.lua
```

## 换密钥

只改 `luaenc.c` 里 `LUAENC_KEY_BEGIN`/`END` 之间那 32 字节；`pack.py` 会自动
读到新值。改后必须重编 `libluajava.so` 并重新出包，旧包与新密钥不兼容。

## 如何加固（可选，按需）

- 把密文本身也 `xxd -i` 进 `.so`，APK 里连密文文件都没有。
- 密钥拆成多段、运行时拼接 / 从设备指纹派生，抬高静态取密钥的成本。
- 关键脚本改走服务端下发 + 一次性 token，才是质变。
