#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/panic_rev3.txt
PC=fffffff007a1c398
LR=fffffff0073f35a0
FAR=fffffff040cffac3
{
echo "== kernel sha =="
sha256sum "$K" | cut -c1-16
echo "== segments =="
llvm-objdump -h "$K" 2>/dev/null | head -25
echo "== symbol of pc =="
llvm-nm -n --defined-only "$K" 2>/dev/null > /tmp/ks.txt
awk -v t="$PC" '$1<=t' /tmp/ks.txt | tail -3
echo "== symbol of lr =="
awk -v t="$LR" '$1<=t' /tmp/ks.txt | tail -3
echo "== disasm around pc =="
llvm-objdump -d --start-address=0xfffffff007a1c360 --stop-address=0xfffffff007a1c3c0 "$K" 2>/dev/null | tail -30
echo "== disasm around lr (caller) =="
llvm-objdump -d --start-address=0xfffffff0073f3540 --stop-address=0xfffffff0073f35c0 "$K" 2>/dev/null | tail -40
echo "== unaligned-abort wording in sleh =="
grep -rn "Unaligned kernel\|Alignment fault\|kernel data abort" "$X/osfmk/arm64/sleh.c" | head -10
} > "$O" 2>&1
echo done
