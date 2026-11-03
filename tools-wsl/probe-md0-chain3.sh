#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/md0-chain3.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

say "== 1. IORamDiskBSDRoot 的调用者 =="
grep -rn 'IORamDiskBSDRoot' "$W" 2>/dev/null | grep -v '\.o' >> "$OUT"

say
say "== 2. bsd_init.c 1000..1120 =="
sed -n '1000,1120p' "$W/bsd/kern/bsd_init.c" >> "$OUT" 2>&1

say
say "== 3. vfs_subr.c 1205..1290（vfs_mountroot 主体）=="
sed -n '1205,1290p' "$W/bsd/vfs/vfs_subr.c" >> "$OUT" 2>&1

say
say "== 4. memdev.h 全文 =="
cat "$W/bsd/dev/memdev.h" >> "$OUT" 2>&1
say "-- memdev.c 顶层函数定义 --"
grep -nE '^[a-zA-Z_][a-zA-Z0-9_ ]*\(' "$W/bsd/dev/memdev.c" | head -40 >> "$OUT"

say
say "== 5. ramdevice_init / mdev 注册者调用链 =="
grep -rn 'ramdevice_init\|mdevadd\|dev_ops_majors' "$W/bsd" 2>/dev/null | grep -v '\.o' | head -20 >> "$OUT"
say done
