#!/bin/bash
# 探针落点二次核对：rootdev 从哪来、snprintf 是否可用、umi_screen_text 在哪实现。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/i-probe-sites.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. rootdev 的声明与赋值 =="
grep -rn "rootdev\b" "$X/bsd/kern/bsd_init.c" | head -20
echo "-- 全树 rootdev = 赋值 --"
grep -rn "rootdev =" "$X/bsd" "$X/osfmk" 2>/dev/null | head -20

echo
echo "== 2. rd= 解析在哪 =="
grep -rn '"rd="' "$X/bsd" "$X/osfmk" 2>/dev/null | head -10
grep -rn 'rd=' "$X/bsd/kern/bsd_init.c" | head -10

echo
echo "== 3. snprintf/sprintf 在这两个文件里是否已用 =="
grep -c "snprintf" "$X/bsd/vfs/vfs_subr.c" "$X/bsd/kern/bsd_init.c"
grep -rn "snprintf" "$X/bsd/kern/bsd_init.c" | head -5
echo "-- 声明处 --"
grep -rn "snprintf" "$X/bsd/sys/systm.h" "$X/libkern/libkern.h" "$X/EXTERNAL_HEADERS/libkern/libkern.h" 2>/dev/null | head -10

echo
echo "== 4. umi_screen_text 的实现与声明 =="
grep -rn "umi_screen_text" "$X" 2>/dev/null | head -20

echo
echo "== 5. boot_progress_stage 的宏 =="
sed -n '1,80p' "$X/osfmk/kern/boot_progress.h"

echo
echo "== 6. bsd_rooted_ramdisk 定义 =="
grep -rn "bsd_rooted_ramdisk" "$X/bsd" "$X/osfmk" 2>/dev/null | head -10
echo done
