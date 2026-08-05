#!/usr/bin/env python3
"""
Lua 脚本打包加密器。与设备端 androlua/src/main/jni/lua/luaenc.c 同算法、同密钥。

密钥不在这里写死 —— 直接从 luaenc.c 的 LUAENC_KEY 数组解析，保证唯一真源、
两端永不漂移。

用法：
  pack.py selftest                 自测：随机数据 round-trip（不依赖设备）
  pack.py enc-apk <in.apk> <out>   把 APK 内所有 *.lua 条目改写成密文
  pack.py enc-file <in> <out>      加密单个文件（调试/测试用）
"""
import hashlib, os, re, struct, sys, zipfile, pathlib

# 无明文魔数：头 = nonce(8) + tag(8)，tag = SHA256(KEY||nonce)[:8]。
# 没有 KEY 就算不出 tag，所以文件头对外看是随机字节、grep 不到签名。
NONCE_LEN = 8
TAG_LEN = 8
HEADER_LEN = 16

_HERE = pathlib.Path(__file__).resolve().parent
_LUAENC_C = _HERE.parent.parent / "androlua/src/main/jni/lua/luaenc.c"


def load_key(path=_LUAENC_C):
    """从 luaenc.c 的 LUAENC_KEY_BEGIN/END 标记之间提取 32 字节密钥。"""
    txt = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")
    m = re.search(r"LUAENC_KEY_BEGIN(.*?)LUAENC_KEY_END", txt, re.S)
    if not m:
        raise SystemExit(f"在 {path} 里找不到 LUAENC_KEY 标记")
    nums = re.findall(r"0x([0-9a-fA-F]{2})", m.group(1))
    if len(nums) != 32:
        raise SystemExit(f"密钥应为 32 字节，实际解析出 {len(nums)} 个")
    return bytes(int(x, 16) for x in nums)


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


def enc_apk(src, dst, key):
    """把 APK 内每个 *.lua 条目替换成密文，其余条目原样复制。返回改写条数。"""
    n = 0
    with zipfile.ZipFile(src, "r") as zin, \
         zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename.endswith(".lua") and not is_encrypted(data, key):
                data = encrypt(data, key)
                n += 1
            # 保留原压缩方式：STORED 的（如已对齐的 so）不要改成 DEFLATED
            zi = zipfile.ZipInfo(item.filename, date_time=item.date_time)
            zi.compress_type = item.compress_type
            zi.external_attr = item.external_attr
            zout.writestr(zi, data)
    return n


def verify_apk(apk, key):
    """断言 APK 内每个 *.lua 都是密文、且能解回合法内容。失败抛异常。"""
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
    if total == 0:
        raise SystemExit("::error::APK 里一个 .lua 都没有，加密步骤可能没生效")
    print(f"校验通过：APK 内 {total} 个 .lua 全部为密文且可解密")


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
    if cmd == "enc-apk":
        n = enc_apk(argv[2], argv[3], key)
        print(f"改写 {n} 个 .lua 条目：{argv[2]} -> {argv[3]}"); return 0
    if cmd == "verify-apk":
        verify_apk(argv[2], key); return 0
    print(__doc__); return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
