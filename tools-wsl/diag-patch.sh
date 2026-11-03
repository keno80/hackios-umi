#!/bin/bash
# 诊断 umi 补丁系列为什么在 early-entry-trace.patch 上失败
set -u
for W in /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree /home/unixnu/code/UniXNU-main/out/umi/tree; do
  echo "########## $W"
  [ -d "$W" ] || { echo "不存在"; continue; }
  work=$W/.cache/xnu-work
  echo "xnu-work HEAD: $(git -C "$work" log --oneline -1 2>&1)"
  echo "refer/xnu HEAD: $(git -C "$W/refer/xnu" log --oneline -1 2>&1)"
  echo "-- 已改动文件 --"
  git -C "$work" status --porcelain 2>&1 | head -25
  echo "-- start.s 25..50 --"
  sed -n '25,50p' "$work/osfmk/arm64/start.s" 2>&1
  echo "-- arm_init.c 50..70 --"
  sed -n '50,70p' "$work/osfmk/arm/arm_init.c" 2>&1
  echo "-- patches/xnu 里谁动 start.s --"
  grep -l "osfmk/arm64/start.s" "$W"/patches/*/ 2>/dev/null | head -5
  ls "$W/patches" 2>/dev/null
  echo "-- git apply --check 逐补丁 --"
  for p in "$W"/patches/umi-xnu/*.patch; do
    r=$(git -C "$work" apply --reverse --check "$p" 2>&1 >/dev/null; echo $?)
    f=$(git -C "$work" apply --check "$p" 2>&1 >/dev/null; echo $?)
    echo "$(basename "$p") reverse=$r forward=$f"
  done
done
