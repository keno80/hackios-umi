#!/bin/bash
set -u
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped
NM=/usr/lib/llvm-18/bin/llvm-nm
{
echo "== nm version =="
$NM --version | head -2
echo "== bare nm sample =="
$NM "$K" 2>&1 | head -5
echo "== nm grep ccaes sample =="
$NM "$K" 2>&1 | grep -i ccaes | head -10
echo "== nm -no-sort grep =="
$NM -no-sort "$K" 2>&1 | grep -i ccaes | head -10
echo "== objdump -t grep =="
/usr/lib/llvm-18/bin/llvm-objdump -t "$K" 2>&1 | grep -i ccaes_cbc | head -10
} > /mnt/e/Code/HackIos/out/probes/nm-probe.txt 2>&1
