#!/usr/bin/env python3
"""路A 本地补丁 5：bootstrap 步同时归零 XNU_VERIFIED_ROOT_PROBE。

build_umi_xnu.py 的 bootstrap 趟把 XNU_SOURCE_CORECRYPTO14 等强制置 0（那一趟只为出编译记录和符号表），
但 --native-ufs 会把 XNU_VERIFIED_ROOT_PROBE 留成 1；baseline 脚本第 257 行的闸门要求
「probe=1 必须 CORECRYPTO14=1 且 crypto=prelinked」，于是 bootstrap 趟 100% 退出。
四个副本（UniXNU-umi/bringup/tools、umi-work{,-pin}/tools、devices/umi/bringup/tools）都是同一份上游代码。
libraries/kernel 趟仍按完整 settings 走，probe 照样生效。
"""
import argparse
import pathlib
import sys

OLD = """        run("bootstrap", build, {k: "0" for k in (
            "XNU_SOURCE_CORECRYPTO14", "XNU_SOURCE_PTHREAD", "XNU_ARM_DT_PLATFORM",
            "XNU_ARMCPU", "XNU_NATIVE_ARCH_TIMER", "XNU_BOOT_PROGRESS")})"""
NEW = """        run("bootstrap", build, {k: "0" for k in (
            "XNU_SOURCE_CORECRYPTO14", "XNU_SOURCE_PTHREAD", "XNU_ARM_DT_PLATFORM",
            "XNU_ARMCPU", "XNU_NATIVE_ARCH_TIMER", "XNU_BOOT_PROGRESS",
            "XNU_VERIFIED_ROOT_PROBE")})"""

MARK = "XNU_VERIFIED_ROOT_PROBE\")})"


def patch(path):
    text = path.read_text()
    if MARK in text:
        print(f"already: {path}")
        return 0
    if OLD not in text:
        print(f"SKIP（找不到目标块，需人工核对）: {path}")
        return 1
    path.write_text(text.replace(OLD, NEW, 1))
    print(f"patched: {path}")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("targets", nargs="*",
                    default=["/home/unixnu/code/umi-work-pin/tools/build_umi_xnu.py"])
    args = ap.parse_args()
    rc = 0
    for t in args.targets:
        p = pathlib.Path(t)
        if p.exists():
            rc |= patch(p)
    return rc


if __name__ == "__main__":
    sys.exit(main())
