#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/pe-init-ctx.txt
{
  echo "== pe_init.c 330-400 =="
  sed -n '330,400p' "$W/pexpert/arm/pe_init.c" | cat -n
  echo "== who calls pe_init =="
  grep -rn 'pe_init' "$W/osfmk" --include=*.c --include=*.h --include=*.S 2>/dev/null | head -12
  echo "== umi marker helpers visible outside libkern/startup.c =="
  grep -rn 'umi_screen_mark\|umi_screen_text\|umi_early_trace' "$W" --include=*.c --include=*.h 2>/dev/null | head -25
  echo "== startup.c 735-765 =="
  sed -n '735,765p' "$W/osfmk/kern/startup.c" | cat -n
} > "$O" 2>&1
echo done
