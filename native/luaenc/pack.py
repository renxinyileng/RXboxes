#!/usr/bin/env python3
"""
Lua 脚本打包加密器。与设备端 androlua/src/main/jni/lua/luaenc.c 同算法、同密钥。

密钥不在这里写死 —— 直接从 luaenc.c 的 LUAENC_KEY 数组解析，保证唯一真源、
两端永不漂移。

用法：
  pack.py selftest                 自测：随机数据 round-trip（不依赖设备）
  pack.py enc-apk <in.apk> <out> [--lua <host-lua>]
                                   把 APK 内所有 *.lua 条目改写成密文；
                                   传 --lua 时先 strip 编译成字节码再加密
  pack.py enc-file <in> <out>      加密单个文件（调试/测试用）
  pack.py verify-apk <apk> [--lua <host-lua>]
                                   检查密文格式；传 --lua 时逐个解密并解析
"""
import hashlib, os, re, subprocess, sys, zipfile, pathlib, tempfile

# 无明文魔数：头 = nonce(8) + tag(8)，tag = SHA256(KEY||nonce)[:8]。
# 没有 KEY 就算不出 tag，所以文件头对外看是随机字节、grep 不到签名。
NONCE_LEN = 8
TAG_LEN = 8
HEADER_LEN = 16

_HERE = pathlib.Path(__file__).resolve().parent
_LUAENC_C = _HERE.parent.parent / "androlua/src/main/jni/lua/luaenc.c"


def _rotl8(x, n):
    n &= 7
    return ((x << n) | (x >> ((8 - n) & 7))) & 0xFF


def load_key(path=_LUAENC_C):
    """从 luaenc.c 的 LUAENC_KEY_BEGIN/END 标记之间解析 6 张混淆表
    （A/B/C/R/P/W），按与设备端 luaEnc_getKey 逐位一致的多级逻辑重组出
    32 字节密钥：

        阶段一（按置换 P 收集，每字节混入异或掩码 B + 加法掩码 C + 位旋转 R）：
            j = P[i]; s[i] = rotl8( ((A[j] ^ B[j]) + C[j]) & 0xff , R[j] & 7 )
        阶段二（CBC 式链式白化，令每个输出字节耦合前一个）：
            prev = 0xA5; key[i] = s[i] ^ W[i] ^ prev; prev = key[i]

    这份逻辑是 gen_key.py 的逆运算的正向，三处（C / load_key / gen_key）
    互为镜像，任一漂移都会被 selftest 与 C↔Python 交叉验证抓出。"""
    txt = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")

    def grab(name):
        m = re.search(
            r"LUAENC_KEY_%s\[\s*32\s*\]\s*=\s*\{(.*?)\};" % name, txt, re.S)
        if not m:
            raise SystemExit(f"在 {path} 里找不到 LUAENC_KEY_{name} 表")
        nums = re.findall(r"0x([0-9a-fA-F]{2})", m.group(1))
        if len(nums) != 32:
            raise SystemExit(f"LUAENC_KEY_{name} 应为 32 字节，实际解析出 {len(nums)} 个")
        return [int(x, 16) for x in nums]

    A, B, C, R, P, W = (grab(n) for n in ("A", "B", "C", "R", "P", "W"))
    if sorted(P) != list(range(32)):
        raise SystemExit("LUAENC_KEY_P 不是 0..31 的置换")
    s = [0] * 32
    for i in range(32):
        j = P[i]
        v = (A[j] ^ B[j])
        v = (v + C[j]) & 0xFF
        s[i] = _rotl8(v, R[j] & 7)
    key = bytearray(32)
    prev = 0xA5
    for i in range(32):
        key[i] = s[i] ^ W[i] ^ prev
        prev = key[i]
    return bytes(key)


def _tag(key, nonce):
    # SHA256(KEY||nonce)[:8]，作"是否本方案加密"的判据 + 密钥校验，与密码算法无关
    return hashlib.sha256(key + nonce).digest()[:TAG_LEN]


# ---- AES-256（纯 Python，无外部依赖）----
# 与设备端 luaenc.c 逐位对齐（FIPS-197，Nk=8, Nr=14，只需前向分组加密）。
# 刻意不依赖 cryptography/pycryptodome：该环境里 cryptography 的 _cffi_backend
# 常缺失、CI runner 也未必可靠；纯 Python 与项目内自带 SHA-256 的做法一致。
_AES_SBOX = bytes([
  0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
  0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
  0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
  0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
  0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
  0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
  0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
  0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
  0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
  0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
  0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
  0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
  0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
  0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
  0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
  0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16,
])


def _aes_xtime(x):
    return ((x << 1) ^ (0x1b if x & 0x80 else 0)) & 0xff


