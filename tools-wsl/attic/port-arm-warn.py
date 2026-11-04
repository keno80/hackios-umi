#!/usr/bin/env python3
"""回移上游 main 的 -Wno-unnecessary-virtual-specifier 到 pin 树的 ARM 驱动构建脚本。"""
import shutil
from pathlib import Path

TOKEN_OLD = '"-Wno-reorder-init-list", "-Wno-deprecated-enum-enum-conversion",'
TOKEN_NEW = ('"-Wno-reorder-init-list", "-Wno-deprecated-enum-enum-conversion",\n'
             '    "-Wno-unnecessary-virtual-specifier",')
TARGETS = [
    Path("/home/unixnu/code/UniXNU-umi/scripts/build-umi-arm-driver.py"),
    Path("/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/scripts/build-umi-arm-driver.py"),
]
for path in TARGETS:
    if not path.exists():
        print(f"跳过（不存在）：{path}")
        continue
    real = path.resolve()
    text = real.read_text()
    if TOKEN_NEW.split("\n")[-1].strip() in text:
        print(f"已含该抑制：{real}")
        continue
    if text.count(TOKEN_OLD) != 1:
        raise SystemExit(f"锚点不唯一（{text.count(TOKEN_OLD)} 处）：{real}")
    backup = real.with_name(real.name + ".macos-original")
    if not backup.exists():
        shutil.copyfile(real, backup)
    real.write_text(text.replace(TOKEN_OLD, TOKEN_NEW))
    import ast
    ast.parse(real.read_text())
    print(f"OK 已插入并语法自检：{real}")
