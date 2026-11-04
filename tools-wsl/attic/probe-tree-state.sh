#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/f-treestate.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
say "== date =="
date -u >> "$OUT"
say "== umi-work-pin 顶层 =="
ls -la /home/unixnu/code/ 2>&1 | head >> "$OUT"
ls -la /home/unixnu/code/umi-work-pin/ 2>&1 | head -20 >> "$OUT"
say "== devices/umi/patches =="
ls -la /home/unixnu/code/umi-work-pin/devices/umi/patches/ 2>&1 | head >> "$OUT"
ls /home/unixnu/code/umi-work-pin/devices/umi/patches/umi-xnu/ 2>&1 | head -30 >> "$OUT"
say "== 磁盘与挂载 =="
df -h /home/unixnu 2>&1 | head -3 >> "$OUT"
mount | grep -E "unixnu|code" 2>&1 | head >> "$OUT"
say "== 内核产物还在吗 =="
ls -la /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho 2>&1 >> "$OUT"
ls -la /home/unixnu/code/umi-work-pin/out/umi/xnu/umi-xnu-fat.img 2>&1 >> "$OUT"
say "== 正在跑的重活 =="
ps -eo pid,etime,rss,comm --sort=-rss 2>/dev/null | head -12 >> "$OUT"
say done