def _aes_key_expansion(key):
    rk = bytearray(key)              # 32 -> 240 字节
    rcon = 1
    i = 32
    while i < 240:
        t = list(rk[i - 4:i])
        if i % 32 == 0:
            t = [_AES_SBOX[t[1]] ^ rcon, _AES_SBOX[t[2]], _AES_SBOX[t[3]], _AES_SBOX[t[0]]]
            rcon = _aes_xtime(rcon)
        elif i % 32 == 16:
            t = [_AES_SBOX[b] for b in t]
        for k in range(4):
            rk.append(rk[i - 32 + k] ^ t[k])
        i += 4
    return bytes(rk)


def _aes_encrypt_block(key, blk):
    rk = _aes_key_expansion(key)
    s = bytearray(blk)              # 列主序：(行 r, 列 c) = s[r + 4c]
    for k in range(16):
        s[k] ^= rk[k]
    x = _aes_xtime
    for rnd in range(1, 15):
        for k in range(16):
            s[k] = _AES_SBOX[s[k]]
        s[1], s[5], s[9], s[13] = s[5], s[9], s[13], s[1]
        s[2], s[6], s[10], s[14] = s[10], s[14], s[2], s[6]
        s[3], s[7], s[11], s[15] = s[15], s[3], s[7], s[11]
        if rnd != 14:
            for c in range(4):
                o = 4 * c
                a0, a1, a2, a3 = s[o], s[o + 1], s[o + 2], s[o + 3]
                s[o]     = x(a0) ^ (x(a1) ^ a1) ^ a2 ^ a3
                s[o + 1] = a0 ^ x(a1) ^ (x(a2) ^ a2) ^ a3
                s[o + 2] = a0 ^ a1 ^ x(a2) ^ (x(a3) ^ a3)
                s[o + 3] = (x(a0) ^ a0) ^ a1 ^ a2 ^ x(a3)
        for k in range(16):
            s[k] ^= rk[16 * rnd + k]
    return bytes(s)


