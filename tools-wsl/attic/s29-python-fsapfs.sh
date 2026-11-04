#!/bin/bash
# s28 装了 python3-fsapfs 但 import 失败，且 apt 被一个坏掉的 apfs-dkms 后处理脚本拖住（exit 10）。
# 本文件只查四件事，不改动任何东西：
#   1) which -a python3 到底是哪个解释器（UniXNU 工具链会不会遮蔽系统 python）；
#   2) python3-fsapfs 这个包把 .so 装到哪、哪个 abi；
#   3) 已装的 libfsapfs-utils 提供哪些命令行工具（有没有比 python 更直接的路）；
#   4) apfs-dkms 的破状态是谁装的、能不能绕开它（不卸载，先看）。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s29-python-fsapfs.txt 2>&1

echo "== 1. python3 解析 =="
which -a python3 python
python3 -V 2>&1
ls -l /usr/local/bin/python* 2>/dev/null
echo "  sys.path:"; python3 -c 'import sys;print("\n".join("    "+p for p in sys.path))' 2>&1
echo "  /usr/bin/python3:"; /usr/bin/python3 -V 2>&1

echo
echo "== 2. python3-fsapfs 包内容 =="
dpkg -L python3-fsapfs 2>&1 | head -20
echo "  实际文件："
ls -l /usr/lib/python3/dist-packages/ 2>/dev/null | grep -i fsapfs

echo
echo "== 3. libfsapfs-utils 提供的工具 =="
dpkg -L libfsapfs-utils 2>&1 | grep -E 'bin/' 
echo "  libfsapfs 运行库："
ls -l /usr/lib/x86_64-linux-gnu/libfsapfs* 2>/dev/null

echo
echo "== 4. apfs-dkms 状态 =="
dpkg -l | grep -iE 'apfs|dkms' | sed 's/^/  /'
echo "  dkms 状态文件："
ls -l /var/lib/dkms/ 2>/dev/null | head
echo "  dpkg 里处于半配置的包："
grep -l 'Status:.*half-configured' /var/lib/dpkg/status >/dev/null 2>&1 && awk '/^Package:/{p=$2} /Status:.*half-configured/{print "  "p}' /var/lib/dpkg/status

echo
echo "== 5. 直接试 /usr/bin/python3 能不能 import =="
/usr/bin/python3 -c 'import fsapfs; print("  OK fsapfs", fsapfs.get_version())' 2>&1 | tail -3
