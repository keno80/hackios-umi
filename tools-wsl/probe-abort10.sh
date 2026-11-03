#!/bin/bash
# 取证：run-10-kit 的 data abort —— pc 落在哪个函数、tcp_init 调了谁、上游 rand wrapper 怎么写
set -u
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
NM=$(command -v llvm-nm || command -v nm)
OD=$(command -v llvm-objdump || command -v objdump)
OUT=/mnt/e/Code/HackIos/out/abort10.txt
{
  echo "== pc/lr symbolize"
  $NM -n --defined-only "$K" > /tmp/k.syms
  python3 - <<'PY'
import bisect,re
syms=[]
for line in open('/tmp/k.syms',errors='replace'):
    p=line.split()
    if len(p)==3 and re.fullmatch(r'[0-9a-f]+',p[0]): syms.append((int(p[0],16),p[2]))
syms.sort(); keys=[a for a,_ in syms]
def name(a):
    i=bisect.bisect_right(keys,a)-1
    return '%s+0x%x'%(syms[i][1],a-syms[i][0]) if i>=0 else '?'
for a in (0xfffffff0078dda10,0xfffffff00763b710,0xfffffff0078dc928):
    print('%x -> %s'%(a,name(a)))
print('-- kit 邻近符号 --')
for a,n in syms:
    if 0xfffffff0078dc800<=a<=0xfffffff0078de400: print('%x %s'%(a,n))
    if 0xfffffff00763b5a0<=a<=0xfffffff00763b760: print('%x %s'%(a,n))
PY
  echo "== tcp_init 附近反汇编（lr-4 处即调用点）"
  $OD -d --start-address=0xfffffff00763b6e0 --stop-address=0xfffffff00763b730 "$K" 2>&1 | tail -20
  echo "== abort pc 反汇编"
  $OD -d --start-address=0xfffffff0078dd9d0 --stop-address=0xfffffff0078dda60 "$K" 2>&1 | tail -24
  echo "== 上游 corecrypto_rand.c"
  cat "$W/libkern/crypto/corecrypto_rand.c" 2>&1
  echo "== 我们的 kit tail（rng 四个 wrapper）"
  grep -n -A14 'umi_random_uniform\|umi_random_generate\|umi_rng_handle' /mnt/e/Code/HackIos/tools-wsl/umi_crypto_kit_tail.c | head -80
} > "$OUT" 2>&1
echo done