def _xor_ctr(key, nonce, data):
    # AES-256-CTR：块 j 的密钥流 = AES(key, nonce(8) || u64_be(j))，逐 16 字节异或。
    # 与设备端 luaenc.c 的 keystream_block 完全一致。
    out = bytearray(len(data))
    ks = b""
    for i in range(len(data)):
        if i % 16 == 0:
            ctr = nonce + (i // 16).to_bytes(8, "big")
            ks = _aes_encrypt_block(key, ctr)
        out[i] = data[i] ^ ks[i % 16]
    return bytes(out)


def is_encrypted(data, key=None):
    # 判据 = tag 校验。没有 key 无法判定（对外即"看不出"），此时保守返回 False
    if key is None or len(data) < HEADER_LEN:
        return False
    return _tag(key, data[:NONCE_LEN]) == data[NONCE_LEN:HEADER_LEN]


def encrypt(data, key, nonce=None):
    if is_encrypted(data, key):     # 幂等：已加密的原样返回
        return data
    if nonce is None:
        nonce = os.urandom(NONCE_LEN)
    return nonce + _tag(key, nonce) + _xor_ctr(key, nonce, data)


def decrypt(data, key):
    if not is_encrypted(data, key):
        return data
    nonce = data[:NONCE_LEN]
    return _xor_ctr(key, nonce, data[HEADER_LEN:])


def run_lua_helper(lua_exe, script, *args):
    """从 stdin 运行辅助脚本，arg[1..] 仅作参数，绝不作为主脚本执行。

    -E 禁止 LUA_INIT/LUA_PATH 等宿主环境变量影响构建。
    """
    return subprocess.run(
        [str(lua_exe), "-E", "-", *(str(arg) for arg in args)],
        input=script, capture_output=True, text=True)


def strip_compile(lua_exe, src, dst):
    """用与设备同源码编译的 host lua 把 .lua 编译成 strip 调试信息的字节码
    (等价 luac -s)，供 enc-apk 在加密前调用。失败抛 SystemExit。"""
    # string.dump(f, true) 第二参数 true = strip；写出的字节码仍带 5.4 头，
    # 设备端 luaL_loadbufferx 解密后直接 undump（定制 VM 同源码，两端一致）
    # 辅助脚本从 stdin 读取，路径作为 arg[1..] 传入，避免 -e 的主脚本语义；
    # run_lua_helper 的 -E 同时隔离宿主 Lua 初始化环境。
    script = (
        "local f=assert(loadfile(arg[1]))\n"
        "local s=string.dump(f,true)\n"
        "local h=assert(io.open(arg[2],'wb'))\n"
        "assert(h:write(s))\nassert(h:close())"
    )
    r = run_lua_helper(lua_exe, script, src, dst)
    if r.returncode != 0:
        raise SystemExit(
            f"::error::strip 编译失败 {src}: {r.stderr.strip()}")


def enc_apk(src, dst, key, lua_exe=None):
    """把 APK 内每个 *.lua 条目替换成密文，其余条目原样复制。
    传 lua_exe 时先 strip 编译成字节码再加密（阶段 A）；否则直接加密文本。
    返回改写条数。

    安全护栏：若 APK 已带 v2/v3 签名块（"APK Sig Block 42"），改写会破坏签名，
    直接拒绝。所以本步必须在签名之前跑（CI 里就是签名前）。"""
    if b"APK Sig Block 42" in pathlib.Path(src).read_bytes():
        raise SystemExit(f"::error::{src} 已签名，加密会破坏签名——请在签名前加密")
    n = 0
    with zipfile.ZipFile(src, "r") as zin, \
         zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename.endswith(".lua") and not is_encrypted(data, key):
                if lua_exe:
                    with tempfile.TemporaryDirectory() as td:
                        # 以 APK 内条目为输入：先落盘再编译，避免路径/编码问题
                        srcp = pathlib.Path(td) / "in.lua"
                        srcp.write_bytes(data)
                        tmp = pathlib.Path(td) / "out.luac"
                        strip_compile(lua_exe, srcp, tmp)
                        data = tmp.read_bytes()
                data = encrypt(data, key)
                n += 1
            # 保留原压缩方式：STORED 的（如已对齐的 so）不要改成 DEFLATED
            zi = zipfile.ZipInfo(item.filename, date_time=item.date_time)
            zi.compress_type = item.compress_type
            zi.external_attr = item.external_attr
            zout.writestr(zi, data)
    return n


def verify_apk(apk, key, lua_exe=None):
    """检查每个 *.lua 的密文头、排除重复加密。

    传 lua_exe 时还经 C 解密入口加载并解析每个脚本，不执行脚本。
    格式及解析检查不等于载荷完整性认证，也不验证运行时依赖。
    """
    total = 0
    with zipfile.ZipFile(apk, "r") as z:
        for name in z.namelist():
            if not name.endswith(".lua"):
                continue
            total += 1
            data = z.read(name)
            if not is_encrypted(data, key):
                raise SystemExit(f"::error::{name} 在 APK 里仍是明文（未加密）")
            # 解回来的明文不应再通过 tag 校验（即确实是原始脚本，非重复加密）
            pt = decrypt(data, key)
            if is_encrypted(pt, key):
                raise SystemExit(f"::error::{name} 解密后仍像密文（重复加密？）")
            if lua_exe:
                with tempfile.TemporaryDirectory() as td:
                    encrypted = pathlib.Path(td) / "chunk.lua"
                    encrypted.write_bytes(data)
                    r = run_lua_helper(lua_exe,
                                       "assert(loadfile(arg[1]))", encrypted)
                if r.returncode != 0:
                    raise SystemExit(
                        f"::error::{name} 无法由设备同源 Lua 解密并解析: "
                        f"{r.stderr.strip()}")
    if total == 0:
        raise SystemExit("::error::APK 里一个 .lua 都没有，加密步骤可能没生效")
    detail = "且由设备同源 Lua 解密并解析通过" if lua_exe else "（未验证 Lua 内容）"
    print(f"校验通过：APK 内 {total} 个 .lua 密文格式有效{detail}")


def selftest(key):
    import random
    random.seed(0)
    ok = True
    for size in (0, 1, 31, 32, 33, 100, 4096, 100000):
        pt = bytes(random.getrandbits(8) for _ in range(size))
        ct = encrypt(pt, key)
        assert is_encrypted(ct, key), "tag 校验失败"
        assert decrypt(ct, key) == pt, f"round-trip 失败 size={size}"
        # 幂等
        assert encrypt(ct, key) == ct, "重复加密不幂等"
    print(f"selftest OK（密钥 {key.hex()[:16]}…，8 组尺寸全部 round-trip 通过）")
    return ok


def main(argv):
    key = load_key()
    if len(argv) < 2:
        print(__doc__); return 1
    cmd = argv[1]
    if cmd == "selftest":
        selftest(key); return 0
    if cmd == "enc-file":
        data = pathlib.Path(argv[2]).read_bytes()
        pathlib.Path(argv[3]).write_bytes(encrypt(data, key))
        print(f"加密 {argv[2]} -> {argv[3]}"); return 0
    if cmd in ("enc-apk", "verify-apk"):
        lua_exe = None
        rest = argv[2:]
        if "--lua" in rest:
            i = rest.index("--lua")
            if i + 1 >= len(rest):
                raise SystemExit("--lua 需要参数（host lua 可执行文件路径）")
            lua_exe = rest[i + 1]
            rest = rest[:i] + rest[i + 2:]
        if cmd == "verify-apk":
            if len(rest) != 1:
                raise SystemExit("用法：pack.py verify-apk <apk> [--lua <host-lua>]")
            verify_apk(rest[0], key, lua_exe)
            return 0
        if len(rest) != 2:
            raise SystemExit("用法：pack.py enc-apk <in.apk> <out> [--lua <host-lua>]")
        n = enc_apk(rest[0], rest[1], key, lua_exe)
        mode = "strip 编译后加密" if lua_exe else "直接加密"
        print(f"改写 {n} 个 .lua 条目（{mode}）：{rest[0]} -> {rest[1]}")
        return 0
    print(__doc__); return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
