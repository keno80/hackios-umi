#!/bin/bash
# R 步之七：上一版 r12 的号表 grep 空手而归——mach_syscalls.h 里是 `#define MACH_MSG (-34)` 这种
# 带括号的负数形式，正则要求「空白后紧跟 -数字」就整段没命中。这版按真形态取。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r13-mach-trap-numbers.txt
: > "$LOG"
exec >> "$LOG" 2>&1
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi
H=$W/tree/build/xnu/ios-obj/EXPORT_HDRS/osfmk/mach/mach_syscalls.h
X=$W/tree/.cache/xnu-work

echo "== 1. 头文件前 30 行（看真实写法）=="
head -30 "$H"
echo
echo "== 2. 走查件要打的 trap 号 =="
for n in MACH_MSG MACH_MSG_OVERWRITE MACH_REPLY MACH_DESTROY MACH_PORT_ALLOCATE \
         MACH_PORT_DEALLOCATE MACH_PORT_INSERT MACH_PORT_EXTRACT MACH_PORT_MOD_REFS \
         MACH_PORT_GET_RIGHTS MACH_TASK_SELF MACH_HOST_SELF MACH_TASK_GET_SPECIAL_PORT \
         MACH_VM_ALLOCATE MACH_VM_DEALLOCATE MACH_VM_MAP THREAD_SELF MACH_TIME_VALUE_TO_TIMESPEC; do
  v=$(grep -E "^[[:space:]]*#[[:space:]]*define[[:space:]]+$n[[:space:]]" "$H" | sed 's/.*[[:space:]]//')
  printf '%-34s %s\n' "$n" "${v:-NONE}"
done
echo
echo "== 3. 分派表上限（越界=踩表）=="
grep -rn "MAXMACHTRAPS" "$X/osfmk/kern/syscall_sw.c" "$X"/osfmk/mach/*.h 2>/dev/null | head -6
echo
echo "== 4. svc 号怎么取（正负如何区分 unix/mach）=="
grep -rn "get_saved_state_svc_number" "$X/osfmk/arm64/saved_state.h" 2>/dev/null | head -6
grep -rn -A8 "get_saved_state_svc_number(const arm_saved_state_t" "$X/osfmk/arm64/saved_state.h" 2>/dev/null | head -20
echo "== done $(date -u +%FT%TZ)"
