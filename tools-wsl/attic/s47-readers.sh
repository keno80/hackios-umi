#!/bin/bash
# 接 s46：去交错不成立（NXSB 只出现 10 次=超级块副本组）；ipsw 对 OS dmg 进了 "Decrypting DMG" 且 koly flags=0x1 ⇒ 加密 UDIF。
# 本文件把读者逐个试穿，全部只读：
#   1) apfs-fuse（sgerrand，自带 APFS 实现）在不在源里、装了能不能挂 cryptex；
#   2) apfsck(2023) 对 cryptex 的判读——它认不认这代格式；
#   3) ipsw -V 的详细报错（确认到底要 key 还是别的问题）；
#   4) cryptex 头 10 个超级块副本逐字段（blocksize/blocks/uuid/features），钉死真实基址。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s47-readers.txt 2>&1
IPSW=/mnt/d/tools/ipsw/ipsw
IMG=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461
CX=$IMG/044-76034-038.dmg
OS=$IMG/044-76040-038.dmg
OUT=/home/unixnu/code/umi-work-pin/out/umi-xnu/apple-el0
rm -f "$OUT/os.raw"

echo "== 1. apfs-fuse 可得性 =="
apt-cache policy apfs-fuse 2>&1 | head -6
timeout 240 apt-get install -y apfs-fuse 2>&1 | tail -6
command -v apfs-fuse || echo "  apfs-fuse 不可用"

echo
echo "== 2. apfsck 读 cryptex（只检不改）=="
timeout 300 apfsck -v "$CX" 2>&1 | head -40

echo
echo "== 3. ipsw -V 详细报错 =="
echo "--- cryptex ---"
timeout 300 $IPSW disk dmg "$CX" -o "$OUT/cx.raw" -V 2>&1 | head -25
echo "--- OS dmg ---"
timeout 300 $IPSW disk dmg "$OS" -o "$OUT/os.raw" -V 2>&1 | head -25
ls -l "$OUT" 2>/dev/null | head

echo
echo "== 4. cryptex 的 10 个超级块副本逐字段 =="
python3 - "$CX" <<'PY'
import struct, sys
f = open(sys.argv[1], 'rb')
d = f.read(256 * 1024)
offs = [i for i in range(len(d) - 4) if d[i:i + 4] == b'NXSB']
print('  NXSB 偏移', [hex(o) for o in offs], '共', len(offs))
for o in offs[:4]:
    b = d[o:o + 256]
    magic = b[:8]
    blocksize, = struct.unpack_from('<Q', b, 8)
    blocks, = struct.unpack_from('<Q', b, 16)
    next_cat, = struct.unpack_from('<Q', b, 24)
    next_bn, = struct.unpack_from('<Q', b, 32)
    used, = struct.unpack_from('<Q', b, 40)
    cp0, cp1 = struct.unpack_from('<2Q', b, 48)
    compat, incompat, ro = struct.unpack_from('<3Q', b, 64)
    uuid = b[88:104]
    print(f'  @{hex(o)} magic={magic[:4]} blksize={blocksize} blocks={blocks} '
          f'next_cat={next_cat} next_bnode={next_bn} used={used}')
    print(f'      checkpoint_pair={cp0:#x},{cp1:#x} compat={compat:#x} incompat={incompat:#x} ro={ro:#x} uuid={uuid.hex()}')
print('  对照 fsapfsinfo 报的 uuid=e886f82c-ee56-4b52-af5f-e70bf46320c4 / incompat=0x28')
PY
