#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
P=/home/unixnu/code/umi-work-pin/devices/umi/patches/umi-xnu/zzzzzzzzzzzzzzzzzz-umi-crypto-kit.patch
O=/mnt/e/Code/HackIos/out/probes/pe-hook-state.txt
{
  echo "== patch: file headers and hunks =="
  grep -n '^---\|^+++\|^@@' "$P"
  echo "== patch: umi lines =="
  grep -n 'umi_crypto_kit_register' "$P"
  echo "== tree pe_init.c lines 1-20 =="
  sed -n '1,20p' "$W/pexpert/arm/pe_init.c" | cat -n
  echo "== tree pe_init.c lines 385-395 =="
  sed -n '385,395p' "$W/pexpert/arm/pe_init.c" | cat -n
  echo "== tree: any umi_crypto_kit_register? =="
  grep -n 'umi_crypto_kit_register' "$W/pexpert/arm/pe_init.c"
  echo "== how replay applies patches =="
  grep -rn 'patches/umi-xnu\|git apply\|patch -p\|--fuzz' /home/unixnu/code/umi-work-pin/tools/build_umi_xnu.py /home/unixnu/code/umi-work-pin/devices/umi/scripts/*.py 2>/dev/null | head -20
} > "$O" 2>&1
echo done
