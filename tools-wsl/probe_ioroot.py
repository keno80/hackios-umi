#!/usr/bin/env python3
"""还原 IOFindBSDRoot 尾部 panic 的字符串，判定是缺根设备还是 boot-arg 问题。

llvm-objdump 反汇编 _IOFindBSDRoot，抓 adrp+add 得到的 __cstring 地址，
再按 Mach-O 段表把 VA 换成文件偏移读出字符串。纯只读。
"""
import re
import subprocess as sp
import sys

K = "/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho"
SYM = 0xFFFFFFF00798AE00  # _IOFindBSDRoot 起始，脚本里会重新精确取


def sh(cmd):
    return sp.run(cmd, capture_output=True, text=True, errors="replace").stdout


# 1) 段表：addr/size/offset -> 用于 VA 换文件偏移
load = sh(["otool", "-l", K])
sects = []
cur = {}
for ln in load.splitlines():
    t = ln.strip()
    if t.startswith("sectname"):
        cur = {"name": t.split(None, 1)[1]}
    elif t.startswith("addr ") and "addr" not in cur:
        cur["addr"] = int(t.split()[1], 16)
    elif t.startswith("size") and "size" not in cur:
        cur["size"] = int(t.split()[1], 16)
    elif t.startswith("offset") and "offset" not in cur:
        cur["offset"] = int(t.split()[1])
        if "addr" in cur and cur.get("size"):
            sects.append(cur)
        cur = {}


def cstr(va):
    for s in sects:
        if s["addr"] <= va < s["addr"] + s["size"]:
            with open(K, "rb") as f:
                f.seek(s["offset"] + (va - s["addr"]))
                return f.read(4096).split(b"\0")[0].decode("utf-8", "replace")
    return None


# 2) 精确符号地址
nm = sh(["xcrun", "nm", "-n", K])
base = None
for ln in nm.splitlines():
    fld = ln.split()
    if len(fld) == 3 and fld[2] == "_IOFindBSDRoot":
        base = int(fld[0], 16)
print(f"== _IOFindBSDRoot @ {base:#x}" if base else "== 没找到 _IOFindBSDRoot")
if not base:
    sys.exit(1)

# 3) 反汇编整个函数，记录 adrp 基址与 add 组合出的字符串 VA
dis = sh(["llvm-objdump", "--macho", "-d", "--disassemble-symbols=_IOFindBSDRoot", K])
pages = {}
hits = []
for ln in dis.splitlines():
    m = re.match(r"\s*([0-9a-f]+)\s+\S+\s+adrp\s+(x\d+), (0x[0-9a-f]+)", ln)
    if m:
        pages[m.group(2)] = int(m.group(3), 16)
        continue
    m = re.match(r"\s*([0-9a-f]+)\s+\S+\s+add\s+(x\d+), (x\d+), #?(0x[0-9a-f]+)", ln)
    if m and m.group(3) in pages:
        va = pages[m.group(3)] + int(m.group(4), 16)
        s = cstr(va)
        if s and len(s) > 3:
            hits.append((int(m.group(1), 16), f"{va:#x}", s))

print(f"== 函数内引用到的字符串（{len(hits)} 条，尾部 20 条最相关）")
for a, va, s in hits[-20:]:
    mark = "  <<< 断言前" if base + 0xc00 <= a <= base + 0xc90 else ""
    print(f"  {a - base:#06x} {va}  {s!r}{mark}")

print("== 尾部指令（找 panic 的 bl 目标）")
tail = [ln for ln in dis.splitlines() if re.match(r"\s*[0-9a-f]+\s", ln)][-26:]
for ln in tail:
    p = ln.split(None, 2)
    print("  " + (p[2].strip() if len(p) > 2 else ln.strip()))
