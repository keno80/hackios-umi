#!/bin/bash
# 接 s25：本机已有 OS 与 Cryptex1,SystemOS 两个已解密 DMG，也有 9.38G 的 userdata-root.img
# （它按 SHNGROOT 布局把 OS/SystemOS 镜像逐字节搬进去了）。
# 要拿「真 Apple 的 EL0 件」只差一步：从 APFS 卷里读单个文件。上游没有 APFS 读实现，
# 所以本文件先量三件事：盘上还有多少空间、窗口偏移是多少、Linux 侧有没有现成的 APFS 读取器可装。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s26-apfs-reader-options.txt 2>&1
W=/home/unixnu/code/umi-work-pin
IMG=$W/out/umi-xnu/umi/userdata/userdata-root.img

echo "== 1. 磁盘余量 =="
df -h /home/unixnu /mnt/e 2>&1 | sed 's/^/  /'

echo
echo "== 2. SHNGROOT manifest 解出来的窗口表（名字/偏移/大小）=="
python3 - "$IMG" <<'PY'
import struct, sys, hashlib
p = sys.argv[1]
with open(p, 'rb') as f:
    head = f.read(4096)
magic, version, count, image_bytes = struct.unpack_from('<4sIII', head, 0)
print(f"  magic={magic!r} version={version} count={count} image_bytes={image_bytes}")
for i in range(count):
    off, size = struct.unpack_from('<QQ', head, 16 + 128*i)
    name = head[16 + 128*i + 112: 16 + 128*i + 128].split(b'\0')[0].decode('utf-8', 'replace')
    print(f"  [{i}] off=0x{off:x} size={size} ({size>>20} MiB) tail16={head[16+128*i+112:16+128*i+128].hex()} name_guess={name!r}")
PY

echo
echo "== 3. 系统里已有的 APFS 读取器（命令行）=="
for b in apfs-fuse apfs-dump apfsck fsapfsinfo apisfs; do printf '  %-12s %s\n' "$b" "$(command -v $b || echo 无)"; done

echo
echo "== 4. pip 能不能装 apisfs（只查索引，不装）=="
timeout 90 pip3 download --no-deps --dest /tmp/apisfs-probe apisfs 2>&1 | tail -5
ls -la /tmp/apisfs-probe 2>/dev/null | tail -3

echo
echo "== 5. 已解密的两个 DMG 头部（koly/UDIF 还是裸 APFS？）=="
for d in "$W"/out/umi-xnu/ipsw/21H461/*.dmg; do
  printf '  %s\n' "$d"
  python3 -c "
import sys
p=sys.argv[1]
f=open(p,'rb'); head=f.read(64); f.seek(-512,2); tail=f.read(512)
print('    first16:', head[:16].hex())
print('    koly@tail-512:', tail[:4]==b'koly')
print('    NXSB@0x20 in head:', head[32:36]==b'NXSB')
" "$d"
done
