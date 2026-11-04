#!/bin/bash
# N 步之十：thread_bootstrap_return 的 arm64 汇编体，本地与上游逐字对照。
# 这里就是「子线程第一次回 EL0 时 x0 是什么」的落点。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n23-bootret-body.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
L=$X/osfmk/arm64/locore.s
U=/tmp/up-locore.s

echo "== 1. 本地 1270-1340 =="
sed -n '1270,1340p' "$L" | grep -n ''

echo
echo "== 2. 上游 1762,1832 =="
sed -n '1762,1832p' "$U" | grep -n ''

echo
echo "== 3. 差异（把上游的 LEXT 段与本地同段做纯文本 diff）=="
sed -n '/LEXT(thread_bootstrap_return)/,/^\s*\.globl\s*EXT(load_context)/p' "$L" > /tmp/loc-boot.s
sed -n '/LEXT(thread_bootstrap_return)/,/^\s*\.globl\s*EXT(load_context)/p' "$U" > /tmp/up-boot.s
wc -l /tmp/loc-boot.s /tmp/up-boot.s
diff -u /tmp/up-boot.s /tmp/loc-boot.s | head -60

echo
echo "== 4. 本地 return_from_trap / machine_load_context 里 x0 的写法 =="
grep -n 'x0' "$L" | sed -n '1,25p'
echo "-- sleh.c 中 return_from_trap 相关（asm 里叫 _return_from_trap？）--"
grep -rn 'return_from_trap' "$X/osfmk/arm64/" | head -8

echo
echo "== 5. 上游 thread_bootstrap_return 之后紧跟的 return_from_trap 体（本地）=="
A=$(grep -n 'LEXT(return_from_trap)' "$L" | head -1 | cut -d: -f1)
echo "@$A"
[ -n "$A" ] && sed -n "$((A-2)),$((A+45))p" "$L"
echo done
