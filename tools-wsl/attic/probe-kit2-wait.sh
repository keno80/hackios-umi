#!/bin/bash
# 等内核编译结束（最多 25 分钟），然后汇总状态
set -u
OUT=/mnt/e/Code/HackIos/out
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
D=$(cat "$LOGD/kernel-screen-latest.txt" 2>/dev/null)
PID=$(cat "$LOGD/kernel-screen.pid" 2>/dev/null)
i=0
while [ $i -lt 75 ]; do
  if ! kill -0 "$PID" 2>/dev/null; then break; fi
  sleep 20; i=$((i+1))
done
{
  echo "== waited=$((i*20))s driver=$D pid=$PID"
  if kill -0 "$PID" 2>/dev/null; then echo "STATE=RUNNING etime=$(ps -o etime= -p $PID | tr -d ' ')"; else echo "STATE=EXITED"; fi
  echo "SIZE=$(stat -c %s "$D" 2>/dev/null)"
  S=$(ls -t /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/logs/*/kernel.log 2>/dev/null | head -1)
  echo "== step log $S"
  ls -l "$S" 2>&1
  echo "== 我们的文件相关"
  grep -naE 'register_crypto\.c:[0-9]+:[0-9]+: (fatal error|error|warning)|pe_init\.c:[0-9]+:[0-9]+: (fatal error|error)' "$S" 2>/dev/null | tail -12
  echo "== error/undefined"
  grep -naE 'fatal error|error: |\*\*\* \[|Undefined symbols|undefined symbol' "$S" 2>/dev/null | tail -20
  echo "== driver tail"
  tail -20 "$D" 2>/dev/null | tr -cd '\11\12\40-\176'
} > "$OUT/kit2-status.txt" 2>&1
echo done
