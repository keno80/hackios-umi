#!/bin/bash
set -u
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
F=$X/iokit/Kernel/IOPlatformExpert.cpp
O=/mnt/e/Code/HackIos/out/genuuid-src.txt
{
  echo "== IOPlatformExpert.cpp 2200-2300 =="
  sed -n '2200,2300p' "$F" | cat -n | sed 's/^/    /'
  echo "== who calls generatePlatformUUID at 2185 (context 2160-2200) =="
  sed -n '2160,2200p' "$F"
} > "$O" 2>&1
echo done
