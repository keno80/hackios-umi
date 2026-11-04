#!/bin/bash
# 读画屏补丁的对外接口：新钩子要调谁、startup.c 那处怎么挂的
set -u
OUT=/mnt/e/Code/HackIos/out/f-painter-api.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
D=/home/unixnu/code/umi-work-pin/devices/umi/patches/umi-xnu

say "== 目录实名 =="
ls "$D" | cat -A | grep screen >> "$OUT"
F=$(ls "$D"/*screen*.patch 2>/dev/null | head -1)
say "F=$F  size=$(stat -c %s "$F" 2>/dev/null)"

say
say "== 改了哪些文件 =="
grep -n '^+++ ' "$F" >> "$OUT"

say
say "== 新增/改动的函数与宏（画屏器导出面）=="
grep -n '^+\(void\|static\|extern\|#define\|boolean_t\|unsigned\|kern_return_t\|int \)' "$F" >> "$OUT"

say
say "== 所有 umi_scr_* / UMI 字面量 =="
grep -n 'umi_scr\|"UMI ' "$F" >> "$OUT"

say
say "== startup.c 那一段 hunk（看钩子挂在哪个函数）=="
awk '/^\+\+\+ b\/osfmk\/kern\/startup.c/{f=1} f&&/^@@/{p=1} p{print} /^\+\+\+ b\/osfmk\/kern\/debug.c/{exit}' "$F" | head -40 >> "$OUT"
say done
