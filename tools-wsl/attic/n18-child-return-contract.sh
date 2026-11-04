#!/bin/bash
# N 步之五：坐实「子进程 fork 返回值应为 0」这条契约在本树/上游各在哪落地。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n18-child-return-contract.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
MAIN=/home/unixnu/code/UniXNU-main

echo "== 1. task_wait_to_return 后半段（醒后到底怎么回 EL0，有没有改返回值）=="
L=$(grep -n '^task_wait_to_return' "$X/osfmk/kern/task.c" | head -1 | cut -d: -f1)
sed -n "$((L+40)),$((L+110))p" "$X/osfmk/kern/task.c" | grep -n ''

echo
echo "== 2. get_user_regs 在 arm64 的实现（写进去的到底是哪份状态）=="
grep -rn 'get_user_regs' "$X/osfmk/arm64/"*.c "$X/osfmk/arm64/"*.h "$X/osfmk/mach/"*.h 2>/dev/null | head -8
F=$(grep -rl 'define get_user_regs\|get_user_regs(thread_t' "$X/osfmk" 2>/dev/null | head -3)
echo "FILES: $F"
for f in $F; do
  echo "-- $f --"
  L2=$(grep -n 'get_user_regs' "$f" | head -1 | cut -d: -f1)
  sed -n "$((L2-3)),$((L2+12))p" "$f"
done

echo
echo "== 3. syscall 返回路径上有没有对 fork 特判归零 =="
grep -rn 'SYS_fork\|SYS_vfork\|SYS_rfork' "$X/bsd/kern/kern_syscall.c" "$X/bsd/kern/unix_syscalls.c" \
  "$X/bsd/kern/kern_fork.c" "$X/osfmk/arm64/sleh.c" 2>/dev/null | head -12

echo
echo "== 4. 全树还有谁调 thread_set_child、传的是什么 =="
grep -rn 'thread_set_child(' "$X" --include=*.c --include=*.h --include=*.S 2>/dev/null | grep -v 'i386' | head

echo
echo "== 5. 上游 native-user 走查件是怎么用 fork 返回值的（期望 0 的契约证据）=="
find "$MAIN" -name 'native-user*.S' -o -name 'native_user*.S' 2>/dev/null | head -5
for f in $(find "$MAIN" -name 'native-user*.S' 2>/dev/null | head -3); do
  echo "-- $f --"
  grep -n -A12 -i 'fork' "$f" | head -40
done

echo
echo "== 6. 上游 fixture 编出来的 launchd.macho 里 fork 之后是什么指令 =="
U=$MAIN/build/native-user-fixture-umi/launchd.macho
ls -la "$U" 2>/dev/null
/usr/bin/llvm-objdump -d --symbolize-operands "$U" 2>/dev/null | grep -n -B3 -A12 'cbz\|_child' | head -40
echo done
