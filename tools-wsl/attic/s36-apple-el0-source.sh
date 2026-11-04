#!/bin/bash
# 台阶1「塞一个真 Apple 件进假根 exec」的前置取证收口。
# 已知：上游 build-target-dyld-fixture.py 要的两件是
#   .cache/firmware/target-volumes/os-mount/sbin/launchd  (sha 8cec9a3c...)
#   .cache/firmware/target-volumes/os-mount/usr/lib/dyld  (sha f8df3c58...)
# 而 s34 里 libfsapfs 在 cryptex 卷的 B-tree 根节点直接断（invalid object type 0x0）。
# 本文件把剩下三个未知一次问清：
#   A) 真件是否已经在这台主机上（上游可能早就解出来了，那就白绕一圈）；
#   B) 两个 OS/ Cryptex DMG 到底是 UDIF 压缩还是裸容器、有没有加密段；
#   C) Linux 侧解 DMG→裸 APFS 的工具（dmg2img / 7z / 更新的 libfsapfs / ipsw）装不装得上。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s36-apple-el0-source.txt 2>&1
U=/home/unixnu/code/UniXNU-main
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
V=$T/.cache/firmware/target-volumes
IMG=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461

echo "== A1. 名字叫 launchd / dyld 的常规文件（排除源码与符号链接）=="
for root in "$U" /home/unixnu/code/umi-work-pin; do
  find "$root" -xdev \( -name launchd -o -name dyld -o -name 'launchd.macho' -o -name 'dyld.macho' \) \
       -type f -printf '%s\t%p\n' 2>/dev/null
done | sort -u

echo
echo "== A2. 这些候选里哪些是真 Mach-O（magic 0xfeedfacf + cputype 0x100000c）=="
python3 - <<'PY'
import glob, os, struct
cands = []
for root in ('/home/unixnu/code/UniXNU-main', '/home/unixnu/code/umi-work-pin'):
    for dirpath, dirnames, filenames in os.walk(root):
        for n in filenames:
            if n in ('launchd', 'dyld', 'launchd.macho', 'dyld.macho'):
                cands.append(os.path.join(dirpath, n))
for p in sorted(set(cands)):
    try:
        with open(p, 'rb') as f:
            head = f.read(32)
        magic, cputype, cpusub, filetype = struct.unpack_from('<4I', head)
        ok = magic == 0xfeedfacf and cputype == 0x100000c
        print(f'{"MACHO-ARM64" if ok else "  not-macho"} {os.path.getsize(p):>12} {p}')
    except Exception as e:
        print(f'  error      0 {p} {e}')
PY

echo
echo "== A3. target-volumes 目录现在有什么 =="
ls -la "$V" 2>&1 | head -30
echo "--- os-mount 子树（若有）---"
find "$V/os-mount" -maxdepth 3 2>/dev/null | head -40 || echo "  无 os-mount"

echo
echo "== B. 两个 DMG 的 UDIF 尾（koly）与块表 =="
python3 - "$IMG" <<'PY'
import os, plistlib, struct, sys
d = sys.argv[1]
for name in sorted(os.listdir(d)):
    if not name.endswith('.dmg'):
        continue
    p = os.path.join(d, name)
    size = os.path.getsize(p)
    with open(p, 'rb') as f:
        f.seek(max(0, size - 512))
        trailer = f.read(512)
    magic = trailer[0:4]
    print(f'--- {name}  size={size} ---')
    if magic != b'koly':
        print('  尾部无 koly：不是 UDIF，可能是裸镜像（APFS 直接对齐）')
        continue
    version, header_size, flags, blocksz, mblocksz = struct.unpack_from('<5I', trailer, 8)
    xmloff, xmllen = struct.unpack_from('<2Q', trailer, 48)
    print(f'  koly v{version} flags={flags:#x} blocksz={blocksz} xml@{xmloff}+{xmllen}')
    with open(p, 'rb') as f:
        f.seek(xmloff)
        plist = plistlib.loads(f.read(xmllen))
    for b in plist.get('blkx', []):
        ct = b.get('CompressionType')
        print(f"  blkx '{b.get('Name')}' type={b.get('Contents')} Compress={ct} "
              f"data={b.get('dataLength')} csum={b.get('ChecksumType')} "
              f"Enc={b.get('Encrypted') or b.get('encryptionHint')}")
PY

echo
echo "== C. Linux 侧解 DMG/APFS 的工具现状 =="
for t in dmg2img 7z 7za bsdtar ipsw apfs-fuse fsapfsinfo apfsmount macos-x; do
  printf '%-12s %s\n' "$t" "$(command -v "$t" || echo '-')"
done
echo "--- apt 候选 ---"
apt-cache policy dmg2img libfsapfs1t64 libfsapfs-utils apfsprogs 2>/dev/null | grep -A1 '^[a-z]'
echo "--- libfsapfs 版本 ---"
python3 -c 'import pyfsapfs; print("pyfsapfs", pyfsapfs.get_version())' 2>&1 | tail -2

echo
echo "== D. OS 卷（非 cryptex）libfsapfs 能不能走到根目录 =="
python3 - "$IMG/044-76040-038.dmg" <<'PY' 2>&1 | tail -25
import pyfsapfs, sys
c = pyfsapfs.container()
c.open(sys.argv[1], 'r')
print('containers', c.number_of_containers, 'volumes', c.number_of_volumes)
for i in range(c.number_of_volumes):
    v = c.get_volume(i)
    print('volume', i, v.name)
    try:
        r = v.get_root_directory()
        print('  root entries', r.number_of_file_entries)
        for k in range(min(r.number_of_file_entries, 40)):
            e = r.get_file_entry(k)
            print('   ', e.name, e.get_size())
    except Exception as ex:
        print('  ROOT FAIL:', str(ex).split('\n')[0][:300])
PY
