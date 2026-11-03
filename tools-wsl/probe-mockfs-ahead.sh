#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/mockfs-ahead.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
F=/home/unixnu/code/umi-work-pin/tools/build_umi_xnu.py
R=/home/unixnu/code/UniXNU-umi
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree

say "== 1. 仓库内所有 SOURCE_MOCKFS / mockfs 消费者 =="
grep -rn 'SOURCE_MOCKFS\|mockfs' "$R" --include=*.py --include=*.sh --include=*.toml 2>/dev/null | grep -v '/out/' | head -30 >> "$OUT"

say
say "== 2. build_umi_xnu.py 315..400（kernel 步之后）=="
sed -n '315,400p' "$F" >> "$OUT" 2>&1

say
say "== 3. baseline 脚本里 MOCKFS 的全部出现 =="
grep -n 'MOCKFS' "$T/scripts/build-xnu-4k-baseline.sh" >> "$OUT" 2>&1

say
say "== 4. board.toml 的 bootargs 相关键 =="
grep -nE 'boot_arg|bootarg|args|rd=|root=' "$R/board.toml" 2>/dev/null | head -20 >> "$OUT"
say "-- 上游 sheng 板的 bootargs 写法 --"
grep -rnE 'boot_arg|rd=' "$R/../UniXNU-main/devices"/*/board.toml 2>/dev/null | head -10 >> "$OUT"
say done
