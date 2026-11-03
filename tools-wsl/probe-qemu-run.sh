#!/bin/bash
# 用法：probe-qemu-run.sh <run名> —— 等该 run 结束并汇总 uart/stop/符号化/截屏
set -u
NAME=${1:-run-11-kit2}
O=/home/unixnu/code/umi-work-pin/out/umi-qemu/$NAME
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped
OUTD=/mnt/e/Code/HackIos/out
OUT="$OUTD/qemu-$NAME.txt"
i=0
while [ $i -lt 60 ]; do
  if [ -f "$O/gdb-stop.json" ] || [ -f "$O/gdb-failure.json" ]; then break; fi
  if ! pgrep -f "qemu-system-aarch64.*$NAME" > /dev/null 2>&1 \
     && ! pgrep -f "run_umi_qemu.py.*$NAME" > /dev/null 2>&1; then break; fi
  sleep 10; i=$((i+1))
done
cp "$O/screen.png" "$OUTD/qemu-$NAME-screen.png" 2>/dev/null
{
  echo "== waited=$((i*10))s"
  echo "== run dir"
  ls -l "$O" 2>&1
  echo "== uart tail"
  [ -f "$O/gdb-uart.log" ] && tail -c 2500 "$O/gdb-uart.log" | tr -cd '\11\12\40-\176'
  echo "== stop json (head)"
  [ -f "$O/gdb-stop.json" ] && head -c 1200 "$O/gdb-stop.json"
  echo
  echo "== stop json (tail)"
  [ -f "$O/gdb-failure.json" ] && head -c 1500 "$O/gdb-failure.json"
  echo
  echo "== symbolize"
  llvm-nm -n --defined-only "$K" > /tmp/k11.syms 2>/dev/null
  J="$O/gdb-stop.json" python3 - <<'PY'
import os,bisect,re
js=open(os.environ.get('J','/dev/null'),errors='replace').read() if os.path.exists(os.environ.get('J','')) else ''
syms=[]
for line in open('/tmp/k11.syms',errors='replace'):
    p=line.split()
    if len(p)==3 and re.fullmatch(r'[0-9a-f]+',p[0]): syms.append((int(p[0],16),p[2]))
syms.sort(); keys=[a for a,_ in syms]
def name(a):
    i=bisect.bisect_right(keys,a)-1
    return '%s+0x%x'%(syms[i][1],a-syms[i][0]) if i>=0 else '?'
for m in re.finditer(r'"(pc|lr|x30)": "0x([0-9a-f]+)"',js):
    print('%s %s -> %s'%(m.group(1),m.group(2),name(int(m.group(2),16))))
print('-- frame_chain --')
for m in re.finditer(r'"fp": "0x([0-9a-f]+)",\s*"lr": "0x([0-9a-f]+)"',js):
    print('lr %s -> %s'%(m.group(2),name(int(m.group(2),16))))
PY
} > "$OUT" 2>&1
echo done
