#!/bin/bash
# K1：核准 EL0 打点的三个点位（load_init_program 定义/调用、mach_syscall 入口、unix_syscall 是否在树里）
set -u
LOG=/mnt/e/Code/HackIos/out/probes/k1-el0-sites2.txt
: > "$LOG"
exec >>"$LOG" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. load_init_program 全树定义与声明 =="
grep -rn 'load_init_program' "$X" --include='*.c' --include='*.h' 2>/dev/null | head -12
echo
echo "== 2. 定义体（若在 bsd_init.c 之外）=="
D=$(grep -rln '^load_init_program' "$X" --include='*.c' 2>/dev/null | head -1)
echo "def file=$D"
if [ -n "$D" ]; then
  S=$(grep -n '^load_init_program' "$D" | head -1 | cut -d: -f1)
  awk -v a="$S" 'NR>=a && NR<=a+70 {printf "%5d\t%s\n", NR, $0}' "$D"
fi
echo
echo "== 3. bsd_arm64.c 里 mach_syscall 头部 =="
awk 'NR>=170 && NR<=240 {printf "%5d\t%s\n", NR, $0}' "$X/osfmk/arm64/bsd_arm64.c"
echo
echo "== 4. unix_syscall 在不在这棵树 =="
grep -rn 'unix_syscall' "$X/osfmk/arm64/bsd_arm64.c" "$X/bsd/kern/kern_syscall.c" 2>/dev/null | head -10
grep -rln 'unix_syscall' "$X/osfmk" "$X/bsd/kern" 2>/dev/null | head -10
echo
echo "== 5. bsd_arm64.c 顶部的 include（打点要用的头在不在）=="
grep -n '#include' "$X/osfmk/arm64/bsd_arm64.c" | head -25
echo
echo "== 6. mach_syscall_name_table 声明 =="
grep -rn 'mach_syscall_name_table' "$X/osfmk/" --include='*.h' --include='*.c' 2>/dev/null | head -6
echo
echo "== 7. proc_name / current_proc 可用性（打点想带进程名）=="
grep -rn 'proc_name_address\|#define proc_name(' "$X/bsd/sys/proc.h" 2>/dev/null | head -6
echo "DONE"
