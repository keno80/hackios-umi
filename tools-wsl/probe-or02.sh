#!/bin/bash
# 探第一趟死在哪一步、clang 为什么崩
set -u
LOGD=/home/unixnu/code/umi-work-pin/out/umi-xnu-build
STEPS=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/logs/20261103T062720673628Z
OUT=/mnt/e/Code/HackIos/out/probes/or02-probe.txt
{
  echo "== 外层日志全文"
  cat "$LOGD/or-02-bootstrap.log"
  echo
  echo "== 步日志列表"
  ls -l "$STEPS"
  echo
  echo "== 每个步日志尾部 5 行"
  for f in "$STEPS"/*.log; do
    echo "---- $f"
    tail -5 "$f"
  done
  echo
  echo "== native-ufs.log 里的错误区"
  grep -n "error:\|Assertion\|PLEASE submit\|Stack dump\|fatal" "$STEPS/native-ufs.log" 2>/dev/null | head -20
  echo
  echo "== native-ufs.log 崩点上下文"
  n=$(grep -n "PLEASE submit" "$STEPS/native-ufs.log" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -n "$n" ]; then sed -n "$((n > 40 ? n - 40 : 1)),$((n + 25))p" "$STEPS/native-ufs.log"; fi
} > "$OUT" 2>&1
echo WROTE
