#!/bin/bash
# 接 s38：cryptex DMG 全文件 4096 对齐扫不到 NXSB、尾部 1MiB 无 koly；OS DMG 有 koly 但我按小端解（UDIF 是大端）。
# 本文件把三件事一次钉死：
#   1) 两个 DMG 的头 64 字节原样十六进制 + 常见压缩魔数判别；
#   2) 本地两份 DMG 的 sha256 与 s25 侧车 json 是否一致（防止半截文件导致后面全假）；
#   3) 用大端正确解 OS DMG 的 koly + blkx XML：CompressionType / Encrypted / 每段原始与压缩长度。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s39-dmg-headers.txt 2>&1
IMG=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461

echo "== 1. 头 64 字节 =="
for f in "$IMG"/044-76034-038.dmg "$IMG"/044-76040-038.dmg; do
  echo "--- $(basename "$f") ($(stat -c %s "$f") B) ---"
  od -An -tx1 -N64 "$f"
  python3 - "$f" <<'PY'
import sys
head = open(sys.argv[1], 'rb').read(16)
tags = {b'\x78\x9c': 'zlib(789c)', b'\x78\x01': 'zlib(7801)', b'\x78\xda': 'zlib(78da)',
        b'BZh': 'bzip2', b'QLFB': 'lzfse', b'lzvn': 'lzvn', b'\x04\x22\x4d\x18': 'lz4',
        b'NXSB': 'raw APFS', b'hfs+': 'HFS+', b'CD': None}
for k, v in tags.items():
    if head.startswith(k) and v:
        print('  头部魔数命中：', v)
        break
else:
    print('  头部无已知魔数，前 8 字节 ascii=', repr(head[:8]))
PY
done

echo
echo "== 2. sha256 与侧车核对 =="
for f in "$IMG"/044-76034-038.dmg "$IMG"/044-76040-038.dmg; do
  echo "--- $(basename "$f") ---"
  python3 -c "import json;d=json.load(open('$f.json'));print('  json:',d.get('sha256'),d.get('size'))" 2>/dev/null || echo '  无侧车 json'
  printf '  实际: '; timeout 600 sha256sum "$f" | cut -d' ' -f1
done

echo
echo "== 3. OS DMG 的 UDIF 尾（大端）与块表 =="
python3 - "$IMG/044-76040-038.dmg" <<'PY'
import plistlib, struct, sys
p = sys.argv[1]
f = open(p, 'rb')
sz = f.seek(0, 2)
f.seek(sz - 512)
t = f.read(512)
if t[:4] != b'koly':
    print('  末扇区无 koly：', t[:4])
    sys.exit()
(hd, ver, hdrsz, flags, blocksz, mblock, mkbtn, mktb) = struct.unpack_from('>8I', t, 0)
xor, xlen, zlib, zlen, master, metab, idany = struct.unpack_from('>7Q', t, 32)
print(f'  koly v{ver} hd={hd} hdrsz={hdrsz} flags={flags:#x} blocksz={blocksz} '
      f'xml@{xor}+{xlen} zlib@{zlib}+{zlen} master@{master} metablock@{metab} uuid={idany:016x}')
f.seek(xor)
try:
    plist = plistlib.loads(f.read(xlen))
except Exception as e:
    print('  xml plist 解析失败：', e); sys.exit()
print('  plist keys:', list(plist.keys()))
for b in plist.get('blkx', []):
    print(f"  blkx attrs={b.get('Attributes'):#x} type={b.get('BLKX_type')} "
          f"Compress={b.get('CompressionType')} (0=raw,1=zlib,2=bzlib,3=split,4=runzlib,5=runbzlib,6=lzfse) "
          f"start={b.get('startOfData')} dataLen={b.get('dataLength')} csum={b.get('ChecksumType')} "
          f"Name={b.get('Name')}")
    for e in b.get('Entries', [])[:4]:
        print(f"     entry Decomp[{e.get('decompBegin')},{e.get('decompEnd')}) "
              f"Comp[{e.get('compBegin')},{e.get('compEnd')}) kind={e.get('kindOfData')}")
PY

echo
echo "== 4. cryptex 是否是被 IM4P/AEA 包着的（前 32 字节若为 'khdr'/'im4p'/'AEA1' 就说明另有一层）=="
od -An -c -N32 "$IMG/044-76034-038.dmg"
