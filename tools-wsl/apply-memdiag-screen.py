#!/usr/bin/env python3
"""把上屏补丁打进构建树里的 UmiMemoryDiag（只改工作树，不动上游 overlay）。"""
import shutil, sys
from pathlib import Path

D = Path("/home/unixnu/code/uefi-umi-b")
APP = D / "Platforms/Xiaomi/umiPkg/Application/UmiMemoryDiag"
SRC = Path("/mnt/e/Code/HackIos/patches/umi-memdiag")

if not APP.is_dir():
    sys.exit(f"找不到模块目录 {APP}")

for name in ("MemOut.h", "UmiMemoryDiag.c"):
    shutil.copyfile(SRC / name, APP / name)
    print(f"  复制 {name} -> {APP / name}")

# RamProbe.c 也走同一个 DEBUG 覆写
rp = APP / "RamProbe.c"
text = rp.read_text(encoding="utf-8")
if '"MemOut.h"' not in text:
    text = text.replace('#include "SmemRead.h"', '#include "SmemRead.h"\n#include "MemOut.h"', 1)
    rp.write_text(text, encoding="utf-8")
    print("  RamProbe.c 已插入 MemOut.h")
else:
    print("  RamProbe.c 已含 MemOut.h")

# INF：Sources 加 MemOut.h，LibraryClasses 加 PrintLib
inf = APP / "UmiMemoryDiag.inf"
lines = inf.read_text(encoding="utf-8").splitlines(keepends=True)
out, section = [], None
have_hdr = any("MemOut.h" in l for l in lines)
have_print = any(l.strip() == "PrintLib" for l in lines)
for l in lines:
    s = l.strip()
    if s.startswith("[") and s.endswith("]"):
        section = s
        out.append(l)
        if section == "[Sources]" and not have_hdr:
            out.append("  MemOut.h\n")
        elif section == "[LibraryClasses]" and not have_print:
            out.append("  PrintLib\n")
        continue
    out.append(l)
inf.write_text("".join(out), encoding="utf-8")
print(f"  INF：Sources+MemOut.h={not have_hdr} LibraryClasses+PrintLib={not have_print}")

for f in ("MemOut.h", "UmiMemoryDiag.c", "RamProbe.c", "UmiMemoryDiag.inf"):
    p = APP / f
    print(f"  {p.name:22s} {p.stat().st_size:>7} B")
