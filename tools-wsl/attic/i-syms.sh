#!/bin/bash
# 决定探针用什么格式化：内核镜像里到底有没有 snprintf/strlcpy 的符号，以及声明在哪。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/i-syms.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
K=/mnt/e/Code/HackIos/out/umi-xnu/umi/kernel/entry-trace-kernel.macho
ls -la "$K" 2>&1 | head -3
echo "== 内核镜像里的相关符号 =="
if [ -f "$K" ]; then
  /usr/bin/llvm-nm "$K" 2>/dev/null | grep -iE " (snprintf|vsnprintf|sprintf|vsprintf|strlcpy|strncpy|PE_boot_args|umi_screen_text|vfs_mountroot|mockfs_mountroot|bdevvp)$" | head -30
fi

echo
echo "== 源码里的声明位置 =="
grep -rn "snprintf" "$X/EXTERNAL_HEADERS/libkern/libkern.h" 2>/dev/null | head -6
grep -rn "strlcpy" "$X/EXTERNAL_HEADERS/libkern/libkern.h" 2>/dev/null | head -4
grep -rn "PE_boot_args" "$X/pexpert/pexpert.h" "$X/EXTERNAL_HEADERS/pexpert/pexpert.h" 2>/dev/null | head -4
echo "-- 定义处 --"
grep -rn "^snprintf\|^vsnprintf\|^sprintf" "$X/libkern" "$X/osfmk" 2>/dev/null | head -10
echo done
