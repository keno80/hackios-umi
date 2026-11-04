#!/bin/bash
# boot_progress_stage 的定义到底在不在树里（决定钩子加在哪）
set -u
OUT=/mnt/e/Code/HackIos/out/probes/f-bpdef.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

say "== 名字里带 boot_progress 的文件 =="
find "$T" -name "*boot_progress*" 2>/dev/null >> "$OUT"
say
say "== boot_progress.h 全文 =="
cat "$T/osfmk/kern/boot_progress.h" >> "$OUT" 2>&1
say
say "== 若有 boot_progress.c：头 60 行 =="
for f in $(find "$T" -name "boot_progress.c" 2>/dev/null); do
  say "-- $f --"
  sed -n '1,60p' "$f" >> "$OUT"
done
say
say "== 全树搜 boot_progress_stage 的定义式写法 =="
grep -rn "boot_progress_stage" "$T" 2>/dev/null | grep -v "\.h:" | grep -v "boot_progress_stage(" | head >> "$OUT"
grep -rn "boot_progress_stage(const char \*\|boot_progress_stage (\|_boot_progress_stage" "$T" 2>/dev/null | head >> "$OUT"
say
say "== 是不是只在 arm64/CONFIG 里编？Makefile 里的痕迹 =="
grep -rn "boot_progress" "$T/osfmk/kern/Makefile" 2>/dev/null | head >> "$OUT"
grep -rn "boot_progress" "$T/osfmk/*.defs" 2>/dev/null | head >> "$OUT"
say done
