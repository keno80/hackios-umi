#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin
export PATH=/opt/unixnu-linux/CommandLineTools/usr/bin:/opt/unixnu-linux/bin:/usr/local/bin:/usr/bin:/bin
cd "$W"
OUT=/mnt/e/Code/HackIos/out/probes/sym-all.txt
{
  echo "== run 列表"
  ls -1 out/umi-qemu/
  for d in out/umi-qemu/*/; do
    [ -f "$d/gdb-stop.json" ] || continue
    echo
    echo "########## $d"
    python3 /usr/local/bin/umi-sym.py "$d" out/umi-xnu/umi/kernel/source-kernel.macho 2>&1 | head -45
  done
} > "$OUT" 2>&1
wc -l "$OUT"
