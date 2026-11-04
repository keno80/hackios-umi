#!/bin/bash
set -u
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
OUT=/mnt/e/Code/HackIos/out/probes/stuck4.txt
{
echo "== startup.c: umi patch sites =="
grep -n "umi_screen" "$X/osfmk/kern/startup.c"
echo "== startup.c: dispatch loop context =="
grep -n "last_func\|cur->func\|cur->message\|cur->arg\|kernel_bootstrap_thread\|boot_progress\|static struct\|\*cur" "$X/osfmk/kern/startup.c" | head -60
echo "== startup.c: sysctl table entries =="
grep -n "sysctl" "$X/osfmk/kern/startup.c"
echo "== kern_sysctl.c: sysctl_register_oid_early def/uses =="
grep -rn "sysctl_register_oid_early" "$X/bsd" "$X/osfmk" 2>/dev/null | head -20
echo "== kernel_bootstrap_log def =="
grep -rn "kernel_bootstrap_log" "$X/osfmk" "$X/bsd" 2>/dev/null | head -20
} > "$OUT" 2>&1
echo copied
