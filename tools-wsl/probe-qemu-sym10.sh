#!/bin/bash
# 取证：run-10-kit 停在哪儿（截屏 + 符号化）
set -u
O=/home/unixnu/code/umi-work-pin/out/umi-qemu/run-10-kit
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped
NM=$(command -v llvm-nm || command -v nm)
OUTD=/mnt/e/Code/HackIos/out
cp "$O/screen.png" "$OUTD/qemu-run10-screen.png" 2>/dev/null
{
  echo "== runner.log"
  cat "$O/runner.log" 2>&1 | tr -cd '\11\12\40-\176'
  echo "== stderr"
  cat "$O/gdb-stderr.log" 2>&1 | tr -cd '\11\12\40-\176'
  echo "== full stop json tail"
  tail -c 2500 "$O/gdb-stop.json" | tr -cd '\11\12\40-\176'
  echo "== symbolize"
  addrs=$(grep -oE '0xfffffff[0-9a-f]{6,}' "$O/gdb-stop.json" | sort -u)
  # 用 nm 排序表把每个 pc 映射到其前一个符号
  $NM -n --defined-only "$K" > /tmp/kit.syms 2>/dev/null
  wc -l < /tmp/kit.syms
  python3 - "$O/gdb-stop.json" /tmp/kit.syms <<'PY'
import re,sys,bisect
js=open(sys.argv[1],errors='replace').read()
syms=[]
for line in open(sys.argv[2],errors='replace'):
    p=line.split()
    if len(p)==3 and re.fullmatch(r'[0-9a-f]+',p[0]):
        syms.append((int(p[0],16),p[2]))
syms.sort()
keys=[a for a,_ in syms]
def name(a):
    i=bisect.bisect_right(keys,a)-1
    if i<0: return '?'
    return '%s+0x%x'%(syms[i][1],a-syms[i][0])
addrs=sorted(set(int(x,16) for x in re.findall(r'0x([0-9a-f]{16})',js)))
print('-- addresses in stop.json --')
for a in addrs:
    print('%x -> %s'%(a,name(a)))
print('-- frame_chain --')
for m in re.finditer(r'"fp": "0x([0-9a-f]+)",\s*"lr": "0x([0-9a-f]+)"',js):
    lr=int(m.group(2),16)
    print('lr %x -> %s'%(lr,name(lr)))
PY
} > "$OUTD/qemu-run10-sym.txt" 2>&1
