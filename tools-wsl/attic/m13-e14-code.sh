#!/bin/bash
# E14 到底是哪条分支产生的；以及 run-20（上游件）同参数读回长什么样，做对照。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/m13-e14-code.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
G=$(find $WS/sources/UniXNU -name gdb-stop.py | head -1)

echo "== 0. 文件 =="
echo "$G"; wc -l "$G"

echo
echo "== 1. read-memory 处理段（1430-1560）=="
sed -n '1430,1560p' "$G" | nl -ba -v1430

echo
echo "== 2. 读内存的函数定义（read_memory / x_bytes / mem_read）=="
grep -n 'def .*mem\|def .*read\|def .*x(' "$G" | head -30

echo
echo "== 3. 产生 E<数字> 标记的地方 =="
grep -n 'f"E\|"E%"\|E{.*}\|:E\|E%02d\|prefix + str' "$G" | head -30

echo
echo "== 4. run-20（上游件）的 memory 段做对照 =="
for d in $(ls -d $WS/out/umi-qemu/run-20* 2>/dev/null); do
  echo "---- $d"
  python3 -c "
import json,sys
try:
    r=json.load(open('$d/gdb-stop.json'))
    print(json.dumps(r.get('memory',{}),indent=1)[:1200])
    print('stop_symbol',r.get('stop_symbol'),'bounded',r.get('bounded_timeout_interrupted'))
    print('ELR',r.get('system_registers',{}).get('ELR_EL1'),'FAR',r.get('system_registers',{}).get('FAR_EL1'))
except Exception as e:
    print('ERR',e)
"
done

echo
echo "== 5. 全部 run 目录里 memory 段的 E14 出现史 =="
for d in $WS/out/umi-qemu/run-*; do
  v=$(python3 -c "
import json
try:
    r=json.load(open('$d/gdb-stop.json'))
    m=r.get('memory',{})
    print(len(m), sum(1 for x in m.values() if isinstance(x,str) and x.startswith('E')))
except Exception as e: print('-')
" 2>/dev/null)
  echo "$(basename $d) n,err=$v"
done

echo
echo "== 6. 走查件里 0x100003ffc 与 0x100004080 落在哪个段 =="
F=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho
/opt/unixnu-linux/CommandLineTools/usr/bin/otool -l "$F" 2>/dev/null | grep -A6 -i 'sectname\|segname' | head -60
echo "-- 符号 --"
/opt/unixnu-linux/CommandLineTools/usr/bin/nm -n "$F" 2>/dev/null | head -40
echo "== done $(date -u +%FT%TZ)"
