#!/bin/bash
set -u
O=/mnt/e/Code/HackIos/out/probes/mkcrypto.txt
{
  echo "== tail file hygiene =="
  T=/mnt/e/Code/HackIos/tools-wsl/umi_crypto_kit_tail.c
  echo "trailing-space lines: $(grep -c ' \+$' "$T")"
  echo "CR present: $(grep -c $'\r' "$T")"
  echo "tab-indented lines: $(grep -c $'\t' "$T")"
  sed -n '1,3p;20,26p' "$T" | cat -A | head -12
  echo "== run generator =="
  tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/make-crypto-patch.py > /tmp/mk.py
  python3 /tmp/mk.py
  echo "== patch head =="
  head -20 /home/unixnu/code/umi-work-pin/devices/umi/patches/umi-xnu/zzzzzzzzzzzzzzzzzz-umi-crypto-kit.patch
} > "$O" 2>&1
echo done
