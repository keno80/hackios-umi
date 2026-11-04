#!/bin/bash
set -u
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
O=/mnt/e/Code/HackIos/out/probes/sha1-gate.txt
G=fffffff0071c81a8
{
  echo "== globals around 0x$G =="
  llvm-nm -n --defined-only "$K" 2>/dev/null | awk -v t="$G" '$1>=t' | head -6
  echo "-- before --"
  llvm-nm -n --defined-only "$K" 2>/dev/null | awk -v t="$G" '$1<=t' | tail -6
  echo "== generatePlatformUUID source =="
  find "$X/iokit" -name 'IOPlatformExpertDevice.cpp' 2>/dev/null
  F=$(find "$X/iokit" -name 'IOPlatformExpertDevice.cpp' 2>/dev/null | head -1)
  awk '/generatePlatformUUID/,/^}/' "$F" | head -60
  echo "== where do SHA1Init / sha1_init come from =="
  grep -rln "SHA1Init" "$X/osfmk" 2>/dev/null | head -10
  echo "== sha1 sources in tree =="
  find "$X" -name 'sha1*.c' -o -name 'sha*.c' 2>/dev/null | head -20
} > "$O" 2>&1
echo done
