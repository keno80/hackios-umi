#!/bin/bash
# 关键判读：bsd_init_kprintf 走的是哪条道，普通 printf 为什么没上屏。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/i-printf-route.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. bsd_init_kprintf 的定义 =="
grep -n "bsd_init_kprintf" "$X/bsd/kern/bsd_init.c" | head -3
grep -n "define bsd_init_kprintf" -A4 "$X/bsd/kern/bsd_init.c" | head -12

echo
echo "== 2. kprintf 的定义 =="
grep -rn "define[[:space:]]*kprintf" "$X/bsd" "$X/osfmk" 2>/dev/null | head -5

echo
echo "== 3. printf 的实现链（console.c）=="
grep -rn "^printf\|^vprintf\|^console_print\|PutConsole\|dcprintf" "$X/osfmk/libsa/console.c" 2>/dev/null | head -25

echo
echo "== 4. 上屏补丁都动了哪些函数 =="
grep -n "^+++\|^@@" /home/unixnu/code/UniXNU-umi/patches/umi-xnu/zzzzzzzzzzzzzzzzzzzz-umi-boot-stage.patch
echo "-- screen 补丁动了哪些文件 --"
grep -n "^--- a/\|^+++ b/" /home/unixnu/code/UniXNU-umi/patches/umi-xnu/zzzzzzzzzzzzzzzzzzzzz-umi-screen.patch | head -30
echo "-- screen 补丁里 umi_screen_text 的实现签名 --"
grep -n "umi_screen_text\|boot_progress_stage" /home/unixnu/code/UniXNU-umi/patches/umi-xnu/zzzzzzzzzzzzzzzzzzzzz-umi-screen.patch | head -20

echo
echo "== 5. 内核里谁把文字画到屏（UMI .. 前缀）=="
grep -rn '"UMI ' "$X" 2>/dev/null | head -10
echo done
