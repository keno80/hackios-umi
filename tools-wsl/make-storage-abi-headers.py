#!/usr/bin/env python3
"""路A 本地支持：把 storage-abi 的公开头目录补出来。

audit_umi_storage.py 做两件事：(1) 把 Darwin 23 公开 IOStorageFamily 的 *.h 发布到
out/umi/storage-abi/include/IOKit/storage/，(2) 拿作者手上的 iPhone 参照内核跑 ABI 审计。
我们只能复现 (1)——(2) 需要的候选二进制不在我们手里。(1) 是纯机械搬运，且必须核对
source-lock 指定的 commit，否则等于用未审的捐赠头。
"""
import argparse
import hashlib
import shutil
import subprocess
import sys
from pathlib import Path

PIN = "e45fbe30a7879e0b16e26dddb78538f1b00e0bff"


def git_head(path):
    return subprocess.run(["git", "-C", str(path), "rev-parse", "HEAD"],
                          text=True, capture_output=True).stdout.strip()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", default="/home/unixnu/code/umi-work-pin")
    ap.add_argument("--feed", default="/home/unixnu/code/UniXNU-main/out/feeds/IOStorageFamily-ad2e13e0")
    args = ap.parse_args()

    ws = Path(args.workspace)
    out = ws / "out/umi/storage-abi"
    headers = out / "include/IOKit/storage"
    src_link = ws / "out/umi-xnu/IOStorageFamily"

    feed = Path(args.feed)
    if not (feed / "IOBlockStorageDevice.h").is_file():
        print(f"SKIP: 找不到 IOStorageFamily 源 {feed}")
        return 1
    head = git_head(feed)
    if head != PIN:
        print(f"SKIP: IOStorageFamily 版本不符（{head or '非 git 仓'} != {PIN}），不动未锁源的 header")
        return 1

    # 作者脚本用 ROOT/out/umi-xnu/IOStorageFamily；把它指到已锁源的 feed，保持一致
    if src_link.is_symlink() or src_link.is_file():
        src_link.unlink()
    elif src_link.is_dir():
        print("SKIP: out/umi-xnu/IOStorageFamily 是实体目录，不覆盖")
        return 1
    src_link.parent.mkdir(parents=True, exist_ok=True)
    src_link.symlink_to(feed, target_is_directory=True)

    headers.mkdir(parents=True, exist_ok=True)
    copied = 0
    for p in sorted(feed.glob("*.h")):
        dst = headers / p.name
        if dst.exists() and dst.read_bytes() == p.read_bytes():
            continue
        shutil.copyfile(p, dst)
        copied += 1

    tc = out / "include/TargetConditionals.h"
    try:
        sdk = Path(subprocess.run(["xcrun", "--sdk", "macosx", "--show-sdk-path"],
                                  text=True, capture_output=True).stdout.strip())
        donor = sdk / "usr/include/TargetConditionals.h"
    except (OSError, subprocess.SubprocessError):
        donor = None
    if not donor or not donor.is_file():
        donor = (ws / "out/umi-xnu/umi/tree/.cache/fakeroot/usr/include/TargetConditionals.h")
    if donor.is_file():
        if not (tc.exists() and tc.read_bytes() == donor.read_bytes()):
            shutil.copyfile(donor, tc)
            copied += 1

    n = len(list(headers.glob("*.h")))
    print(f"OK: storage-abi 头 {n} 个（本次写入 {copied}）源=IOStorageFamily@{PIN[:8]} "
          f"TargetConditionals={'有' if tc.is_file() else '缺'} sha={hashlib.sha256((headers / 'IOBlockStorageDevice.h').read_bytes()).hexdigest()[:12]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
