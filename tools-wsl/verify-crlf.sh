#!/bin/bash
# 复核 LF 重建后的 git 状态，并确认补丁可用
set -u
R=/home/unixnu/code/UniXNU-umi
echo "status 行数=$(git -C "$R" status --porcelain | wc -l)"
git -C "$R" status --porcelain | head -5
echo "diff 行数=$(git -C "$R" diff | wc -l)"
echo "-- 首个补丁的行尾 --"
head -4 "$R/patches/umi-xnu/early-entry-trace.patch" | cat -A | head -4
echo "-- 逐补丁 forward check（对 pin 树里的干净 xnu-work） --"
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
work=$W/.cache/xnu-work
echo "xnu-work 脏文件=$(git -C "$work" status --porcelain | wc -l)"
for p in "$R"/patches/umi-xnu/*.patch; do
  f=$(git -C "$work" apply --check "$p" 2>&1 | head -1)
  echo "$(basename "$p"): ${f:-OK}"
done
