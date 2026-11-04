#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/patch-mechanism.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
W=/home/unixnu/code/umi-work-pin
X=$W/out/umi-xnu/umi/tree/.cache/xnu-work

say "== 1. xnu-work 是不是 git 库 =="
ls -d "$X/.git" 2>/dev/null >> "$OUT"
git -C "$X" rev-parse --short HEAD 2>&1 | head -2 >> "$OUT"
git -C "$X" status --porcelain 2>&1 | head -8 >> "$OUT"

say
say "== 2. build_umi_xnu.py 如何还原基线与重放补丁 =="
grep -n 'patch\|checkout\|restore\|baseline\|git ' "$W/tools/build_umi_xnu.py" 2>/dev/null | head -30 >> "$OUT"

say
say "== 3. 现有补丁是否碰过 IOKitBSDInit.cpp =="
grep -l 'IOKitBSDInit' "$W/devices/umi/patches/umi-xnu/"*.patch 2>/dev/null >> "$OUT"
say "-- 当前文件里有没有 umi 标记 --"
grep -n 'umi' "$X/iokit/bsddev/IOKitBSDInit.cpp" | head -8 >> "$OUT"
say done
