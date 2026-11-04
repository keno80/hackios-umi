#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/crypto-who.txt
{
  echo "== register_crypto_functions callers =="
  grep -rn "register_crypto_functions" "$X" --include=*.c --include=*.cpp 2>/dev/null | head -10
  echo "== their STARTUP phase (context) =="
  for f in $(grep -rln "register_crypto_functions" "$X" --include=*.c --include=*.cpp 2>/dev/null | grep -v register_crypto.c); do
    echo "--- $f"
    grep -n "STARTUP\|register_crypto_functions" "$f" | head -12
  done
  echo "== who authors unique-chip-id in unixnu repo =="
  grep -rn "unique-chip-id" "$WS" --include=*.py --include=*.toml --include=*.json --include=*.c --include=*.dts --include=*.adt 2>/dev/null | head -10
  echo "== adt file listing =="
  A=$WS/out/umi/xnu/stage2/EFI/UniXNU/Payloads/kernel.macho.adt
  ls -l "$A"
  strings -a "$A" | head -40
} > "$O" 2>&1
echo done
