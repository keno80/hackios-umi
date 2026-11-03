#!/bin/bash
set -u
LOG=/mnt/e/Code/HackIos/out/ramconsole-patches.txt
P=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/patches/umi-xnu
{
  echo "########## zz-console-trace.patch"
  cat "$P/zz-console-trace.patch"
  echo "########## early-entry-trace.patch"
  cat "$P/early-entry-trace.patch"
  echo "########## z-early-entry-detail.patch"
  cat "$P/z-early-entry-detail.patch"
} > "$LOG" 2>&1
