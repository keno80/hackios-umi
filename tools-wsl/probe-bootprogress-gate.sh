#!/bin/bash
# XNU_BOOT_PROGRESS：谁能把它打开、实现件在不在我们拿得到的源里
set -u
OUT=/mnt/e/Code/HackIos/out/f-bpgate.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
S=/home/unixnu/code/UniXNU-main
W=/home/unixnu/code/umi-work-pin

say "== 全工作区搜 boot_progress 的实现文件 =="
find /home/unixnu/code -maxdepth 8 -name "boot_progress*.c" -o -maxdepth 8 -name "*boot-progress*" 2>/dev/null | head -15 >> "$OUT"
say
say "== XNU_BOOT_PROGRESS 在哪里被定义/打开 =="
grep -rn "XNU_BOOT_PROGRESS" "$T" 2>/dev/null | grep -v boot_progress.h | head -15 >> "$OUT"
grep -rn "XNU_BOOT_PROGRESS" "$S" "$W/devices" "$W/tools" 2>/dev/null | head -15 >> "$OUT"
say
say "== boot-progress boot-arg 的解析方（谁读它）=="
grep -rn "boot-progress" "$S" "$W/devices" "$W/tools" 2>/dev/null | grep -v Binary | head -20 >> "$OUT"
say
say "== 我们内核里 boot_progress 符号到底在不在（xcrun nm）=="
/usr/bin/xcrun nm -arch arm64 "$W/out/umi-xnu/umi/kernel/source-kernel.macho" 2>/dev/null | grep -i boot_progress | head -10 >> "$OUT"
say "nm rc=$?"
say "-- 兜底：llvm-nm --format=posix --define-only --no-sort 里找 --"
llvm-nm "$W/out/umi-xnu/umi/kernel/source-kernel.macho" 2>/dev/null | grep -i "boot_progress\|umi_screen" | head -12 >> "$OUT"
say done
