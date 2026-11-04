#!/bin/bash
# R 步之六：Mach trap 号表（mach_syscalls.h）与 sleh.c 里 mach 侧探针的去重行为。
# 走查件下一批要打 mach trap，号必须从生成的头里取；同时要确认屏上「一行 ≠ 一次调用」这条
# 纪律在 mach 侧成不成立（unix 侧 23z 是按 trap_no 去重的）。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r12-mach-trap-table.txt
: > "$LOG"
exec >> "$LOG" 2>&1
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi
H=$W/tree/build/xnu/ios-obj/EXPORT_HDRS/osfmk/mach/mach_syscalls.h
X=$W/tree/.cache/xnu-work

echo "== 1. mach_syscalls.h 里的 trap 号 =="
grep -E '^[[:space:]]*#[[:space:]]*define[[:space:]]+MACH_[A-Z_0-9]+[[:space:]]+-[0-9]+' "$H" | head -90
echo
echo "== 2. 计数与范围 =="
awk '/^[[:space:]]*#[[:space:]]*define[[:space:]]+MACH_[A-Z_0-9]+[[:space:]]+-[0-9]+/{n++; v=$3+0; if(min==""||v<min)min=v; if(max==""||v>max)max=v} END{print "count=" n " min=" min " max=" max}' "$H"
echo
echo "== 3. sleh.c 1926..2005（mach 侧探针打几次）=="
awk 'NR>=1926 && NR<=2005 {printf "%5d  %s\n", NR, $0}' "$X/osfmk/arm64/sleh.c"
echo "== done $(date -u +%FT%TZ)"
