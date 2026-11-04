#!/bin/bash
set -u
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/startup_region.txt
{
echo "===== startup.c 200..270 ====="
sed -n '200,270p' "$X/osfmk/kern/startup.c" | cat -n | sed 's/^/   /'
echo "===== startup.c 360..470 ====="
awk 'NR>=360 && NR<=470 {printf "%4d  %s\n", NR, $0}' "$X/osfmk/kern/startup.c"
echo "===== startup.c 180..200 ====="
awk 'NR>=180 && NR<=200 {printf "%4d  %s\n", NR, $0}' "$X/osfmk/kern/startup.c"
echo "===== sysctl.h 405..450 ====="
awk 'NR>=405 && NR<=450 {printf "%4d  %s\n", NR, $0}' "$X/bsd/sys/sysctl.h"
echo "===== startup.h struct startup_entry ====="
grep -n -A14 "struct startup_entry" "$X/osfmk/kern/startup.h" | head -40
} > "$O" 2>&1
echo copied
