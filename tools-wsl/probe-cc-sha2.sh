#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
O=/mnt/e/Code/HackIos/out/cc-sha2.txt
{
  echo "== sha2 / final / rng symbols =="
  llvm-nm --defined-only "$K" 2>/dev/null | awk '{print $3}' | grep -E "sha2|_final|ccrng|ccn_|ccmode" | sort | head -40
  echo "== all cc14_ symbols =="
  llvm-nm --defined-only "$K" 2>/dev/null | awk '{print $3}' | grep "^_cc14_" | sort | head -40
  echo "== count cc14 =="
  llvm-nm --defined-only "$K" 2>/dev/null | awk '{print $3}' | grep -c "^_cc14_"
  echo "== ccdigest.c functions in tree =="
  grep -n "^void\|^int\|ccdigest_final" "$WS/out/umi-xnu/umi/tree/.cache/xnu-work/osfmk/corecrypto/ccdigest.c" | head -20
  echo "== is ccsha2.c present/compiled? =="
  ls "$WS/out/umi-xnu/umi/tree/.cache/xnu-work/osfmk/corecrypto" | grep -i sha
} > "$O" 2>&1
echo done
