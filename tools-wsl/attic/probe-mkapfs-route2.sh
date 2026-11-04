#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/mkapfs-route2.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
W=/home/unixnu/code/umi-work-pin

say "== 1. mkapfs 正确用法重试 =="
IMG=/tmp/seed-test2.img; rm -f "$IMG"; truncate -s 512M "$IMG"
losetup -d /dev/loop1 2>/dev/null
LOOP=$(losetup -f --show "$IMG"); say "LOOP=$LOOP"
mkapfs -L Data -s "$LOOP" 2>&1 | tail -8 >> "$OUT"
say "rc=${PIPESTATUS[0]}"
python3 - "$IMG" <<'PY' >> "$OUT" 2>&1
import struct
d=open('/tmp/seed-test2.img','rb').read(8*1024*1024)
i=d.find(b'NXSB')
print('NXSB offset:', hex(i) if i>=0 else 'NOT FOUND')
if i>=0:
    vals=struct.unpack_from('<4IQIQIQQQQ',d,i)
    print('fields:',[hex(v) if isinstance(v,int) else v for v in vals])
PY
say "-- fsapfs 能否只读解析 --"
fsapfsinfo /tmp/seed-test2.img 2>&1 | head -20 >> "$OUT"

say
say "== 2. UniXNU 内核侧的 APFS 是谁写的（决定 mkapfs 容器能否被挂）=="
grep -rli 'apfs' "$S/drivers" 2>/dev/null | head -20 >> "$OUT"
say "-- device-records 里 apfs 关键词出现的板子 --"
grep -rli 'apfs' "$S/device-records" 2>/dev/null | head -10 >> "$OUT"
say "-- umi 工具里的 apfs 处理 --"
grep -rn 'apfs' "$W/tools" 2>/dev/null | head -15 >> "$OUT"

say
say "== 3. Linux 上有没有已解出的 OS 卷（make-data-seed 的输入）=="
find /home/unixnu/code -maxdepth 6 -type d -name 'private' 2>/dev/null | head -5 >> "$OUT"
ls -d "$W"/out/ipsw/* 2>/dev/null | head -10 >> "$OUT"
du -sh "$W"/out/ipsw 2>/dev/null >> "$OUT"
say "-- 有没有 Restore/Update 的 DMG 件 --"
find "$W"/out -maxdepth 4 \( -name '*.dmg' -o -name '*Update*' \) 2>/dev/null | head -10 >> "$OUT"

say
say "== 4. userdata-root.img 是怎么造的（我们已成功让内核挂上的样本）=="
grep -rn 'userdata-root' "$S/scripts/unixnu/userdata.py" 2>/dev/null | head -8 >> "$OUT"
sed -n '1,40p' "$S/scripts/unixnu/userdata.py" >> "$OUT" 2>&1
say done
