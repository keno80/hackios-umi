#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
O=/mnt/e/Code/HackIos/out/panic-rev4.txt
PC=fffffff0078dcb3c
LR=fffffff00794701c
X3=fffffff00789841c
X8=fffffff0071c8000
X1=fffffff007b00060
X16=fffffff0070099ee
{
  echo "== kernel sha =="
  sha256sum "$K" | cut -c1-16
  llvm-nm -n --defined-only "$K" 2>/dev/null > /tmp/ks4.txt
  wc -l < /tmp/ks4.txt
  echo "== symbol of pc =="
  awk -v t="$PC" '$1<=t' /tmp/ks4.txt | tail -4
  echo "== symbol of lr =="
  awk -v t="$LR" '$1<=t' /tmp/ks4.txt | tail -4
  echo "== symbol of x3 =="
  awk -v t="$X3" '$1<=t' /tmp/ks4.txt | tail -3
  echo "== symbol of x8 =="
  awk -v t="$X8" '$1<=t' /tmp/ks4.txt | tail -3
  echo "== symbol of x1 =="
  awk -v t="$X1" '$1<=t' /tmp/ks4.txt | tail -3
  echo "== symbol of x16 =="
  awk -v t="$X16" '$1<=t' /tmp/ks4.txt | tail -3
  echo "== disasm around pc =="
  llvm-objdump -d --start-address=0xfffffff0078dca80 --stop-address=0xfffffff0078dcb80 "$K" 2>/dev/null | tail -50
  echo "== disasm around lr (caller) =="
  llvm-objdump -d --start-address=0xfffffff007946fd0 --stop-address=0xfffffff007947030 "$K" 2>/dev/null | tail -30
} > "$O" 2>&1
echo done
