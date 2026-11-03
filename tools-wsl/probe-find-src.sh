#!/bin/bash
set -u
OUT=/home/unixnu/out/stuck3.txt
mkdir -p /home/unixnu/out
: > "$OUT"
echo "== locate patched startup.c ==" >> "$OUT"
find /home/unixnu -maxdepth 8 -name startup.c -path '*osfmk/kern*' 2>/dev/null >> "$OUT"
echo "== locate any file containing umi_screen_mark ==" >> "$OUT"
grep -rl "umi_screen_mark" /home/unixnu --include=*.c 2>/dev/null | head -10 >> "$OUT"
cp "$OUT" /mnt/e/Code/HackIos/out/stuck3.txt
echo copied
