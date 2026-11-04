#!/bin/bash
# K0：为「真机首次进 EL0」找打点位——load_init_program 出口 + 用户态第一条 syscall 的 C 入口
set -u
LOG=/mnt/e/Code/HackIos/out/probes/k0-el0-sites.txt
: > "$LOG"
exec >>"$LOG" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. bsd_init.c 里 load_init_program 的定义与调用点 =="
grep -n 'load_init_program' "$X/bsd/kern/bsd_init.c"
echo "-- 调用点上下文 --"
L=$(grep -n 'load_init_program' "$X/bsd/kern/bsd_init.c" | tail -1 | cut -d: -f1)
awk -v a=$((L-14)) -v b=$((L+22)) 'NR>=a && NR<=b {printf "%5d\t%s\n", NR, $0}' "$X/bsd/kern/bsd_init.c"
echo
echo "== 2. load_init_program 函数体尾部（exec 成功/失败处）=="
S=$(grep -n '^load_init_program' "$X/bsd/kern/bsd_init.c" | head -1 | cut -d: -f1)
echo "start=$S"
awk -v a="$S" 'NR>=a && NR<=a+95 {printf "%5d\t%s\n", NR, $0}' "$X/bsd/kern/bsd_init.c"
echo
echo "== 3. 用户态陷入内核的 C 入口（arm64 unix syscall）=="
grep -rn 'unix_syscall\|kern_syscall_slow\|syscall32' "$X/bsd/kern/kern_syscall.c" "$X/bsd/kern/unix_syscall.c" "$X/bsd/kern/syscalls.c" 2>/dev/null | head -15
ls "$X/bsd/kern/" | grep -i syscall
echo "-- 候选函数定义 --"
grep -rn '^unix_syscall\|^kern_syscall\|^syscall(' "$X/bsd/kern/" 2>/dev/null | head -10
echo
echo "== 4. mach 侧 trap（syscall 走哪条）=="
grep -rn 'mach_syscall\|_kernel_mach_syscall' "$X/osfmk/arm64/"*.c "$X/osfmk/arm64/sbm/"*.c 2>/dev/null | head -10
echo
echo "== 5. boot_progress.h 现有阶段名（避免撞名）=="
grep -n 'LOAD_INIT\|define' "$X/osfmk/kern/boot_progress.h" | head -30
echo "DONE"
