#!/bin/bash
# K2：取 K 步补丁的精确锚点文本（kern_exec.c 的 load_init_program 全函数 + bsd_arm64.c mach_syscall 头部）
set -u
LOG=/mnt/e/Code/HackIos/out/probes/k2-el0-anchor.txt
: > "$LOG"
exec >>"$LOG" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== A. kern_exec.c 7485..7585 =="
awk 'NR>=7485 && NR<=7585 {printf "%5d\t%s\n", NR, $0}' "$X/bsd/kern/kern_exec.c"
echo
echo "== B. bsd_arm64.c 176..205 =="
awk 'NR>=176 && NR<=205 {printf "%5d\t%s\n", NR, $0}' "$X/osfmk/arm64/bsd_arm64.c"
echo
echo "== C. kern_exec.c 是否已 include boot_progress.h =="
grep -n 'boot_progress' "$X/bsd/kern/kern_exec.c" | head -8
echo
echo "== D. umi_exec_attempts 这个既有计数在哪定义（K 步想复用一次性闸）=="
grep -n 'umi_exec_attempts' "$X/bsd/kern/kern_exec.c" | head -8
echo
echo "== E. sleh.c 里 unix syscall 分派点（备用打点）=="
grep -n 'unix_syscall\|syscall()' "$X/osfmk/arm64/sleh.c" | head -10
echo "DONE"
