#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""luaenc 出场密钥的混淆拆分生成器（唯一真源仍在 luaenc.c）。

32 字节密钥不以完整形态出现在 .so 里，而是拆成 6 张表，运行时用
「置换 + 异或掩码 + 加法掩码 + 逐字节位旋转 + 链式白化」重组：

    阶段一（按置换收集，每字节混入 4 种运算）：
        j    = P[i]
        s[i] = rotl8( ((A[j] ^ B[j]) + C[j]) & 0xff , R[j] & 7 )

    阶段二（CBC 式链式白化，令每个输出字节耦合前一个，破坏「两表异或即得」）：
        prev = IV(0xA5)
        key[i] = s[i] ^ W[i] ^ prev ;  prev = key[i]

设备端 luaenc.c 的 luaEnc_getKey 与打包端 pack.py 的 load_key 都实现这份
「正向」重组逻辑（两处手写、互为镜像）；本生成器实现其「逆向」，据目标
密钥反解出 A 表（B/C/R/P/W 随机取），保证 reconstruct(生成表) == 目标密钥。

用法：
    gen_key.py                # 保持现有密钥值不变，仅换一套混淆拆分（随机种子）
    gen_key.py --seed N       # 固定种子，可复现
    gen_key.py --check        # 只校验 luaenc.c 现有表能重组出密钥，不改文件

