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
import hashlib, os, re, struct, subprocess, sys, zipfile, pathlib, tempfile

# 无明文魔数：头 = nonce(8) + tag(8)，tag = SHA256(KEY||nonce)[:8]。
# 没有 KEY 就算不出 tag，所以文件头对外看是随机字节、grep 不到签名。
NONCE_LEN = 8
TAG_LEN = 8
HEADER_LEN = 16

_HERE = pathlib.Path(__file__).resolve().parent
_LUAENC_C = _HERE.parent.parent / "androlua/src/main/jni/lua/luaenc.c"


def load_key(path=_LUAENC_C):
    """从 luaenc.c 的 LUAENC_KEY_BEGIN/END 标记之间解析 SEGS/MASK/MAP 三张表
    重建 32 字节密钥：key[i] = SEGS[MAP[i]] ^ MASK[MAP[i]]。"""
    txt = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")

    def grab(name):
        m = re.search(
            r"LUAENC_KEY_%s\[\s*32\s*\]\s*=\s*\{(.*?)\};" % name, txt, re.S)
        if not m:
            raise SystemExit(f"在 {path} 里找不到 LUAENC_KEY_{name} 表")
        nums = re.findall(r"0x([0-9a-fA-F]{2})", m.group(1))
        if len(nums) != 32:
            raise SystemExit(f"LUAENC_KEY_{name} 应为 32 字节，实际解析出 {len(nums)} 个")
        return bytes(int(x, 16) for x in nums)

    segs, mask, mp = grab("SEGS"), grab("MASK"), grab("MAP")
    if sorted(mp) != list(range(32)):
        raise SystemExit("LUAENC_KEY_MAP 不是 0..31 的置换")
    key = bytes(segs[i] ^ mask[i] for i in mp)
    return key


def _keystream_block(key, nonce, j):
    return hashlib.sha256(key + nonce + struct.pack("<Q", j)).digest()


def _tag(key, nonce):
    # SHA256(KEY||nonce)[:8]；与密钥流输入长度不同，天然不撞
    return hashlib.sha256(key + nonce).digest()[:TAG_LEN]


def _xor_ctr(key, nonce, data):
    out = bytearray(len(data))
    ks = b""
    for i in range(len(data)):
        if i % 32 == 0:
            ks = _keystream_block(key, nonce, i // 32)
        out[i] = data[i] ^ ks[i % 32]
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
    返回改写条数。"""
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
