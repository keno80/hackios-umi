#!/bin/bash
# 跑长脚本前先做语法闸：bash -n 过了再放行，避免半路 syntax error 白等几分钟。
set -u
O=/mnt/e/Code/HackIos/out/probes/check-syntax.txt
P=${1:?用法: check-syntax.sh <脚本>}
{
  echo "== bash -n $P =="
  if bash -n "$P"; then echo "SYNTAX-OK"; exit 0; else echo "SYNTAX-BAD"; exit 1; fi
} >> "$O" 2>&1
