#!/bin/bash
# 接 s43：read 取到了 ipswd（守护进程）而不是 ipsw 主件。本文件装对，并把 disk/extract 命令面验穿。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s44-ipsw-disk.txt 2>&1
TOOLS=/mnt/d/tools/ipsw
IMG=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461
CX=$IMG/044-76034-038.dmg
OS=$IMG/044-76040-038.dmg

echo "== 1. 装 ipsw 主件 =="
timeout 60 curl -sS https://api.github.com/repos/blacktop/ipsw/releases/latest -o /tmp/s44.rel.json
URL=$(python3 -c "
import json
d=json.load(open('/tmp/s44.rel.json'))
print(next(a['browser_download_url'] for a in d['assets']
           if a['name'].startswith('ipsw_') and 'linux' in a['name'] and 'x86_64' in a['name'] and a['name'].endswith('.tar.gz')))")
echo "URL=$URL"
NAME=$(basename "$URL")
[ -x "$TOOLS/ipsw" ] || { timeout 300 curl -sSL -o "$TOOLS/$NAME" "$URL" && tar -xzf "$TOOLS/$NAME" -C "$TOOLS"; }
ls -l "$TOOLS" | head -8
"$TOOLS/ipsw" --version 2>&1 | head -2

echo
echo "== 2. 顶层命令 =="
timeout 60 "$TOOLS/ipsw" --help 2>&1 | sed -n '1,60p'

echo
echo "== 3. disk 子命令（期望有 apfs/dmg 解读者）=="
timeout 60 "$TOOLS/ipsw" disk --help 2>&1 | head -40
for sub in $(timeout 60 "$TOOLS/ipsw" disk --help 2>&1 | sed -n '/Available Commands/,/^Flags/p' | awk 'NF==2 && $1!~/^ /{print $1}'); do
  echo "--- ipsw disk $sub --help ---"
  timeout 60 "$TOOLS/ipsw" disk $sub --help 2>&1 | head -30
done

echo
echo "== 4. extract 子命令 =="
timeout 60 "$TOOLS/ipsw" extract --help 2>&1 | head -45
