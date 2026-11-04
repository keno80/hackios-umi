#!/bin/bash
set -u
LOG=/mnt/e/Code/HackIos/out/probes/xnu-tree.txt
{
  for d in /home/unixnu/code/UniXNU-umi /home/unixnu/code/umi-work /home/unixnu/code/UniXNU-pin /home/unixnu/code/UniXNU /home/unixnu/code/umi-work-pin; do
    echo "== $d"
    ls "$d" 2>/dev/null | head -12 | tr '\n' ' '
    echo
    ls -d "$d"/.cache/*/ 2>/dev/null | head -6
  done
  echo "== 全盘找 sbm.c（限时 300s，排除 /proc /sys）"
  timeout 300 find /home/unixnu -name 'sbm.c' -not -path '*/\.git/*' 2>/dev/null | head -5
  echo "== 找 xnu 顶层特征文件 bsd/Makefile"
  timeout 300 find /home/unixnu -maxdepth 5 -type d -name 'xnu*' 2>/dev/null | head -10
} > "$LOG" 2>&1
