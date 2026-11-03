#!/usr/bin/env python3
"""把 UmiBootLog 装进构建树：只改工作树 + umi.dsc 的 [Components]，不进 FDF。"""
import shutil
import sys
from pathlib import Path

D = Path("/home/unixnu/code/uefi-umi-b")
SRC = Path("/mnt/e/Code/HackIos/patches/umi-bootlog")
APP = D / "Platforms/Xiaomi/umiPkg/Application/UmiBootLog"
INF_LINE = "umiPkg/Application/UmiBootLog/UmiBootLog.inf"

if not APP.parent.is_dir():
    sys.exit(f"找不到 Application 目录 {APP.parent}")

APP.mkdir(exist_ok=True)
for name in ("UmiBootLog.c", "UmiBootLog.inf"):
    shutil.copyfile(SRC / name, APP / name)
    print(f"  复制 {name} -> {APP / name}")

dsc = D / "Platforms/Xiaomi/umiPkg/umi.dsc"
text = dsc.read_text(encoding="utf-8")
if INF_LINE in text:
    print("  umi.dsc 已含 UmiBootLog")
else:
    # prepare 追加的 [Components] 是文件末尾段落，继续追加即属于同一段。
    if text.endswith("\n"):
        dsc.write_text(text + f"  {INF_LINE}\n", encoding="utf-8")
    else:
        dsc.write_text(text + f"\n  {INF_LINE}\n", encoding="utf-8")
    print("  umi.dsc 追加 UmiBootLog 组件")

for f in ("UmiBootLog.c", "UmiBootLog.inf"):
    print(f"  {f:16s} {(APP / f).stat().st_size:>7} B")
