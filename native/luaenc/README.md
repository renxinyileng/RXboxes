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

## 密文格式

```
magic[5] = 1B 4C 45 4E 43  ("\x1bLENC")
ver[1]   = 0x01
nonce[8] = 每个文件随机（明文存放，仅用于让各文件密钥流互相独立）
ct[...]  = 明文 XOR 密钥流
```

密钥流（CTR 模式，SHA-256 当 PRF）：
`block_j = SHA256(KEY(32) || nonce(8) || u64_le(j))`，`j = 0,1,2,…`

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
