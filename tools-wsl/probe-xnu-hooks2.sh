#!/bin/bash
set -u
LOG=/mnt/e/Code/HackIos/out/probes/xnu-hooks2.txt
C=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
{
  echo "== arm64 目录里的 platform/sbm"
  ls "$C/osfmk/arm64" | grep -E 'platform|sbm|cpu_atomics'
  echo "== osfmk/arm 里的 platform"
  ls "$C/osfmk/arm" | grep -E 'platform|sbm'
  echo "== console 目录"
  ls "$C/osfmk/console"
  echo "== platform_log_write 定义（限定文件）"
  grep -rn 'platform_log_write' "$C/osfmk/arm64/"*.c "$C/osfmk/arm/"*.c "$C/osfmk/console/"*.c 2>/dev/null | head -10
  echo "== video_console 里的写入口"
  grep -n 'vc_write_line\|void\s*vc_display\|video_console_write\|vc_init' "$C/osfmk/console/video_console.c" 2>/dev/null | head -20
  echo "== machine_kernel / start_kernel 位置"
  grep -rn 'machine_kernel(void)' "$C/osfmk/arm64/"*.c 2>/dev/null | head -3
  grep -rn 'start_kernel(' "$C/osfmk/kern/startup.c" 2>/dev/null | head -3
  echo "== 现有 umi 补丁里是否已碰过这些文件"
  ls /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/patches/umi-xnu/ 2>/dev/null | head -30
} > "$LOG" 2>&1
