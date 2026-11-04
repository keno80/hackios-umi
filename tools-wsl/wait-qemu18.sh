#!/bin/bash
# 等 run-18-boot-stage 的 screen.png 落地，然后与基线 sha 比对并 OCR 关键行。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/f-qemu18.txt
: > "$OUT"
exec >>"$OUT" 2>&1
WS=/home/unixnu/code/umi-work-pin
D=$WS/out/umi-qemu/run-18-boot-stage
BASE=717d84387892fe668ba513eb66f89c3c8da61bc44fdb96085390fd28de8dfaf6
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
start=$(date +%s)
while [ ! -f "$D/screen.png" ]; do
  el=$(( $(date +%s) - start ))
  if [ "$el" -gt 600 ]; then echo "TIMEOUT 等 screen.png ${el}s"; break; fi
  sleep 15
  echo "[$el s] $(tail -2 "$LOGD/qemu-run-18-boot-stage.launch.log" 2>/dev/null | tr -d '\r' | tr '\n' ' ' | cut -c1-140)"
done
echo "== 用时 $(( $(date +%s) - start )) s =="
echo
echo "== run 目录 =="
ls -la "$D" 2>&1
echo
echo "== screen.png sha =="
if [ -f "$D/screen.png" ]; then
  S=$(sha256sum "$D/screen.png" | cut -d' ' -f1)
  echo "$S"
  if [ "$S" = "$BASE" ]; then echo "VERDICT SAME-AS-BASELINE（FAIL：屏幕没变）"; else echo "VERDICT CHANGED（PASS：屏幕有新内容）"; fi
else
  echo "NO-SCREEN"
fi
echo
echo "== gdb-stop.json 关键字段 =="
[ -f "$D/gdb-stop.json" ] && python3 -c "
import json,sys
d=json.load(open('$D/gdb-stop.json'))
def walk(o,p=''):
    if isinstance(o,dict):
        for k,v in o.items(): walk(v,p+'/'+k)
    elif isinstance(o,list):
        print(p,'list len',len(o))
    else:
        s=str(o)
        if len(s)<200: print(p,'=',s)
walk(d)
" 2>&1 | head -60
echo
echo "== uart 尾部 =="
[ -f "$D/gdb-uart.log" ] && tail -30 "$D/gdb-uart.log"
echo "== DONE =="
