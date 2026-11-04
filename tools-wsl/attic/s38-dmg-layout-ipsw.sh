#!/bin/bash
# 接 s37：apfsprogs deb 只给 apfsck/mkapfs/apfs-snap，没有 dump-apfs；且 cryptex DMG 前 64MiB 无 NXSB。
# 两件事要落地：① 容器在 DMG 里的真实起点（libfsapfs 能开，说明它自己在别处找到了 NXSB）；
#               ② ipsw(Go) 这条备选是否真的带 APFS 读、有没有 linux amd64 预编译件。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s38-dmg-layout-ipsw.txt 2>&1
IMG=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461
CX=$IMG/044-76034-038.dmg

echo "== 1. cryptex DMG 里 NXSB 的真实位置（全文件 4096 对齐扫）=="
python3 - "$CX" <<'PY'
import sys
p = sys.argv[1]
f = open(p, 'rb')
sz = f.seek(0, 2); f.seek(0)
hits, step = [], 4096
pos = 0
while pos + 8 <= sz and len(hits) < 5:
    f.seek(pos)
    if f.read(8) == b'NXSB\0\0\0\0':
        hits.append(pos)
    pos += step
print('size', sz, 'NXSB@', [hex(h) for h in hits], 'block-index', [h // 4096 for h in hits])
if hits:
    f.seek(max(0, hits[0] - 0x400)); back = f.read(0x400)
    print('前 1KiB 里的可读串：', [s.decode() for s in
          __import__('re').findall(rb'[ -~]{6,}', back)][-8:])
PY

echo
echo "== 2. DMG 尾部 1MiB 内找 koly（koly 不一定正好压末扇区）=="
python3 - "$CX" <<'PY'
import os, sys
p = sys.argv[1]
sz = os.path.getsize(p)
with open(p, 'rb') as f:
    f.seek(max(0, sz - 1024 * 1024)); tail = f.read()
idx = [i for i in range(len(tail) - 4) if tail[i:i + 4] == b'koly']
print('tail-window koly @', [hex(max(0, sz - 1024 * 1024) + i) for i in idx][:5])
print('距文件尾字节数：', [len(tail) - i for i in idx][:5])
PY

echo
echo "== 3. libfsapfs 到底按哪个偏移开的（strace 看它读了哪几段）=="
command -v strace >/dev/null && timeout 120 strace -f -e trace=pread64,lseek -o /tmp/s38.strace \
  fsapfsinfo "$CX" >/dev/null 2>&1
if [ -s /tmp/s38.strace ]; then
  grep -o 'lseek(3, [0-9]*' /tmp/s38.strace | awk '{print $2}' | sort -n -u | head -8
  grep -o 'pread64(3, .*, [0-9]*)' /tmp/s38.strace | head -5
else
  echo "  无 strace 或无输出"
fi

echo
echo "== 4. ipsw 的 APFS 能力与发行件（决定走不走 Go 这条路）=="
timeout 30 curl -sS https://api.github.com/repos/blacktop/ipsw/releases/latest \
  -o /tmp/s38.rel.json 2>&1 | head -2
python3 - <<'PY'
import json
d = json.load(open('/tmp/s38.rel.json'))
print('tag', d.get('tag_name'))
for a in d.get('assets', []):
    n = a['name']
    if 'linux' in n and ('amd64' in n or 'x64' in n):
        print(f"  {n}  {a['size']/1e6:.1f}MB  {a['browser_download_url']}")
PY
echo "--- 仓库里有没有 apfs 包 ---"
timeout 30 curl -sS "https://api.github.com/repos/blacktop/ipsw/git/trees/HEAD?recursive=0" -o /tmp/s38.tree.json 2>&1 | head -2
python3 -c "
import json
print([t['path'] for t in json.load(open('/tmp/s38.tree.json')).get('tree',[]) if t['type']=='tree'][:40])" 2>/dev/null
for d in cmd pkg internal; do
  echo "--- $d 子目录 ---"
  timeout 25 curl -sS "https://api.github.com/repos/blacktop/ipsw/contents/$d" 2>/dev/null \
    | python3 -c "import json,sys
try:
  print(', '.join(x['name'] for x in json.load(sys.stdin)))
except Exception as e: print('  ?')"
done
