#!/bin/bash
# 打点要在 osfmk/arm64/sleh.c 里用 snprintf：确认这棵树里 snprintf 由哪个头声明，
# 以及同目录已有文件是怎么引的，防止 include 引错让整场 kernel 构建白跑。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/k4-snprintf.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. sleh.c 里现在有没有 snprintf/printf =="
grep -n 'snprintf\|printf0\|kprintf' "$X/osfmk/arm64/sleh.c" | head -20
echo "hit=$(grep -c 'snprintf' "$X/osfmk/arm64/sleh.c")"

echo
echo "== 2. 声明 snprintf 的头 =="
grep -rn 'snprintf' "$X/osfmk/kern/misc_protos.h" "$X/libkern/libkern.h" "$X/libkern/klib.h" 2>/dev/null | head -20

echo
echo "== 3. boot_progress.h 全文（看 stage 到底接到哪）=="
cat "$X/osfmk/kern/boot_progress.h"

echo
echo "== 4. 同目录用 snprintf 的文件都引了什么头 =="
for f in $(grep -rl 'snprintf' "$X/osfmk/arm64/" 2>/dev/null | head -6); do
  echo "-- $f"
  grep -n '#include <libkern\|#include <kern/misc_protos' "$f" | head -5
done

echo
echo "== 5. sleh.c 是否已在别的补丁里被改过（对比干净树）=="
D=/home/unixnu/code/UniXNU-umi/patches/umi-xnu
for p in "$D"/*.patch; do
  if grep -q 'osfmk/arm64/sleh.c' "$p" 2>/dev/null; then echo "TOUCHES-SLEH: $(basename "$p")"; fi
done
echo "== 6. 现有补丁清单（按重放序）=="
ls "$D" | sort
echo
echo "== 7. 基线是不是 21z 之后的状态（决定新补丁的上下文对不对）=="
printf 'bsd_init MOUNTFAIL hit=%s\n' "$(grep -c 'MOUNTFAIL' "$X/bsd/kern/bsd_init.c")"
printf 'vfs_subr MR-exhausted hit=%s\n' "$(grep -c 'MR exhausted last=' "$X/bsd/vfs/vfs_subr.c")"
printf 'kern_exec boot-progress-enter hit=%s\n' "$(grep -c 'load_init_program enter' "$X/bsd/kern/kern_exec.c")"
printf 'kern_exec libkern hit=%s\n' "$(grep -c 'include <libkern/libkern.h>' "$X/bsd/kern/kern_exec.c")"
printf 'sleh libkern hit=%s\n' "$(grep -c 'include <libkern/libkern.h>' "$X/osfmk/arm64/sleh.c")"
echo done
