#!/bin/bash
# 接 s42：cryptex 每 8192 字节一个 32B 描述符、载荷以 'NXSB' 起；OS dmg 里有 'bvxn'/'bvx2'/'EFI PART'。
# ⇒ 这是 Apple 的 bvx 块式磁盘图（GPT+APFS），2020 版 libfsapfs 结构上就吃不下。
# 本文件一次做完：认格式 → 取工具 → 验命令面。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s43-ipsw-install.txt 2>&1
export PATH=$PATH:/mnt/d/tools/ipsw
TOOLS=/mnt/d/tools/ipsw
IMG=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461

echo "== 0. 环境 =="
id 2>&1 | head -1
sudo -n true 2>&1 | head -1 && echo "  sudo 免密可用"
ls /dev/loop* 2>/dev/null | head -3
df -h /mnt/d /home/unixnu 2>/dev/null | tail -3

echo
echo "== 1. cryptex 前 1MiB 的 bvx/EFI/NXSB 位置（确认块描述符规则）=="
python3 - "$IMG/044-76034-038.dmg" "$IMG/044-76040-038.dmg" <<'PY'
import sys
for p in sys.argv[1:]:
    d = open(p, 'rb').read(1024 * 1024)
    print('---', p.split('/')[-1], '---')
    for m in (b'bvx$', b'bvxh', b'bvxn', b'bvx2', b'EFI PART', b'NXSB', b'CHECK'):
        offs = []
        i = d.find(m)
        while i != -1 and len(offs) < 8:
            offs.append(hex(i)); i = d.find(m, i + 1)
        if offs:
            print(f'  {m.decode():8} count={d.count(m):<6} {offs}')
    print('  bvx$ 后的标签串:', [s.decode() for s in
          __import__('re').findall(rb'bvx.{0,8}[ -~]{3,12}', d[:4096])][:8])
PY

echo
echo "== 2. 取 ipsw linux amd64 预编译件 =="
mkdir -p "$TOOLS"
timeout 60 curl -sS https://api.github.com/repos/blacktop/ipsw/releases/latest -o /tmp/s43.rel.json
python3 - <<'PY' > /tmp/s43.url.txt
import json
d = json.load(open('/tmp/s43.rel.json'))
for a in d['assets']:
    n = a['name'].lower()
    if 'linux' in n and ('amd64' in n or 'x86_64' in n) and a['name'].endswith('.tar.gz'):
        print(a['browser_download_url'], round(a['size'] / 1e6, 1), a['name'])
PY
cat /tmp/s43.url.txt
read -r URL SIZE NAME < /tmp/s43.url.txt
echo "选中: $NAME ($SIZE MB)"
for base in "" "https://gh-proxy.com/"; do
  echo "--- 试 ${base:-直连} ---"
  timeout 300 curl -sSL -o "$TOOLS/$NAME" "${base}${URL}" && \
    [ "$(stat -c %s "$TOOLS/$NAME")" -gt 1000000 ] && echo "  下载完成 $(stat -c %s "$TOOLS/$NAME") B" && break
  echo "  失败，换下一个源"
done
tar -xzf "$TOOLS/$NAME" -C "$TOOLS" 2>&1 | head -5
find "$TOOLS" -maxdepth 2 -type f -printf '%s\t%p\n' | head
"$TOOLS/ipsw" --version 2>&1 | head -3

echo
echo "== 3. ipsw 的 disk/extract/dyld 命令面 =="
for c in "--help" "disk --help" "extract --help" "dyld --help" "info --help"; do
  echo "--- ipsw $c ---"
  timeout 60 "$TOOLS/ipsw" $c 2>&1 | head -40
done
