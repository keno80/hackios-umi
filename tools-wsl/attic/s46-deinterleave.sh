#!/bin/bash
# 台阶1取证第四轮。两个待验假设：
#   A) cryptex 是 [32B 头(校验/版本/序号/flags) + 8160B 载荷] 每 8192 交错 ⇒ 去交错后才对齐，
#      这正好能解释 libfsapfs 读到超级块(0x20 处)却在 B-tree 拿 0x0（地址没加基）。
#   B) OS dmg 有 koly（s37 的 'koly' 匹配成立，只是我按小端解了字段）⇒ ipsw disk dmg 能直接解出裸盘。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s46-deinterleave.txt 2>&1
IPSW=/mnt/d/tools/ipsw/ipsw
IMG=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461
CX=$IMG/044-76034-038.dmg
OS=$IMG/044-76040-038.dmg
OUT=/home/unixnu/code/umi-work-pin/out/umi-xnu/apple-el0
mkdir -p "$OUT"

echo "== A1. 去交错前 64MiB，看解出来的流是不是正常 APFS =="
python3 - "$CX" "$OUT/cx.head64.raw" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
f = open(src, 'rb'); n = 64 * 1024 * 1024
raw = f.read(n)
out = bytearray()
for k in range(len(raw) // 8192):
    out += raw[k * 8192 + 32:(k + 1) * 8192]
open(dst, 'wb').write(bytes(out))
print(f'  输入 {len(raw)} B → 去交错 {len(out)} B (每 8192 取 8160)')
marks = {}
for name, m in {'NXSB': b'NXSB', 'cksum/obj 0x0a0b0c0d': b'\x0d\x0c\x0b\x0a',
                'obj 0x0d0c0b0a': b'\x0a\x0b\x0c\x0d', 'EFI PART': b'EFI PART',
                'bvx': b'bvx', 'snapshot': b'snapshot'}.items():
    offs = []
    i = out.find(m)
    while i != -1 and len(offs) < 6:
        offs.append(hex(i)); i = out.find(m, i + 1)
    print(f'  {name:22} count={out.count(m):<6} {offs}')
print('  头 256B 十六进制:', bytes(out[:64]).hex(' '))
PY

echo
echo "== A2. 另一种可能：头是 32B 但载荷 8192B（单元=8224）—— 前 64MiB 同样试 =="
python3 - "$CX" <<'PY'
raw = open('/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461/044-76034-038.dmg','rb').read(64*1024*1024)
out = bytearray()
p = 0
while p + 32 + 8192 <= len(raw):
    out += raw[p+32:p+32+8192]; p += 32 + 8192
nx = [i for i in range(0, min(len(out), 8*1024*1024), 1) if out[i:i+4] == b'NXSB']
print(f'  单元=8224 假设：解出 {len(out)} B，NXSB 前 6 偏移 {[hex(x) for x in nx[:6]]}')
print(f'  该假设下 EFI PART 偏移:', [hex(i) for i in range(len(out)-8) if out[i:i+8]==b'EFI PART'][:4])
PY

echo
echo "== B1. koly 大端正确解（OS dmg）=="
python3 - "$OS" <<'PY'
import plistlib, struct, sys
p = sys.argv[1]
f = open(p, 'rb'); sz = f.seek(0, 2)
f.seek(sz - 512); t = f.read(512)
print('  magic', t[:4], 'version', *struct.unpack_from('>I', t, 4), 'hdrsize', struct.unpack_from('>I', t, 8)[0])
mcount, hdrver, hdrsize, flags, blocksize = struct.unpack_from('>5I', t, 0)
print(f'  fields: magic={t[:4]} mcount={mcount} hdrver={hdrver} hdrsize={hdrsize} flags={flags:#x} blocksize={blocksize}')
data_fork, data_len = struct.unpack_from('>2Q', t, 0x18)
plist_off, plist_len = struct.unpack_from('>2Q', t, 0x60)
sectors, = struct.unpack_from('>Q', t, 0x70)
print(f'  data_fork@{data_fork} len={data_len}  plist@{plist_off}+{plist_len}  sectors={sectors} ({sectors*512} B)')
f.seek(plist_off); pl = plistlib.loads(f.read(plist_len))
print('  plist keys:', list(pl.keys()))
for b in pl.get('resource-fork', {}).get('blkx', []):
    mish = b['Data']
    print(f"  blkx Name={b.get('Name')!r} sig={mish[:4]} attr={b.get('Attributes'):#x} "
          f"nchunks={struct.unpack_from('>I', mish, 0xc8)[0]}")
PY

echo
echo "== B2. 后台起 ipsw 解 OS dmg（5.1GB，可能要几分钟）=="
cd "$OUT"
setsid nohup bash -c "echo \$\$ > $OUT/osdecode.pid; $IPSW disk dmg '$OS' -o '$OUT/os.raw' > '$OUT/osdecode.log' 2>&1; echo RC=\$? >> '$OUT/osdecode.log'" >/dev/null 2>&1 &
sleep 8
echo "  pid=$(cat "$OUT/osdecode.pid" 2>/dev/null || echo 无)"
ps -o pid,etime,rss,args -p "$(cat "$OUT/osdecode.pid" 2>/dev/null)" 2>/dev/null | tail -2
echo "--- 日志前 15 行 ---"; head -15 "$OUT/osdecode.log" 2>/dev/null
ls -l "$OUT" | head
