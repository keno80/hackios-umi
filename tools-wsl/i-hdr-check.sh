#!/bin/bash
# 出补丁前的最后两处确认：boot_progress.h 的宏条件、libkern.h 里 snprintf/strlcpy 的声明。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/i-hdr-check.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== boot_progress.h 全文 =="
grep -n "" "$X/osfmk/kern/boot_progress.h"

echo
echo "== libkern.h 里 snprintf/strlcpy/vsnprintf 声明 =="
grep -n "snprintf\|strlcpy" "$X/libkern/libkern.h" | head -20

echo
echo "== PE_boot_args 的声明 =="
grep -rn "PE_boot_args" "$X/pexpert/pexpert.h" | head -5

echo
echo "== vfs_subr.c 是否已经能看到 rootdev 声明 =="
grep -rn "extern.*rootdev" "$X/bsd/sys" "$X/bsd/vfs" "$X/osfmk" 2>/dev/null | head -10
echo done