注意：换密钥 / 换拆分后必须重编 libluajava.so 并重新出包，旧包不兼容。
本脚本绝不打印密钥明文。
"""
import argparse
import pathlib
import random
import re
import sys

_HERE = pathlib.Path(__file__).resolve().parent
_LUAENC_C = _HERE.parent.parent / "androlua/src/main/jni/lua/luaenc.c"

IV = 0xA5
_TABLES = ("A", "B", "C", "R", "P", "W")


def rotl8(x, n):
    n &= 7
    return ((x << n) | (x >> ((8 - n) & 7))) & 0xFF


def rotr8(x, n):
    n &= 7
    return ((x >> n) | (x << ((8 - n) & 7))) & 0xFF


def reconstruct(t):
    """正向重组：与 luaenc.c 的 luaEnc_getKey、pack.py 的 load_key 完全一致。"""
    A, B, C, R, P, W = (t[k] for k in _TABLES)
    s = [0] * 32
    for i in range(32):
        j = P[i]
        v = (A[j] ^ B[j])
        v = (v + C[j]) & 0xFF
        s[i] = rotl8(v, R[j] & 7)
    key = bytearray(32)
    prev = IV
    for i in range(32):
        v = s[i] ^ W[i] ^ prev
        key[i] = v
        prev = v
    return bytes(key)


def _grab(txt, name, count=32):
    m = re.search(r"LUAENC_KEY_%s\[\s*32\s*\]\s*=\s*\{(.*?)\};" % name, txt, re.S)
    if not m:
        return None
    nums = re.findall(r"0x([0-9a-fA-F]{2})", m.group(1))
    if len(nums) != count:
        raise SystemExit(f"LUAENC_KEY_{name} 应为 {count} 字节，实际 {len(nums)} 个")
    return [int(x, 16) for x in nums]


def parse_tables(txt):
    """读出当前 luaenc.c 里的密钥表；兼容新（6 表）与旧（SEGS/MASK/MAP）两种格式。"""
    new = {k: _grab(txt, k) for k in _TABLES}
    if all(v is not None for v in new.values()):
        if sorted(new["P"]) != list(range(32)):
            raise SystemExit("LUAENC_KEY_P 不是 0..31 的置换")
        return "new", new
    segs, mask, mp = _grab(txt, "SEGS"), _grab(txt, "MASK"), _grab(txt, "MAP")
    if segs and mask and mp:
        if sorted(mp) != list(range(32)):
            raise SystemExit("LUAENC_KEY_MAP 不是 0..31 的置换")
        return "old", {"SEGS": segs, "MASK": mask, "MAP": mp}
    raise SystemExit("在 luaenc.c 里找不到密钥表（新 A/B/C/R/P/W 或旧 SEGS/MASK/MAP）")


def recover_key(txt):
    """从当前 luaenc.c 重组出密钥（仅内存，绝不打印）。"""
    fmt, t = parse_tables(txt)
    if fmt == "new":
        return reconstruct(t)
    return bytes(t["SEGS"][i] ^ t["MASK"][i] for i in t["MAP"])  # 旧方案


def generate(key, seed):
    """据目标密钥反解出一套新混淆表（B/C/R/P/W 随机，A 反推）。"""
    rnd = random.Random(seed)
    B = [rnd.randrange(256) for _ in range(32)]
    C = [rnd.randrange(256) for _ in range(32)]
    R = [rnd.randrange(8) for _ in range(32)]
    W = [rnd.randrange(256) for _ in range(32)]
    P = list(range(32))
    rnd.shuffle(P)
    # 逆阶段二：由 key 反推 s
    s = [0] * 32
    prev = IV
    for i in range(32):
        s[i] = key[i] ^ W[i] ^ prev
        prev = key[i]
    # 逆阶段一：由 s 反推 A
    A = [0] * 32
    for i in range(32):
        j = P[i]
        u = rotr8(s[i], R[j] & 7)
        u = (u - C[j]) & 0xFF
        u = u ^ B[j]
        A[j] = u
    t = {"A": A, "B": B, "C": C, "R": R, "P": P, "W": W}
    if reconstruct(t) != key:
        raise SystemExit("内部错误：生成表无法重组回目标密钥")
    return t


def _fmt_table(name, vals):
    lines = [f"static const unsigned char LUAENC_KEY_{name}[32] = {{"]
    for r in range(0, 32, 8):
        row = ", ".join("0x%02x" % v for v in vals[r:r + 8])
        lines.append(f"  {row},")
    lines[-1] = lines[-1].rstrip(",")  # 末行去掉尾逗号
    lines.append("};")
    return "\n".join(lines)


def emit_block(t):
    """生成 BEGIN/END 之间的整段（含 6 表），顺序固定 A,B,C,R,P,W。"""
    body = "\n".join(_fmt_table(k, t[k]) for k in _TABLES)
    return "/* LUAENC_KEY_BEGIN */\n" + body + "\n/* LUAENC_KEY_END */"


def rewrite(path, t):
    txt = pathlib.Path(path).read_text(encoding="utf-8")
    new_block = emit_block(t)
    txt2, n = re.subn(
        r"/\* LUAENC_KEY_BEGIN \*/.*?/\* LUAENC_KEY_END \*/",
        lambda _m: new_block, txt, count=1, flags=re.S)
    if n != 1:
        raise SystemExit("找不到 LUAENC_KEY_BEGIN/END 标记，未改动")
    pathlib.Path(path).write_text(txt2, encoding="utf-8")


def main(argv):
    ap = argparse.ArgumentParser(description="luaenc 出场密钥混淆拆分生成器")
    ap.add_argument("--seed", type=int, default=None,
                    help="随机种子（省略则用系统随机；打印所用种子以便复现）")
    ap.add_argument("--check", action="store_true",
                    help="只校验现有表能重组出密钥，不写文件")
    ap.add_argument("--file", default=str(_LUAENC_C), help="luaenc.c 路径")
    args = ap.parse_args(argv)

    txt = pathlib.Path(args.file).read_text(encoding="utf-8")
    key = recover_key(txt)  # 仅内存

    if args.check:
        fmt, _ = parse_tables(txt)
        print(f"OK：{args.file} 现有密钥表（{fmt} 格式）可正常重组（{len(key)} 字节）")
        return 0

    seed = args.seed if args.seed is not None else random.randrange(1 << 63)
    t = generate(key, seed)
    rewrite(args.file, t)
    # 复核：重写后的文件用「正向」逻辑重组，必须仍等于原密钥
    key2 = recover_key(pathlib.Path(args.file).read_text(encoding="utf-8"))
    if key2 != key:
        raise SystemExit("重写后重组结果与原密钥不一致——已破坏，请回滚")
    print(f"已写入新的混淆拆分（6 表，seed={seed}）；密钥值不变。"
          f"\n务必重编 libluajava.so 并重新出包。")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
