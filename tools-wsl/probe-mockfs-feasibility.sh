#!/bin/bash
set -u
cd /mnt/e/Code/HackIos || exit 1
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
O=out/mockfs-md0-feasibility.txt
: > "$O"
{
  echo "== a. IOKitBSDInit 1060..1100（rd=/RAMDisk 是否短路）=="
  sed -n '1055,1100p' "$T/.cache/xnu-work/iokit/bsddev/IOKitBSDInit.cpp" 2>&1
  echo ""
  echo "== a2. IOKitBSDInit 里所有 PE_RamDisk / \"rd\" 引用 =="
  grep -n -E 'PE_RamDisk|PE_parse_boot_argn\("rd"|RamDisk' "$T/.cache/xnu-work/iokit/bsddev/IOKitBSDInit.cpp" 2>&1 | head -20
  echo ""
  echo "== b. 钉住的 xnu 源里到底有没有 md.c =="
  find "$T" -name 'md.c' -o -name 'md.h' 2>/dev/null | head -10
  echo "-- xnu 源根位置 --"
  ls -d "$T"/.cache/xnu* "$T"/refer/* 2>/dev/null | head -20
  echo ""
  echo "== b2. memdev.c 是否参与 iOS 构建（Makefile 里）=="
  grep -rn -E 'memdev|md\.o' "$T/.cache/xnu-work/bsd/Makefile" 2>&1 | head -15
  echo ""
  echo "== c. umi 的补丁清单里有没有 mockfs =="
  ls -1 "$T/patches" 2>/dev/null | head -20
  echo "-- umi 设备仓 patches --"
  find "$T/devices/umi/patches" -name '*mockfs*' 2>/dev/null | head -10
  ls -1 "$T/devices/umi/patches/umi-xnu" 2>/dev/null | head -40
  echo ""
  echo "== c2. 基线脚本从哪里取 mockfs 补丁 =="
  grep -rn 'mockfs' UniXNU-main/scripts/build-xnu-4k-baseline.sh UniXNU-main/scripts/prepare-um-xnu.py 2>/dev/null | head -20
  echo ""
  echo "== d. vfs_conf 里 mockfs 的注册条件 =="
  grep -n -B3 -A6 'mockfs' "$T/.cache/xnu-work/bsd/vfs/vfs_conf.c" 2>&1 | head -40
} >> "$O" 2>&1
echo done >> "$O" 2>&1
