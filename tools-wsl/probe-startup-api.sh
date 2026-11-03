#!/bin/bash
set -u
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/startup-api.txt
{
  echo "== ccdigest.h 60-110 =="
  sed -n '60,110p' "$X/EXTERNAL_HEADERS/corecrypto/ccdigest.h"
  echo "== vm_kern.c kmem_crypto_init =="
  sed -n '2575,2600p' "$X/osfmk/vm/vm_kern.c"
  echo "== STARTUP macro =="
  grep -n "define STARTUP\|__STARTUP\|struct startup_" "$X/osfmk/kern/startup.h" | head -20
  echo "== EARLY_BOOT phase names =="
  grep -n "EARLY_BOOT\|STARTUP_RANK" "$X/osfmk/kern/startup.h" | head -20
} > "$O" 2>&1
echo done
