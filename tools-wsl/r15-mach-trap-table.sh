#!/bin/bash
# R 步之九：r14 摸清两件事——mach_syscalls.h 只是 <mach/mach_traps.h> 的转接口，
# 而全树 grep MAXMACHTRAPS / machsysent 竟全空。要么这版 XNU 换了名字，要么 syscall_sw.c 里是别的符号。
# 这版直接打开 syscall_sw.c 和 mach_traps.h 看原文，不再猜符号名。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r15-mach-trap-table.txt
: > "$LOG"
exec >> "$LOG" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
B=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/EXPORT_HDRS

echo "== 1. syscall_sw.c 结构（前 60 行非注释）=="
grep -vE '^\s*\*|^\s*/\*|^\s*$' "$X/osfmk/kern/syscall_sw.c" | head -60

echo
echo "== 2. syscall_sw.c 里的表与计数（任何 *_SYSCTL/entry/size 字样）=="
grep -nE "syscall(?:_entry|table)|_count|COUNT|size" "$X/osfmk/kern/syscall_sw.c" | head -30

echo
echo "== 3. mach_traps.h 真身在哪 =="
find "$X" "$B" -name "mach_traps.h" 2>/dev/null | head -5

echo
echo "== 4. mach 侧 svc 号：sleh.c 走 mach_syscall()，找它的分派 =="
grep -rn "mach_syscall" "$X/osfmk/kern/"*.c 2>/dev/null | head -10
echo "--- syscall_sw.c 里 mach 相关行 ---"
grep -n "mach" "$X/osfmk/kern/syscall_sw.c" | head -30

echo
echo "== 5. arm 侧 svc 号语义（thread_status.h:970-1000 原文）=="
sed -n '965,1000p' "$X/osfmk/mach/arm/thread_status.h"

echo "== done $(date -u +%FT%TZ)"
