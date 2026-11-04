#!/bin/bash
# 接 s41：udif.py 说「无 koly 即裸盘，IPSW 的 SystemOS cryptex 就是」⇒ 我们手里已经是裸容器。
# 但 s39/40 量到 cryptex 的 NXSB 不在 0，而在 0x20，且每 0x2000 出现一次；OS dmg 以 'bvxn'(大端字段) 开头。
# 本文件只做测量，不做拷贝：
#   1) cryptex 前 0x400 完整十六进制；
#   2) 前 4MiB 内所有 NXSB 的偏移/步长，并逐段 diff 前三个 256B 超级块是否相同；
#   3) 两个文件前 64KiB 的可读串（找 plist/字段名，认格式）；
#   4) ipsw 有没有 apfs/cryptex 读件（决定要不要引入 Go 工具）。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s42-layout-measure.txt 2>&1
IMG=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461
CX=$IMG/044-76034-038.dmg
OS=$IMG/044-76040-038.dmg

echo "== 1. cryptex 前 0x400 =="
od -Ax -tx1z -N0x400 "$CX"

echo
echo "== 2. NXSB 步长与副本是否相同（cryptex 前 4MiB）=="
python3 - "$CX" <<'PY'
d = open('/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461/044-76034-038.dmg','rb').read(4*1024*1024)
offs = [i for i in range(len(d)-4) if d[i:i+4] == b'NXSB']
print('count', len(offs), 'first', [hex(o) for o in offs[:6]])
print('strides', [offs[i+1]-offs[i] for i in range(min(len(offs)-1,6))])
for i in offs[:3]:
    print(f'@{i:#x}', d[i:i+64].hex(' '))
if len(offs) >= 3:
    same = all(d[offs[0]:offs[0]+256] == d[o:o+256] for o in offs[1:6])
    print('前 256B 是否与首个一致:', same)
print('0x20 之前 32 字节:', d[0:32].hex(' '))
print('每 0x2000 段头 32B 抽样:')
for k in range(4):
    print(f'  seg{k}:', d[k*0x2000:k*0x2000+32].hex(' '))
PY

echo
echo "== 3. 可读串 =="
for f in "$CX" "$OS"; do
  echo "--- $(basename "$f") 前 64KiB ---"
  head -c 65536 "$f" | strings -a -n 6 | head -25
done

echo
echo "== 4. ipsw 的 APFS/cryptex 命令面 =="
timeout 30 curl -sS "https://api.github.com/repos/blacktop/ipsw/contents/cmd/ipsw/cmd" -o /tmp/s42.cmd.json 2>&1 | head -2
python3 -c "
import json
print(', '.join(x['name'] for x in json.load(open('/tmp/s42.cmd.json'))))" 2>/dev/null
timeout 30 curl -sS "https://api.github.com/repos/blacktop/ipsw/contents/pkg" -o /tmp/s42.pkg.json 2>&1 | head -2
python3 -c "
import json
n=[x['name'] for x in json.load(open('/tmp/s42.pkg.json'))]
print('pkg:', ', '.join(n))
print('有 apfs?', [x for x in n if 'apfs' in x.lower() or 'cryptex' in x.lower() or 'dmg' in x.lower()])" 2>/dev/null
