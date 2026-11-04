#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/cc14.txt
{
  echo "== cc14 references in work pin (non-binary) =="
  grep -rIn "cc14" "$WS/devices" "$X/libkern" "$X/osfmk" 2>/dev/null | head -25
  echo "== struct crypto_functions full text =="
  awk '/struct crypto_functions/,/crypto_functions_t;|} crypto_functions/' "$X/libkern/libkern/crypto/crypto.h" | head -80
  echo "== provider registration shim anywhere? =="
  grep -rIn "kernel_provider_registered" "$WS/devices" 2>/dev/null | head -10
} > "$O" 2>&1
echo done
