#!/bin/bash
# R 步之十：r15 定位到真表在 osfmk/kern/syscall_sw.c 的 mach_trap_table[MACH_TRAP_TABLE_COUNT]，
# 但还缺三件事：① 表长度 ② 全表（含每行 /* n */ 序号）③ sleh.c 的 trap_no<0 是怎么换成表下标的、
# 有没有越界防护（走查件要打多发 mach trap，越界就是踩表，必须先知道安全范围）。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r16-mach-trap-full.txt
: > "$LOG"
exec >> "$LOG" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
SW=$X/osfmk/kern/syscall_sw.c

echo "== 1. MACH_TRAP_TABLE_COUNT 定义 =="
grep -rn "MACH_TRAP_TABLE_COUNT" "$X" 2>/dev/null | grep -E "define|=" | head -6

echo
echo "== 2. mach_trap_table 全表（105..241）=="
sed -n '105,241p' "$SW"

echo
echo "== 3. mach_syscall 本体在哪（负号→下标的换算点）=="
grep -rn "mach_syscall" "$X/osfmk" 2>/dev/null | grep -vE "mach_syscalls\.h|name_table" | head -12

echo
echo "== 4. sleh.c 中 trap_no 处理原文（1900..1935）=="
sed -n '1900,1935p' "$X/osfmk/arm64/sleh.c"

echo
echo "== 5. 越界防护：mach 侧有没有对 -trap_no 做 < 表长的检查 =="
grep -rn -B3 -A12 "mach_syscall(arm_saved_state_t\|void mach_syscall" "$X" 2>/dev/null | head -40

echo
echo "== 6. unix 侧对照：unix_syscall 表长与越界处理 =="
grep -rn "MAXSYSCALL\|sysent_count\|unix_syscall(" "$X/bsd/kern/kern_syscall.c" 2>/dev/null | head -12
echo "== done $(date -u +%FT%TZ)"
