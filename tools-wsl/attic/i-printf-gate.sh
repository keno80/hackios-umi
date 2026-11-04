#!/bin/bash
# 判读 printf 为什么没上屏：vprintf 的闸门与 video_console 的绘制入口。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/i-printf-gate.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. printf/vprintf 本体 =="
grep -n "" "$X/osfmk/kern/printf.c" | sed -n '860,990p'

echo
echo "== 2. vconsole_print / console_print 的闸门 =="
grep -n "PE_i_can_has_debugger\|console_log_level\|debug_mode\|if (!" "$X/osfmk/kern/printf.c" | head -30

echo
echo "== 3. video_console 里 umi_scr 的入口 =="
grep -n "umi_scr_\|video_console_printf\|vc_puts" "$X/osfmk/console/video_console.c" | head -30

echo
echo "== 4. 3660-3710 上下文 =="
grep -n "" "$X/osfmk/console/video_console.c" | sed -n '3655,3715p'
echo done
