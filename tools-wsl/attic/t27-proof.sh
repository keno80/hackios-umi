#!/bin/bash
set -u
exec > /mnt/e/Code/HackIos/out/probes/t27-30z-proof.txt 2>&1
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
echo "== 内核身份 =="
sha256sum "$K"
echo
echo "== _accelerate_entitlement_queries 反汇编 =="
A=$(llvm-nm -n --defined-only "$K" 2>/dev/null | awk '/_accelerate_entitlement_queries$/{print $1}')
echo "addr=0x$A"
S=$(printf '0x%x' "0x$A"); E=$(printf '0x%x' $(( "0x$A" + 0x60 )))
llvm-objdump -d --start-address=$S --stop-address=$E "$K" 2>&1 | tail -30
echo
echo "== 判据 =="
llvm-objdump -d --start-address=$S --stop-address=$E "$K" 2>&1 > /tmp/a.txt
python3 - <<'PY'
import re
txt = open('/tmp/a.txt').read()
lines = [l for l in txt.splitlines() if re.search(r'\b[0-9a-f]{16}:', l)]
idx_load = next((i for i, l in enumerate(lines) if '#0x228' in l), None)
idx_deref = next((i for i, l in enumerate(lines) if '#0x1a0' in l), None)
print('ldr amfi 行 =', lines[idx_load].strip() if idx_load is not None else None)
print('deref 行   =', lines[idx_deref].strip() if idx_deref is not None else None)
if idx_load is None:
    print('VERDICT: 找不到 amfi 载入（结构变了，需人工看）')
elif idx_deref is None:
    print('VERDICT: 产物里已无 0x1a0 解引用（守卫把整段消掉了）')
else:
    between = lines[idx_load + 1:idx_deref]
    branch = [l for l in between if re.search(r'\b(cbz|cbnz|tbz|tbnz|b\.(eq|ne|hs|lo))\b', l)]
    print('中间指令 =', [l.split('\t')[-1].strip() for l in between])
    print('VERDICT:', 'GUARD-OK' if branch else 'NO-GUARD：30z 没进这个函数')
PY
echo
echo "== 顺带：cs_blob_cleanup 里 invalidate 的守卫 =="
B=$(llvm-nm -n --defined-only "$K" 2>/dev/null | awk '/_cs_blob_cleanup$/{print $1}')
echo "cs_blob_cleanup addr=0x$B"
[ -n "$B" ] && llvm-objdump -d --start-address=0x$B --stop-address=$(printf '0x%x' $((0x$B + 0x90))) "$K" 2>&1 | tail -22
echo "done $(date -u +%FT%TZ)"
