#!/bin/bash
set -u
O=/mnt/e/Code/HackIos/out/probes/build3.txt
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
D=$(cat "$LOGD/kernel-screen-latest.txt")
PID=$(cat "$LOGD/kernel-screen.pid")
L=$(ls -t /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/logs/*/kernel.log | head -1)
{
  echo "== driver: $D =="
  if kill -0 "$PID" 2>/dev/null; then echo "STATE=RUNNING pid=$PID etime=$(ps -o etime= -p $PID | tr -d ' ')"; else echo "STATE=EXITED pid=$PID"; fi
  echo "SIZE=$(stat -c %s "$D")"
  echo "== step log: $L =="
  ls -l "$L"
  echo "== our files =="
  grep -naE 'register_crypto\.c:[0-9]+|pe_init\.c:[0-9]+:(fatal|error|warning: implicit)' "$L" | tail -12
  echo "== fatal/error/make =="
  grep -naE 'fatal error|error: |\*\*\* \[|Undefined symbols|undefined symbol' "$L" | tail -20
  echo "== progress markers =="
  grep -naE 'LDFILELIST|kernel\.macho|IM4P|== ' "$L" | tail -8
  echo "== driver tail =="
  tail -18 "$D"
} > "$O" 2>&1
echo done
