#!/bin/bash
# 接 s26：Cryptex1,SystemOS 那个 .dmg 头部 0x20 就是 NXSB ⇒ 它本身就是**裸 APFS 容器**，
# 不需要再过 udif。OS 那个才是 UDIF（尾部 koly）。所以「取一个真 Apple 的 EL0 件」现在只差
# 一个 Linux 侧的 APFS 读取器。本文件把可选读取器一次问完，并先用 fsapfsinfo 确认容器真能认。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s27-apfs-read.txt 2>&1
W=/home/unixnu/code/umi-work-pin
SYSOS=$W/out/umi-xnu/ipsw/21H461/044-76034-038.dmg
OS=$W/out/umi-xnu/ipsw/21H461/044-76040-038.dmg

echo "== 1. fsapfsinfo 能不能直接吃这个 3.3G 裸容器 =="
timeout 180 fsapfsinfo "$SYSOS" 2>&1 | head -40

echo
echo "== 2. libyal 系（python 绑定 / FUSE 挂载工具）在源里有没有 =="
apt-cache search fsapfs 2>/dev/null | head -10
apt-cache policy python3-fsapfs 2>/dev/null | head -6
apt-cache policy libfsapfs-utils 2>/dev/null | head -6
echo "--- apfs-fuse / apfsprogs 源码包："
apt-cache policy apfs-fuse apfsprogs 2>/dev/null | grep -E '^[a-z]|Candidate' | head -10

echo
echo "== 3. 容器里卷的名字（fsapfsinfo 的 volume 段）=="
timeout 180 fsapfsinfo -v "$SYSOS" 2>&1 | head -30 || echo "  -v 不支持"

echo
echo "== 4. OS 那个 DMG 用上游 udif.py 能不能在 Linux 解出裸镜像（只做 dry：读 koly 元数据）=="
python3 - <<'PY'
import sys
sys.path.insert(0, '/home/unixnu/code/UniXNU-main/scripts')
from unixnu import udif
p = '/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461/044-76040-038.dmg'
img = udif.Image(p)
print('  size=', img.size, 'blocks=', len(img.blocks()))
PY

echo
echo "== 5. ipsw-inputs.json 里有没有 RestoreRamDisk（cpio 路线，绕开 APFS 的备选）=="
cat /home/unixnu/code/umi-work-pin/devices/umi/ipsw-inputs.json
