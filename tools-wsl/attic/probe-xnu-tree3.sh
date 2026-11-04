#!/bin/bash
set -u
LOG=/mnt/e/Code/HackIos/out/probes/xnu-tree3.txt
C=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
{
  echo "== .cache/xnu-work 顶层"
  ls "$C" | head -25
  echo "== osfmk 顶层"
  ls "$C/osfmk" 2>/dev/null | head -25
  echo "== arm64 目录"
  ls "$C/osfmk/arm64" 2>/dev/null | head -30
  echo "== platform_log_write 全树搜索（限时 200s）"
  timeout 200 grep -rn 'platform_log_write' "$C/osfmk" "$C/bsd" 2>/dev/null | head -10
} > "$LOG" 2>&1
