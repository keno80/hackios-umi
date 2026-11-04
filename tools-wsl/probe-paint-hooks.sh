#!/bin/bash
# F 步 Phase2：画屏器导出面 + mountroot 之后的日志通道到底走哪条、受什么门控
set -u
OUT=/mnt/e/Code/HackIos/out/f-hooks.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
D=/home/unixnu/code/umi-work-pin/devices/umi/patches/umi-xnu
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
F=$(ls "$D"/*screen*.patch | head -1)
say "F=$F"

say
say "== 1. 补丁改了哪些文件 =="
grep -n '^+++ ' "$F" >> "$OUT"

say
say "== 2. 画屏器导出面（新增函数/宏/全局）=="
grep -n '^+\(void\|static\|extern\|#define\|boolean_t\|unsigned\|kern_return_t\|int \|char \)' "$F" | head -30 >> "$OUT"
say "-- 所有 umi_scr_ 调用点 --"
grep -n 'umi_scr' "$F" | head -30 >> "$OUT"

say
say "== 3. startup.c 的 hunk（钩在哪个函数、怎么调画屏器）=="
awk '/^\+\+\+ b\/osfmk\/kern\/startup.c/{f=1;next} f&&/^@@/{p=1} p{print} f&&/^\+\+\+ /&&!/startup.c/{exit}' "$F" | head -45 >> "$OUT"

say
say "== 4. boot_progress_stage 定义与门控 =="
grep -rn "boot_progress_stage" "$T/osfmk/kern/"*.c "$T/osfmk/kern/*.h" 2>/dev/null | head -10 >> "$OUT"
grep -rn "boot_progress_arg\|boot-progress" "$T/osfmk/" "$T/bsd/kern/bsd_init.c" 2>/dev/null | head -15 >> "$OUT"
say
say "== 5. bsd_init_kprintf 定义 =="
grep -rn "define bsd_init_kprintf\|bsd_init_kprintf(" "$T/bsd/kern/bsd_init.c" | head -6 >> "$OUT"
grep -rn "klogprintf\|bsd_init_verbose" "$T/bsd/kern/bsd_init.c" | head -8 >> "$OUT"
say
say "== 6. mountroot 前后的完整上下文（bsd_init.c:1005..1030）=="
sed -n '1005,1032p' "$T/bsd/kern/bsd_init.c" >> "$OUT"
say done
