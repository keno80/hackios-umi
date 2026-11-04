#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/mkapfs-route.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
K=$(uname -r)

say "== 0. mkapfs 用法 =="
test -f /usr/share/man/man8/mkapfs.8.gz && zcat /usr/share/man/man8/mkapfs.8.gz | sed -n '1,60p' >> "$OUT" 2>&1 || mkapfs 2>&1 | head -25 >> "$OUT"

say
say "== 1. loop 设备可用性 =="
ls -l /dev/loop-control 2>&1 >> "$OUT"
modprobe loop 2>&1 | head -2 >> "$OUT"
say "loops -> $(ls /dev/loop* 2>/dev/null | tr '\n' ' ')"

say
say "== 2. 造 512MiB 稀疏文件 + mkapfs =="
IMG=/tmp/seed-test.img
rm -f "$IMG"; truncate -s 512M "$IMG"
LOOP=$(losetup -f --show "$IMG" 2>&1); say "LOOP=$LOOP"
case "$LOOP" in /dev/loop*) ;; *) say "losetup 失败，跳过"; printf 'x\n' >> "$OUT"; exit 0;; esac
mkapfs -f -v -L Data "$LOOP" 2>&1 | tail -20 >> "$OUT"
say "mkapfs rc=${PIPESTATUS[0]}"
say "-- 头/魔数核对：NXSB 在哪 --"
python3 - "$IMG" <<'PY' >> "$OUT" 2>&1
import sys
d=open(sys.argv[1],'rb').read(64*1024*1024)
i=d.find(b'NXSB')
print('NXSB offset:', hex(i) if i>=0 else 'NOT FOUND')
if i>=0:
    import struct
    nf,magic,blocksize,flags,nphys,nlog,oidmax,cksum=struct.unpack_from('<4IQIQIQQQ',d,i)
    print('magic',hex(magic),'blocksize',blocksize,'flags',hex(flags),'nphys',nphys,'nlog',nlog,'oidmax',oidmax)
PY

say
say "== 3. apfs-dkms：能否给 WSL 内核编出模块 =="
say "kernel=$K headers_dir=$(test -e /lib/modules/$K/build && echo YES || echo NO)"
DEBIAN_FRONTEND=noninteractive apt-get install -y apfs-dkms >/tmp/dkms-install.log 2>&1
say "apt rc=$?"
tail -8 /tmp/dkms-install.log >> "$OUT"
dkms status 2>&1 | head -10 >> "$OUT"
say "-- 模块文件 --"
find /lib/modules/$K -name 'apfs*' 2>/dev/null >> "$OUT"
say "-- 试着加载 --"
modprobe apfs 2>&1 | head -3 >> "$OUT"
lsmod 2>/dev/null | grep -i apfs >> "$OUT" || say "apfs 未加载"

say
say "== 4. 若加载成功：挂载并写入（符号链接/权限/owner）=="
if lsmod 2>/dev/null | grep -q '^apfs'; then
  M=/tmp/apfs-mnt; mkdir -p "$M"
  mount -t apfs "$LOOP" "$M" 2>&1 | head -5 >> "$OUT"
  if mountpoint -q "$M" 2>/dev/null || grep -q "$M" /proc/mounts; then
    mkdir -p "$M/mobile/Documents" "$M/tmp"
    echo hello > "$M/mobile/Documents/a.txt"
    ln -s ../Documents "$M/mobile/Library"
    chmod 1777 "$M/tmp"; chown -R 501:501 "$M/mobile" 2>/dev/null
    sync; umount "$M" 2>&1 | head -3 >> "$OUT"
    say "写入 rc ok"
    apfsck -n "$LOOP" 2>&1 | tail -12 >> "$OUT"
  else
    say "挂载失败"
  fi
else
  say "跳过（无内核模块）"
fi

say
say "== 5. 只读侧备选：libfsapfs-utils / apfs-fuse =="
DEBIAN_FRONTEND=noninteractive apt-get install -y libfsapfs-utils >/tmp/fsapfs.log 2>&1
say "apt rc=$?"
dpkg -L libfsapfs-utils 2>/dev/null | grep bin >> "$OUT"
apt-cache search apfs-fuse 2>&1 | head -5 >> "$OUT"
say done
