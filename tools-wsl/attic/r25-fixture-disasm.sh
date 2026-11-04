#!/bin/bash
# R 步之十六：r24 里 `mov x16, #-28` 编成 0x92800370 = MOVN x16, #27 → x16 = -28，方向对了；
# 同时发现本机其实有 aarch64-linux-gnu-objdump。这版直接反汇编整段 __text，
# 把每一发的 x16 值与 svc 顺序列出来，作为出图前的静态闸。
set -u
O=/mnt/e/Code/HackIos/out/probes/r25-fixture-disasm.txt
: > "$O"; exec >>"$O" 2>&1
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CLT=$TC/CommandLineTools/usr
F=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho
W=/tmp/fx-dis2
rm -rf "$W"; mkdir -p "$W"
OD=aarch64-linux-gnu-objdump

echo "== 1. __text 的 addr/size/offset =="
"$CLT/bin/otool" -l "$F" 2>/dev/null | grep -A6 'sectname __text' | tee "$W/sec.txt"
ADDR=$(awk '/addr /{print $2; exit}' "$W/sec.txt")
SIZE=$(awk '/size /{print $2; exit}' "$W/sec.txt")
OFF=$(awk '/offset /{print $2; exit}' "$W/sec.txt")
echo "ADDR=$ADDR SIZE=$SIZE OFF=$OFF"
SIZE=$((SIZE))   # dd 不吃十六进制

echo
echo "== 2. 反汇编 =="
dd if="$F" of="$W/text.bin" bs=1 skip="$OFF" count="$SIZE" status=none
"$OD" -D -b binary -m aarch64 --adjust-vma="$ADDR" "$W/text.bin" > "$W/text.asm" 2>&1
echo "--- objdump 头 15 行（失败就把错误打出来）---"
head -15 "$W/text.asm"
printf 'svc=%s  x16 写=%s\n' "$(grep -c 'svc' "$W/text.asm")" "$(grep -c 'x16' "$W/text.asm")"

echo
echo "== 3. 逐发序列（x16 的值 + 紧随的 svc）=="
grep -E "x16|svc" "$W/text.asm" | sed -e 's/^[[:space:]]*//' | awk '{print}' | head -80

echo
echo "== 4. mach 段（应为 -28 -29 -27 -26 -89 -16 -19 -18 -31 九个负号）=="
grep -E "movn|sub.*x16" "$W/text.asm" | sed -e 's/^[[:space:]]*//'
echo "== done $(date -u +%FT%TZ)"
