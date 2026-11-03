#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/uuid-gate.txt
{
  echo "== tree top level =="
  ls "$X" 2>/dev/null | head -20
  echo "== locate files =="
  find "$X" -maxdepth 4 -name 'IOPlatformExpertDevice.cpp' 2>/dev/null
  find "$X" -maxdepth 4 -name 'kern_security.c' 2>/dev/null
  find "$X" -maxdepth 5 -name 'IOCryptoCmd?*Storage*' 2>/dev/null | head
  echo "== g_crypto_funcs definition =="
  grep -rn "g_crypto_funcs" "$X" --include=*.c --include=*.cpp --include=*.h 2>/dev/null | head -12
  echo "== crypto_add_kext callers =="
  grep -rn "crypto_add_kext" "$X" --include=*.c --include=*.cpp 2>/dev/null | head -12
  echo "== platform-uuid readers =="
  grep -rn "platform-uuid\|platform_uuid\|PlatformUUID" "$X/iokit" "$X/osfmk" 2>/dev/null | head -25
  echo "== running.dtb: any uuid =="
  D=$(find "$WS" -name 'running.dtb' 2>/dev/null | head -1)
  echo "dtb=$D"
  strings -a "$D" 2>/dev/null | grep -i "uuid" | head -10
} > "$O" 2>&1
echo done
