#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/crypto-kit-pattern.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
W=/home/unixnu/code/umi-work-pin
X=$W/out/umi-xnu/umi/tree/.cache/xnu-work

say "== 1. umi-xnu 补丁清单（尾部几个）=="
ls -1 "$W/devices/umi/patches/umi-xnu/" 2>/dev/null | tail -18 >> "$OUT"

say
say "== 2. crypto kit 补丁的注册点（install 调用在哪）=="
P=$(ls -t "$W/devices/umi/patches/umi-xnu/"*crypto* 2>/dev/null | head -1)
say "P=$P"
grep -n 'install\|+++\|@@' "$P" 2>/dev/null | head -25 >> "$OUT"
say "-- 补丁正文前 40 行 --"
sed -n '1,40p' "$P" >> "$OUT" 2>&1

say
say "== 3. 尾件源文件在哪（tail .c 如何进构建）=="
grep -rn 'crypto_kit\|g_crypto_funcs' "$W/tools/build_umi_xnu.py" 2>/dev/null | head -12 >> "$OUT"
grep -rln 'umi_crypto_kit' "$W" --include='*.py' --include='*.c' --include='*.patch' 2>/dev/null | head -8 >> "$OUT"

say
say "== 4. amfi_interface_register 的调用者 =="
grep -rn 'amfi_interface_register' "$X" --include='*.c' --include='*.cpp' 2>/dev/null | head -10 >> "$OUT"
say done
