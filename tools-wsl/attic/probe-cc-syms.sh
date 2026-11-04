#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/cc-syms.txt
{
  echo "== in-tree corecrypto symbols needed for the kit =="
  for s in ccdigest_init ccdigest_update ccdigest_final ccdigest ccmd5_di ccsha1_di \
           ccsha2_256_di ccsha2_384_di ccsha2_512_di cchmac_init cchmac_update \
           cchmac_final cchmac ccrng_system_rnd_get; do
    printf "%-24s " "$s"
    llvm-nm --defined-only "$K" 2>/dev/null | grep -E "_(^| )$s\$|_s _$s\$" | head -1
    llvm-nm --defined-only "$K" 2>/dev/null | awk -v n="_$s" '$2=="S"||$2=="s"||$2=="T"{if($3==n)print "FOUND "$1}' | head -1
  done
  echo "== exact-name pass =="
  llvm-nm --defined-only "$K" 2>/dev/null | awk '{print $3}' | grep -x -E \
    "_ccdigest_init|_ccdigest_update|_ccdigest_final|_ccdigest|_ccmd5_di|_ccsha1_di|_ccsha2_256_di|_ccsha2_384_di|_ccsha2_512_di|_cchmac_init|_cchmac_update|_cchmac_final|_cchmac" | sort
  echo "== STARTUP include used by vm_kern.c =="
  grep -n "startup.h" "$X/osfmk/vm/vm_kern.c" | head -3
  echo "== how patches get generated =="
  grep -rln "patches/umi-xnu" /mnt/e/Code/HackIos/tools-wsl 2>/dev/null | head -10
} > "$O" 2>&1
echo done
