#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
O=/mnt/e/Code/HackIos/out/probes/panic_sym.txt
llvm-nm -n --defined-only "$K" 2>/dev/null > /tmp/kalls.txt
{
echo "== total symbols =="
wc -l < /tmp/kalls.txt
echo "== lr 0xfffffff00794601c =="
awk '$1 <= "fffffff00794601c"' /tmp/kalls.txt | tail -1
grep -n "fffffff00794601c" /tmp/kalls.txt | head -2
echo "-- neighborhood of lr --"
n=$(grep -n " $(printf '')" /dev/null; grep -n "^fffffff007946" /tmp/kalls.txt | head -1 | cut -d: -f1)
sed -n "$((n-4)),$((n+4))p" /tmp/kalls.txt
echo "== pc candidates in 0xfffffff0078d8000..0xfffffff0078db000 =="
awk '{a=strtonum("0x" $1); if (a>=0xfffffff0078d6000 && a<=0xfffffff0078dc000) print}' /tmp/kalls.txt 2>/dev/null | head -40
echo "== fallback: string slice =="
awk '$1>="fffffff0078d6000" && $1<="fffffff0078dc000"' /tmp/kalls.txt | head -60
echo "== panic format string in source =="
grep -rn "Kernel %s abort\|Kernel data abort\|saved state: %p" /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/osfmk/arm64/ 2>/dev/null | head -10
} > "$O" 2>&1
echo copied
