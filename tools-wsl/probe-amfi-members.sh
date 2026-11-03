#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/amfi-members.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
W=/home/unixnu/code/umi-work-pin

say "== 1. 实际被解引用的 amfi 成员（去重）=="
grep -rhoE 'amfi->[A-Za-z0-9_.]+' "$X" --include='*.c' --include='*.cpp' 2>/dev/null | sort | uniq -c | sort -rn >> "$OUT"

say
say "== 2. 这些成员的 typedef（返回类型）=="
H="$X/libkern/libkern/amfi/amfi.h"
for m in $(grep -rhoE 'amfi->[A-Za-z0-9_.]+' "$X" --include='*.c' --include='*.cpp' 2>/dev/null | sed 's/amfi->//' | cut -d. -f1 | sort -u); do
  say "-- $m --"
  grep -nE "\($m\)|\b$m\b" "$H" | head -6 >> "$OUT"
done

say
say "== 3. crypto kit 在 pe_init.c 的 hunk =="
sed -n '190,205p' "$W/devices/umi/patches/umi-xnu/zzzzzzzzzzzzzzzzzz-umi-crypto-kit.patch" >> "$OUT" 2>&1

say
say "== 4. 补丁目录里最长的 z 前缀（新补丁命名）=="
ls -1 "$W/devices/umi/patches/umi-xnu/" | awk '{print length($0), $0}' | sort -rn | head -3 >> "$OUT"
say done
