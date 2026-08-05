#!/usr/bin/env python3
"""
定制 VM opcode 表生成器(唯一入口,保证 4 个文件顺序一致)。

重排策略:
  - 以官方 Lua 5.4.8 opcode 顺序为固定基准(CANONICAL),用固定种子洗牌
    82 个 opcode(OP_EXTRAARG 保持枚举末位,以维持 NUM_OPCODES 定义),
    每次运行结果确定、可复现。
  - 位域盐(B/C 字段交换)在 lopcodes.h 中以宏形式手动维护(见 POS_B/POS_C),
    本脚本只负责重排枚举与三个按枚举顺序排列的附表。

用法:
  python3 native/luaenc/gen_opcodes.py [--seed N]
  默认种子 20260805。改种子 = 换一套 opcode 映射(与旧字节码不兼容,
  须同版本发布 so 与脚本)。

一致性断言:重排后 4 个文件的名字集合必须与 CANONICAL 完全一致,否则退出 1。
"""
import argparse
import pathlib
import random
import re
import sys

JNI = pathlib.Path(__file__).resolve().parent.parent.parent / "androlua/src/main/jni/lua"

# 官方 Lua 5.4.8 的 83 个 opcode 顺序(权威基准,勿改)
CANONICAL = [
    "MOVE", "LOADI", "LOADF", "LOADK", "LOADKX", "LOADFALSE", "LFALSESKIP",
    "LOADTRUE", "LOADNIL", "GETUPVAL", "SETUPVAL", "GETTABUP", "GETTABLE",
    "GETI", "GETFIELD", "SETTABUP", "SETTABLE", "SETI", "SETFIELD",
    "NEWTABLE", "SELF", "ADDI", "ADDK", "SUBK", "MULK", "MODK", "POWK",
    "DIVK", "IDIVK", "BANDK", "BORK", "BXORK", "SHRI", "SHLI", "ADD", "SUB",
    "MUL", "MOD", "POW", "DIV", "IDIV", "BAND", "BOR", "BXOR", "SHL", "SHR",
    "MMBIN", "MMBINI", "MMBINK", "UNM", "BNOT", "NOT", "LEN", "CONCAT",
    "CLOSE", "TBC", "JMP", "EQ", "LT", "LE", "EQK", "EQI", "LTI", "LEI",
    "GTI", "GEI", "TEST", "TESTSET", "CALL", "TAILCALL", "RETURN", "RETURN0",
    "RETURN1", "FORLOOP", "FORPREP", "TFORPREP", "TFORCALL", "TFORLOOP",
    "SETLIST", "CLOSURE", "VARARG", "VARARGPREP", "EXTRAARG",
]
assert len(CANONICAL) == 83 and CANONICAL[-1] == "EXTRAARG"

# 语义推导组:lcode.c 的 binopr2op/unopr2op 用「枚举差值」推导 opcode
# (opr - baser + base),依赖以下各组的官方相对顺序与连续性,重排时
# 必须整组原子移动、组内顺序不可变:
#   binopr2op(opr, OPR_ADD, OP_ADD)   -> ADD..SHR
#   binopr2op(opr, OPR_ADD, OP_ADDK)  -> ADDK..BXORK
#   binopr2op(opr, OPR_LT,  OP_LT)    -> LT, LE
#   binopr2op(opr, OPR_LT,  OP_LTI)   -> LTI, LEI
#   binopr2op(opr, OPR_LT,  OP_GTI)   -> GTI, GEI
#   unopr2op(opr)                     -> UNM, BNOT, NOT, LEN
ATOMIC_GROUPS = [
    ["ADDK", "SUBK", "MULK", "MODK", "POWK", "DIVK", "IDIVK",
     "BANDK", "BORK", "BXORK"],
    ["ADD", "SUB", "MUL", "MOD", "POW", "DIV", "IDIV",
     "BAND", "BOR", "BXOR", "SHL", "SHR"],
    ["UNM", "BNOT", "NOT", "LEN"],
    ["LT", "LE"],
    ["LTI", "LEI"],
    ["GTI", "GEI"],
]
_GROUP_MEMBERS = {n for g in ATOMIC_GROUPS for n in g}
assert len(_GROUP_MEMBERS) == 32, "原子组共 32 个 opcode"
# 组间可交换、组内保持官方顺序


def rewrite(path, text):
    (JNI / path).write_text(text, encoding="utf-8")
    print(f"  rewrote {path}")


