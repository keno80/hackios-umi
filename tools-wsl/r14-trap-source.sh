#!/bin/bash
# R 步之八：r13 四处全空手，说明「mach_syscalls.h 里有 #define MACH_MSG (-34)」这个假设错了，
# 且 syscall_sw.c / saved_state.h 的猜测路径也不对。这版不做假设：先 find 出真路径，再原样打印。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r14-trap-source.txt
: > "$LOG"
exec >> "$LOG" 2>&1
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi
X=$W/tree/.cache/xnu-work

echo "== 0. 源树根是否真的在 =="
ls -d "$X" && ls "$X" | head -20

echo
echo "== 1. mach_syscalls.h 里所有 #define（原样，看真形态）=="
H=$W/tree/build/xnu/ios-obj/EXPORT_HDRS/osfmk/mach/mach_syscalls.h
grep -n "#define" "$H" 2>/dev/null | head -40
echo "--- define 计数：" $(grep -c "#define" "$H" 2>/dev/null)
echo "--- 非 define 的前 20 行代码长什么样："
grep -vE '^\s*\*|^\s*/\*|^\s*$' "$H" 2>/dev/null | head -20

echo
echo "== 2. 真路径发现：syscall_sw.c / saved_state.h / mach.trap.h =="
for pat in syscall_sw.c saved_state.h mach.trap.h mach_syscalls.def; do
  echo "-- $pat"
  find "$X" -name "$pat" 2>/dev/null | head -5
done

echo
echo "== 3. MAXMACHTRAPS 与 MKTRAP 到底在哪 =="
grep -rn "MAXMACHTRAPS" "$X" 2>/dev/null | head -8
echo "---"
grep -rln "MKTRAP" "$X" 2>/dev/null | head -8

echo
echo "== 4. mach 分派表本体（machsysent / mach_syscall）=="
grep -rn "machsysent" "$X" 2>/dev/null | head -10

echo
echo "== 5. get_saved_state_svc_number 的真实定义位置 =="
grep -rn "get_saved_state_svc_number" "$X" 2>/dev/null | grep -v sleh.c | head -10

echo "== done $(date -u +%FT%TZ)"
