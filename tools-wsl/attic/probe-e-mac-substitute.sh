#!/bin/bash
# E 步：把「Mac 专有」收窄到能逐条验证的集合，并实测 Linux userspace mkapfs 的上界
set -u
OUT=/mnt/e/Code/HackIos/out/probes/e-mac-substitute.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
W=/home/unixnu/code/umi-work-pin

say "== 1. hdiutil / diskutil 的全部调用点（Mac 专有的真实面积）=="
grep -rn "hdiutil\|diskutil" "$S/scripts/unixnu" 2>/dev/null | head -30 >> "$OUT"
say "-- 涉及文件数（上游 + 本机 umi 工具）--"
grep -rl "hdiutil\|diskutil" "$S/scripts/unixnu" "$W/tools" 2>/dev/null \
  | sed -e "s|$S/|S/|" -e "s|$W/|W/|" >> "$OUT"
grep -rl "hdiutil\|diskutil" "$S/scripts/unixnu" "$W/tools" 2>/dev/null | wc -l >> "$OUT"

say
say "== 2. Linux userspace mkapfs 能否造出带指定 UUID 的容器 =="
UUID=04769d26-1111-4c3a-9e0b-0123456789ab
IMG=/tmp/e-seed.img; rm -f "$IMG"; truncate -s 128M "$IMG"
losetup -d /dev/loop2 2>/dev/null
LOOP=$(losetup -f --show "$IMG"); say "LOOP=$LOOP"
say "-- mkapfs 帮助/--version --"
mkapfs -v 2>&1 | head -3 >> "$OUT"
REAL=$(python3 -c "import uuid;print(uuid.UUID('${UUID}'.lower()))")
say "请求 UUID=$REAL"
mkapfs -L Data -U "$REAL" "$LOOP" 2>&1 | tail -5 >> "$OUT"
say "mkapfs rc=${PIPESTATUS[0]}"
sync; losetup -d "$LOOP"
python3 - "$IMG" "$REAL" <<'PY' >> "$OUT" 2>&1
import struct, sys, uuid
img, want = sys.argv[1], sys.argv[2]
d = open(img, 'rb').read(16 << 20)
i = d.find(b'NXSB')
print('NXSB @', hex(i) if i >= 0 else 'NOT FOUND')
if i >= 0:
    fields = struct.unpack_from('<4IQIQIQQQQ', d, i)
    names = ['magic','block_size','block_count','pad','pad','uuid_lo','uuid_hi','desc_off','desc_len','unk']
    for n, v in zip(names, fields):
        print('  %-10s %#x' % (n, v))
    raw = d[i + 32:i + 48]
    print('  container UUID bytes:', raw.hex(), '->', uuid.UUID(bytes_le=raw))
    print('  与请求一致:', uuid.UUID(bytes_le=raw) == uuid.UUID(want))
PY
say "-- fsapfsinfo 只读回解 --"
fsapfsinfo "$IMG" 2>&1 | head -16 >> "$OUT"

say
say "== 3. 卷里能不能写文件（决定 mkapfs 容器能否当 Data seed 用）=="
say "-- 内核 apfs 模块 --"
modprobe apfs > /tmp/mp.txt 2>&1; say "modprobe rc=$?"; head -2 /tmp/mp.txt >> "$OUT"
ls /lib/modules/$(uname -r)/kernel/fs/apfs* 2>&1 | head -3 >> "$OUT"
say "-- fuse / userspace 写路径 --"
for t in mount.apfs mount_apfs apfs-fuse apfs unpackapfs apfsck; do
  p=$(command -v "$t" 2>/dev/null); say "  $t = ${p:-NO}"
done
say "-- apt 侧有哪些可选件 --"
apt-cache policy apfsprogs apfs-fuse linux-apfs-rw-dkms 2>/dev/null | grep -E "^[a-z]|Candidate" | head -12 >> "$OUT"

say
say "== 4. 上游对 seed 的校验口径（mkapfs 产物能不能过）=="
grep -rn "NXSB\|apfs" "$S/scripts/unixnu/packed_ramdisk.py" 2>/dev/null | head -12 >> "$OUT"
say "-- make-data-seed.py 的 hdiutil 命令行 --"
grep -n -A3 "hdiutil\|diskutil" "$S/scripts/unixnu/make_data_seed.py" 2>/dev/null | head -25 >> "$OUT"
find "$S/scripts" -name "*data*seed*" -o -name "*seed*data*" | head >> "$OUT"
say done
