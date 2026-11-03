#!/usr/bin/env python3
"""Decouple XNU_SOURCE_MOCKFS from --data-ramdisk so the fixture root can be
linked on a Linux host that cannot produce a packed APFS Data seed."""
import subprocess
import sys

TARGETS = [
    "/home/unixnu/code/UniXNU-umi/bringup/tools/build_umi_xnu.py",
    "/home/unixnu/code/umi-work-pin/tools/build_umi_xnu.py",
]

ARG_ANCHOR = '    parser.add_argument("--legacy-display", action="store_true",'
ARG_NEW = ('    parser.add_argument("--mockfs-root", action="store_true",\n'
           '                        help="link the XNU mockfs fixture root without a packed APFS Data seed")\n'
           + ARG_ANCHOR)

BIND_OLD = '    settings["XNU_SOURCE_MOCKFS"] = str(int(bool(data_input)))'
BIND_NEW = '    settings["XNU_SOURCE_MOCKFS"] = str(int(bool(data_input) or args.mockfs_root))'

RUN_OLD = '        if data_input:\n            run("original-mockfs", [sys.executable, "scripts/build-mockfs-fixture.py"])'
RUN_NEW = '        if data_input or args.mockfs_root:\n            run("original-mockfs", [sys.executable, "scripts/build-mockfs-fixture.py"])'

for path in TARGETS:
    text = open(path, encoding="utf-8").read()
    if "mockfs_root" in text:
        print(f"{path}: already patched")
        continue
    for anchor, new in ((ARG_ANCHOR, ARG_NEW), (BIND_OLD, BIND_NEW), (RUN_OLD, RUN_NEW)):
        if text.count(anchor) != 1:
            sys.exit(f"{path}: anchor not unique ({text.count(anchor)}): {anchor[:60]}")
        text = text.replace(anchor, new)
    open(path, "w", encoding="utf-8", newline="\n").write(text)
    subprocess.run([sys.executable, "-m", "py_compile", path], check=True)
    print(f"{path}: patched and compiles")
