#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin
K=$W/out/umi-xnu/umi/kernel/source-kernel.macho
OUT=/mnt/e/Code/HackIos/out/probes/a2l.txt
export PATH=/usr/lib/llvm-18/bin:$PATH
{
  echo "== llvm-addr2line 可用性"
  command -v llvm-addr2line || echo "没有 llvm-addr2line"
  echo "== 停点源码行（LR-4 还原调用点）"
  for a in 0xfffffff007427fa4 0xfffffff00728b024 0xfffffff007a08000 0xfffffff00798bb2c 0xfffffff0076f4894; do
    echo "--- $a"
    llvm-addr2line -e "$K" -f -C -i "$a" 2>&1 | head -6
  done
  echo "== 内核里有没有 DWARF"
  otool -l "$K" 2>/dev/null | grep -A2 '__DWARF' | head -8 || echo "otool 不可用"
} > "$OUT" 2>&1
echo WROTE