def parse_enum():
    """lopcodes.h 枚举块 -> {名字: 完整条目文本(含跨行注释)}"""
    txt = (JNI / "lopcodes.h").read_text(encoding="utf-8")
    en = re.search(r"typedef enum \{.*?\} OpCode;", txt, re.S)
    assert en, "lopcodes.h 找不到枚举块"
    out = {}
    lines = en.group(0).splitlines()
    i = 0
    while i < len(lines):
        m = re.match(r"^\s*(OP_[A-Z0-9_]+),?", lines[i])
        if m:
            j = i
            if "/*" in lines[i] and "*/" not in lines[i]:
                while j + 1 < len(lines) and "*/" not in lines[j]:
                    j += 1
            out[m.group(1)[3:]] = "\n".join(
                ln.strip() for ln in lines[i : j + 1])
            i = j + 1
        else:
            i += 1
    assert set(out) == set(CANONICAL), "lopcodes.h 枚举与官方顺序不一致"
    return txt, en, out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=20260805)
    args = ap.parse_args()

    order = CANONICAL[:-1]
    rng = random.Random(args.seed)
    # 原子组整体参与洗牌,组内保持官方顺序(见 ATOMIC_GROUPS 注释);
    # 其余 opcode 单例洗牌。
    units = []
    for g in ATOMIC_GROUPS:
        units.append(list(g))
    for name in order:
        if name not in _GROUP_MEMBERS:
            units.append([name])
    rng.shuffle(units)
    order = [n for u in units for n in u]
    order = order + ["EXTRAARG"]
    # 断言:原子组内部相对顺序未被破坏
    for g in ATOMIC_GROUPS:
        pos = [order.index(n) for n in g]
        assert pos == sorted(pos), f"原子组 {g} 顺序被破坏"

    # ---- lopcodes.h:仅替换 typedef enum 块 ----
    txt, en, enum_lines = parse_enum()
    body = "\n".join(enum_lines[n] for n in order)
    txt = txt[: en.start()] + "typedef enum {\n" + body + "\n} OpCode;" + txt[en.end():]
    rewrite("lopcodes.h", txt)

    # ---- ljumptab.h:disptab 按新顺序 ----
    txt = (JNI / "ljumptab.h").read_text(encoding="utf-8")
    tab = re.search(r"static const void \*const disptab\[NUM_OPCODES\] = \{.*?\};", txt, re.S)
    assert tab, "ljumptab.h 找不到 disptab"
    entries = {m.group(1): m.group(0).rstrip(",").strip()
               for m in re.finditer(r"^\s*&&L_OP_([A-Z0-9_]+),?\s*$", tab.group(0), re.M)}
    assert set(entries) == set(CANONICAL), "ljumptab.h 条目与官方顺序不一致"
    body = ",\n".join(entries[n] for n in order)
    txt = txt[: tab.start()] + "static const void *const disptab[NUM_OPCODES] = {\n" + body + "\n};" + txt[tab.end():]
    rewrite("ljumptab.h", txt)

    # ---- lopnames.h ----
    txt = (JNI / "lopnames.h").read_text(encoding="utf-8")
    arr = re.search(r"static const char \*const opnames\[\] = \{.*?NULL\s*\};", txt, re.S)
    assert arr, "lopnames.h 找不到 opnames"
    entries = {m.group(1): m.group(0).rstrip(",")
               for m in re.finditer(r'^\s*"([A-Z0-9_]+)",\s*$', arr.group(0), re.M)}
    entries["NULL"] = "NULL"
    assert set(entries) - {"NULL"} == set(CANONICAL), "lopnames.h 条目与官方顺序不一致"
    body = ",\n".join(entries[n] for n in order) + ",\n  NULL"
    txt = txt[: arr.start()] + "static const char *const opnames[] = {\n" + body + "\n};" + txt[arr.end():]
    rewrite("lopnames.h", txt)

    # ---- lopcodes.c(条目行首允许前导逗号)----
    txt = (JNI / "lopcodes.c").read_text(encoding="utf-8")
    arr = re.search(r"LUAI_DDEF const lu_byte luaP_opmodes\[NUM_OPCODES\] = \{.*?\};", txt, re.S)
    assert arr, "lopcodes.c 找不到 opmodes"
    entries = {}
    for m in re.finditer(r"^\s*,?\s*(opmode\([^;]*?\)\s*/\*\s*OP_([A-Z0-9_]+)\s*\*/)\s*$",
                         arr.group(0), re.M):
        entries[m.group(2)] = m.group(1)
    assert set(entries) == set(CANONICAL), "lopcodes.c 条目与官方顺序不一致"
    body = "\n,".join(entries[n] for n in order)
    txt = txt[: arr.start()] + "LUAI_DDEF const lu_byte luaP_opmodes[NUM_OPCODES] = {\n" + body + "\n};" + txt[arr.end():]
    rewrite("lopcodes.c", txt)

    # ---- 兜底一致性断言(按各文件格式提取名字) ----
    checks = {
        "lopcodes.h": r"OP_([A-Z0-9_]+)",
        "ljumptab.h": r"&&L_OP_([A-Z0-9_]+)",
        "lopnames.h": r'"([A-Z0-9_]+)",\s*$',
        "lopcodes.c": r"/\*\s*OP_([A-Z0-9_]+)\s*\*/",
    }
    for f, pat in checks.items():
        t = (JNI / f).read_text(encoding="utf-8")
        found = set(re.findall(pat, t, re.M)) - {"NULL"}
        if found != set(CANONICAL):
            print(f"FAIL {f}: 名字集合不一致 {sorted(found ^ set(CANONICAL))}")
            sys.exit(1)
    print(f"OK: 4 个文件已同步重排(seed={args.seed}, 83 个 opcode)")
    print("新枚举顺序:", ", ".join(order))


if __name__ == "__main__":
    main()
