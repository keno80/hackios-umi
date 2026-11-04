#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/umi-tool-argparse.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
F=/home/unixnu/code/UniXNU-umi/bringup/tools/build_umi_xnu.py

say "== 1. argparse 全段 =="
awk '/add_argument|ArgumentParser|def main|set_defaults/' "$F" | head -60 >> "$OUT" 2>&1
say
say "== 2. 精确行号：parser 区（含行号打印）=="
grep -n 'add_argument' "$F" >> "$OUT" 2>&1

say
say "== 3. data_input 的来源与校验（60..130）=="
sed -n '60,130p' "$F" >> "$OUT" 2>&1

say
say "== 4. settings 白名单区（255..300）=="
sed -n '255,300p' "$F" >> "$OUT" 2>&1

say
say "== 5. 两份副本差异的完整上下文（265..275）=="
say "-- repo 副本 --"
sed -n '263,276p' "$F" >> "$OUT" 2>&1
say "-- 工作副本 --"
sed -n '263,276p' /home/unixnu/code/umi-work-pin/tools/build_umi_xnu.py >> "$OUT" 2>&1
say done
