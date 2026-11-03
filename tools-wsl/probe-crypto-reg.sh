#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/crypto-reg.txt
D=$WS/out/umi/dtb/umi-running.dtb
{
  echo "== register_crypto.c 20-70 =="
  sed -n '20,70p' "$X/libkern/crypto/register_crypto.c"
  echo "== callers of the setter =="
  grep -rn "crypto_init (" "$X" --include=*.c --include=*.cpp 2>/dev/null | head -10
  grep -rn "crypto_init\b" "$X" --include=*.c --include=*.cpp --include=*.h 2>/dev/null | grep -v register_crypto | head -15
  echo "== who supplies crypto_functions / kit =="
  grep -rn "crypto_functions_t\|ccsha1_di *=" "$X" --include=*.c --include=*.cpp 2>/dev/null | head -15
  echo "== dtc available? =="
  which dtc fdtdump 2>/dev/null
  echo "== running dtb: chosen props =="
  dtc -I dtb -O dts "$D" 2>/dev/null > /tmp/run.dts
  wc -l < /tmp/run.dts
  grep -n "unique-chip-id\|chip-id" /tmp/run.dts | head -10
  echo "== chosen node =="
  awk '/^ *chosen \{/,/^\t\};/' /tmp/run.dts | head -30
  echo "== adt props =="
  A=$(find "$WS/out" -name 'kernel.macho.adt' 2>/dev/null | head -1)
  echo "adt=$A"
  strings -a "$A" 2>/dev/null | grep -i "chip-id\|chosen" | head -10
} > "$O" 2>&1
echo done
