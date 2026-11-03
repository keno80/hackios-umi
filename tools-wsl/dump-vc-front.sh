#!/bin/bash
set -u
VC=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/osfmk/console/video_console.c
O=/mnt/e/Code/HackIos/out/vc_front.txt
total=$(wc -l < "$VC")
{
  echo "TOTAL=$total"
  echo "----- 3305..3375 -----"
  sed -n '3305,3375p' "$VC" | nl -ba -v 3305
  echo "----- 3372..3380 -----"
  sed -n '3372,3380p' "$VC" | nl -ba -v 3372
} > "$O"
echo "written total=$total"
