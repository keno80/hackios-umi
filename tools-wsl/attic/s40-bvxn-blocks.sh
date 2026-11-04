#!/bin/bash
# 接 s39：cryptex 头 = 'bvxn' + 32 字节头，NXSB 正好在 0x20（块大小 0x1000、806400 块=3303014400B 整）。
# 也就是说这文件是 Apple 压缩框架的「编码块串」，第一段是裸块。本文件钉四件事：
#   1) 'bvxn'/'QLFB' 在两个文件前 4MiB 的出现密度与步长 —— 判断是否整卷都是块串、块头是不是定长；
#   2) 'NXSB' 逐字节搜索（前 2MiB），报出偏移与 mod 4096，确认容器真实起点；
#   3) 上游有没有纯 Python 的 udif/块解码件（scripts/*udif*），谁产出 os-mount；
#   4) 本地源码/头文件里 'bvxn' 的定义在哪（XNU bsd/apfs 或 external 头）。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s40-bvxn-blocks.txt 2>&1
IMG=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461
CX=$IMG/044-76034-038.dmg
OS=$IMG/044-76040-038.dmg
U=/home/unixnu/code/UniXNU-main
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree

echo "== 1. 前 4MiB 的块魔数分布 =="
python3 - "$CX" "$OS" <<'PY'
import sys
for p in sys.argv[1:]:
    d = open(p, 'rb').read(4 * 1024 * 1024)
    for m in (b'bvxh', b'bvxn', b'QLFB', b'nvbn', b'rawx', b'comp', b'zidx', b'lzvn', b'ENDB', b'XVLB'):
        offs = []
        i = d.find(m)
        while i != -1 and len(offs) < 12:
            offs.append(i)
            i = d.find(m, i + 1)
        n = d.count(m)
        if n:
            step = (offs[1] - offs[0]) if len(offs) > 1 else None
            print(f'{p.split("/")[-1]:>20} {m.decode():>5} count={n:<6} 前 12 偏移={offs} 首步长={step}')
    print()
PY

echo "== 2. NXSB 逐字节搜索（前 2MiB）=="
python3 - "$CX" "$OS" <<'PY'
import sys
for p in sys.argv[1:]:
    d = open(p, 'rb').read(2 * 1024 * 1024)
    offs = [i for i in range(len(d) - 4) if d[i:i + 4] == b'NXSB']
    print(p.split('/')[-1], 'NXSB 偏移', [hex(o) for o in offs[:8]], 'mod4096', [o % 4096 for o in offs[:8]])
PY

echo
echo "== 3. bvxn 块头逐字段（cryptex 第一段）=="
python3 - "$CX" <<'PY'
import struct, sys
d = open(sys.argv[1], 'rb').read(0x1000)
print('little:', [hex(v) for v in struct.unpack_from('<16I', d, 0)])
print('bigend:', [hex(v) for v in struct.unpack_from('>16I', d, 0)])
PY

echo
echo "== 4. 上游有没有 udif / 解 DMG 的纯 Python 件 =="
find "$U" "$T" -maxdepth 3 -name '*udif*' -o -maxdepth 3 -name '*dmg*' 2>/dev/null | head
echo "--- scripts 里提到 udif/dmg/os-mount/mount 的行 ---"
grep -rn -E 'udif|\.dmg|os-mount|DMG_' "$U/scripts" 2>/dev/null | grep -v Binary | head -30
echo "--- 谁产出 os-mount ---"
grep -rln 'os-mount' "$U" "$T" 2>/dev/null | head -20

echo
echo "== 5. 本地源码里 bvxn 的定义 =="
grep -rn 'bvxn\|bvxh' "$T/.cache/xnu-work" 2>/dev/null | head -10
grep -rn 'bvxn\|bvxh' /usr/include /usr/local/include 2>/dev/null | head -5
python3 -c "import ctypes.util,sys; print('libcompression:', ctypes.util.find_library('compression'))"
