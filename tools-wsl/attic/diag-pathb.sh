#!/bin/bash
# 取证：路B(main) 为什么在 optional-legacy-display.patch 上失败
set -u
P=/home/unixnu/code/UniXNU-umi/patches/umi-xnu/optional-legacy-display.patch
echo "== 补丁第一个 hunk =="
awk '/^@@/{c++} c<=1' "$P" | head -25
for W in /home/unixnu/code/UniXNU-main/out/umi/tree /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree; do
  f=$W/.cache/xnu-work/bsd/kern/bsd_init.c
  echo "== $W 的 bsd_init.c 540..560 =="
  sed -n '540,560p' "$f" 2>/dev/null | cat -n
  echo "该树已应用的 umi 补丁数=$(git -C "$W/.cache/xnu-work" status --porcelain 2>/dev/null | wc -l) 个改动文件"
  echo "check 结果：$(git -C "$W/.cache/xnu-work" apply --check -v "$P" 2>&1 | head -3 | tr '\n' ' ')"
done
