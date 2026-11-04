#!/bin/bash
set -u
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/check-tail-calls.txt
{
  echo "== remaining bcopy/memmove/memcpy in painter tail =="
  awk '/UMI_SCR_SCALE_MAX/,0' "$X/osfmk/console/video_console.c" | grep -n "bcopy\|memmove\|memcpy"
  echo "== every libc-ish call made from painter tail =="
  awk '/UMI_SCR_SCALE_MAX/,0' "$X/osfmk/console/video_console.c" | grep -n "\bbcopy(\|\bmemcpy(\|\bmemmove(\|\bstrlen(\|\bsnprintf(\|\bbzero(" | head -20
} > "$O" 2>&1
echo done
