#!/bin/bash
set -u
LOG=/mnt/e/Code/HackIos/out/probes/umi-xnu-patches.txt
P=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/patches/umi-xnu
{
  echo "== 尺寸"
  ls -la "$P" | awk '{print $5, $9}' | tail -n +4
  echo "== 每个补丁触碰的文件"
  for f in "$P"/*.patch; do
    echo "--- $(basename "$f")"
    grep -E '^\+\+\+ ' "$f" | head -6
  done
  echo "== 出现的固定物理地址"
  grep -rhoE '0x[0-9A-Fa-f]{6,12}' "$P" | sort | uniq -c | sort -rn | head -20
  echo "== 导出的 trace 函数名"
  grep -rhoE '\bumi_[a-z0-9_]+\(' "$P" | sort -u | head -30
} > "$LOG" 2>&1
