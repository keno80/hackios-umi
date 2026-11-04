#!/bin/bash
# #51 归因之三：把 622 那条判据的真假坐实（thread_is_active 到底看什么字段），
# 并取 machine_load_context / thread_set_child 的函数体作为探针落点。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/m24-active-and-lctx.txt
: > "$OUT"
exec >>"$OUT" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
E=$X/osfmk/kern
S=$X/osfmk/arm64/status.c

echo "== 1. thread_is_active 函数体 =="
sed -n '410,432p' "$E/thread.c" | nl -ba -v410

echo
echo "== 2. active = TRUE 是哪给的（thread.c:1559 上下文）=="
sed -n '1525,1580p' "$E/thread.c" | nl -ba -v1525

echo
echo "== 3. thread_act.c:249 active = FALSE 的上下文 =="
sed -n '232,258p' "$E/thread_act.c" | nl -ba -v232

echo
echo "== 4. 谁调用 thread_launch / thread_start（init 那条线程的出生）=="
grep -rn 'thread_launch(' $E/*.c $X/bsd/kern/*.c 2>/dev/null | head -12
grep -rn 'kernel_bootstrap_thread' $E/startup.c | head -8

echo
echo "== 5. arm64 machine_load_context 声明/定义 =="
grep -n 'machine_load_context' "$S" | head
grep -rn 'machine_load_context' $X/osfmk/kern/sched_prim.c | head

echo
echo "== 6. thread_set_child 函数体（status.c:2030-2075）=="
sed -n '2030,2075p' "$S" | nl -ba -v2030

echo
echo "== 7. 现有 23z 探针的写法（照它的 idiom）=="
cat /mnt/e/Code/HackIos/patches/umi-xnu/zzzzzzzzzzzzzzzzzzzzzzz-el0-walk.patch 2>/dev/null || \
  ls -1 /mnt/e/Code/HackIos/patches/umi-xnu/ | tail -8

echo
echo "== 8. boot_progress_stage / printf 在 sleh.c 里可用的头 =="
grep -n 'UMIx2\.' "$X/bsd/kern/kern_exec.c" | head -6
grep -n 'UMIx2\.' "$S" | head -6
grep -rn 'UMIx2\.' $X/osfmk/arm64/sleh.c | head -6
echo "== done $(date -u +%FT%TZ)"
