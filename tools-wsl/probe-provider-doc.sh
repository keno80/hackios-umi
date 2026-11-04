#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
O=/mnt/e/Code/HackIos/out/probes/provider-doc.txt
{
  echo "== docs/tools mentioning provider registration =="
  grep -rIn "kernel_provider_registered\|register_crypto\|provider_registered" "$WS/devices" "$WS/tools" "$WS/docs" 2>/dev/null | head -20
  echo "== build env for crypto =="
  grep -rIn "XNU_SOURCE_CORECRYPTO14" "$WS/tools" "$WS/devices" 2>/dev/null | head -12
  echo "== crypto mode values =="
  grep -rIn "crypto=prelinked\|XNU_CRYPTO" "$WS/tools" "$WS/devices" 2>/dev/null | head -12
} > "$O" 2>&1
echo done
