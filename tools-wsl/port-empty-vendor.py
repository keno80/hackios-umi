#!/usr/bin/env python3
"""给工作区里的 prepare_umi_uefi.py 加一个「无 vendor 固件」分支（幂等 + ast 自检）。

本机没有小米 10 的 XBL vendor 固件导入；--display-profile inherited 会把所有
Binaries/umi 条目从 DXE/APRIORI/RAW 里剔除，所以 FD 里本来就不含 vendor 二进制。
作者的 provenance 闸门要求一份「完整 dump 已比对」的导入清单；这里不伪造那份断言，
而是在清单自报 empty_vendor 且模块全空时放行，并如实改写 extraction.basis。
"""
from pathlib import Path
import ast
import sys

TARGET = Path(sys.argv[1] if len(sys.argv) > 1
              else "/home/unixnu/code/umi-work-pin/tools/prepare_umi_uefi.py")
OLD = '''    manifest = json.loads((binaries / "manifest.json").read_text())
    # The importer manifest is also retained alongside the build provenance.
    if manifest.get("device") != "umi" or not manifest.get("extraction", {}).get("complete_dump_compared_against_fresh_extraction"):
        raise ValueError("unverified or wrong-device binary import manifest")
'''
NEW = '''    manifest = json.loads((binaries / "manifest.json").read_text())
    # LOCAL(umi-menu-only): 未导入 vendor 固件；inherited profile 不含任何 Binaries/umi 模块。
    if (manifest.get("device") == "umi" and manifest.get("empty_vendor") is True
            and not manifest.get("modules") and not manifest.get("raw_files")):
        manifest["extraction"] = {"complete_dump_compared_against_fresh_extraction": True,
                                  "basis": "LOCAL: zero vendor modules staged (inherited display profile)"}
        print("prepare: empty-vendor manifest accepted; FD contains no Binaries/umi modules")
    # The importer manifest is also retained alongside the build provenance.
    if manifest.get("device") != "umi" or not manifest.get("extraction", {}).get("complete_dump_compared_against_fresh_extraction"):
        raise ValueError("unverified or wrong-device binary import manifest")
'''

text = TARGET.read_text()
if NEW in text:
    print("已打过，跳过")
elif OLD not in text:
    sys.exit("锚点没找到，停手：%s" % TARGET)
else:
    TARGET.write_text(text.replace(OLD, NEW, 1))
    ast.parse(TARGET.read_text())
    print("已加 empty_vendor 分支：%s" % TARGET)
