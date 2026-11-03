#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
OUT=$WS/out/stuck2.txt
: > "$OUT"
echo "== grep binary for 'onee' ==" >> "$OUT"
grep -a -o -E '.{0,40}onee.{0,40}' "$K" >> "$OUT" 2>&1 | head -20
echo "== grep binary for 'template ki' / 'kernel bootstrap' ==" >> "$OUT"
grep -a -o -E '.{0,30}template.{0,30}' "$K" >> "$OUT" 2>&1 | grep -a -i 'ki\|onee' | head -20
echo "== nm: sysctl_register symbols ==" >> "$OUT"
llvm-nm --defined-only "$K" 2>/dev/null | grep -a sysctl_register >> "$OUT"
echo "== source: who calls sysctl_register_oid_early ==" >> "$OUT"
X=$WS/.cache/xnu-work
grep -rn "sysctl_register_oid_early" "$X" --include=*.c --include=*.h >> "$OUT" 2>&1 | head -30
echo "== source: startup.c dispatch loop ==" >> "$OUT"
grep -n "last_func\|cur->func\|cur->message\|kernel_bootstrap_log\|startup_threads\|boot_threads" "$X/osfmk/kern/startup.c" >> "$OUT" 2>&1 | head -60
echo "== source: table entry containing sysctl ==" >> "$OUT"
grep -n "sysctl" "$X/osfmk/kern/startup.c" >> "$OUT" 2>&1 | head -20
echo DONE >> "$OUT"
cp "$OUT" /mnt/e/Code/HackIos/out/stuck2.txt
echo copied
