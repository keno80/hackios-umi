#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/rand-hdr.txt
{
  echo "== libkern/crypto/rand.h =="
  cat -n "$W/libkern/libkern/crypto/rand.h"
  echo "== vm_kern.c 2840-2865 =="
  sed -n '2840,2865p' "$W/osfmk/vm/vm_kern.c" | cat -n
} > "$O" 2>&1
echo done
