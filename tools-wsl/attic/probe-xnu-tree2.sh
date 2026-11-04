#!/bin/bash
set -u
LOG=/mnt/e/Code/HackIos/out/probes/xnu-tree2.txt
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
{
  echo "== tree 顶层"
  ls "$T" | head -20
  echo "== 找 sbm.c / platform.c / debug.c"
  timeout 240 find "$T" -name 'sbm.c' -o -name 'platform.c' -o -name 'debug.c' 2>/dev/null | grep -v '\.git' | head -12
  echo "== 构建中间产物（增量重编要看这个）"
  ls -d "$T"/*/build 2>/dev/null | head
  echo "== source-build-status.json"
  cat /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/source-build-status.json 2>/dev/null | head -30
  echo "== 内核构建日志最后 25 行"
  ls -t /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/logs/ 2>/dev/null | head -6
} > "$LOG" 2>&1
