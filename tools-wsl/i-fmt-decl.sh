#!/bin/bash
# 定死格式化函数：sprintf/snprintf 到底由哪个头声明，bsd_init.c/vfs_subr.c 现有头能不能看到。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/i-fmt-decl.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. 头文件里 snprintf/sprintf 的声明 =="
grep -rn "snprintf\|^int.*sprintf\|sprintf(" "$X/bsd/sys/systm.h" "$X/osfmk/kern/debug.h" "$X/EXTERNAL_HEADERS/libkern/libkern.h" "$X/libkern/libkern.h" 2>/dev/null | head -20

echo
echo "== 2. 全树找 snprintf 的 extern 声明 =="
grep -rln "extern.*snprintf\|int[[:space:]]*snprintf(char" "$X" --include=*.h 2>/dev/null | head -10

echo
echo "== 3. bsd_init.c 现在能看到哪些 printf 家族 =="
grep -n "debug.h\|stdio.h\|libkern" "$X/bsd/kern/bsd_init.c" | head -10

echo
echo "== 4. 同样看 vfs_subr.c =="
grep -n "debug.h\|stdio.h\|libkern" "$X/bsd/vfs/vfs_subr.c" | head -10

echo
echo "== 5. 内核里别的 bsd/vfs 文件怎么用 snprintf 的 =="
grep -rn "snprintf" "$X/bsd/vfs" 2>/dev/null | head -8
echo done
