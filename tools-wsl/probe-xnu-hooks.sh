#!/bin/bash
set -u
LOG=/mnt/e/Code/HackIos/out/xnu-hooks.txt
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
{
  echo "== platform_log_write 定义位置"
  grep -rn 'platform_log_write' "$X/osfmk" --include='*.c' --include='*.h' --include='*.cpp' 2>/dev/null | head -12
  echo "== 其实现体（arm64）"
  F=$(grep -rl 'void.*platform_log_write' "$X/osfmk/arm64" "$X/osfmk/arm" 2>/dev/null | head -1)
  echo "  文件：$F"
  [ -n "$F" ] && awk '/platform_log_write/{f=1} f{print NR": "$0} f&&/^}/{c++; if(c>0) exit}' "$F" | head -60
  echo "== ml_io_map / ml_io_map_unmappable 声明"
  grep -rn 'ml_io_map' "$X/osfmk/machine/machine_routines.h" "$X/osfmk/arm/machine_routines.h" 2>/dev/null | head -6
  echo "== start_kernel 定义"
  grep -rn '^start_kernel\|kern_return_t\s*$' "$X/osfmk/kern/startup.c" 2>/dev/null | head -5
  grep -n 'start_kernel' "$X/osfmk/kern/startup.c" | head -6
  echo "== machine_kernel 里的 printf 首条"
  grep -n 'Starting kernel\|machine_kernel' "$X/osfmk/arm64/sbm.c" | head -8
} > "$LOG" 2>&1
