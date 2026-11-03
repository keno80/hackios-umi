#!/bin/bash
set -u
cd /mnt/e/Code/HackIos || exit 1
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
O=out/mockfs-prereq.txt
: > "$O"
{
  echo "== A. xnu-work/bsd/dev 目录（找 md/mdev）=="
  ls -1 "$T/.cache/xnu-work/bsd/dev" 2>&1 | head -20
  ls -1 "$T/.cache/xnu-work/bsd/dev/arm" 2>&1 | head -20
  echo ""
  echo "== B. mdev / md 设备在内核源里的实现与注册 =="
  grep -rn -E 'mdev_lookup|MI_MDEV|mdev_create|"md0"|md%d|mi_mdev' "$T/.cache/xnu-work" 2>/dev/null | head -25
  echo ""
  echo "== C. rd= 引导参数解析位置 =="
  grep -rn -E 'rd=|root_bsd_name|BSD_ROOT|kModBootRoot' "$T/.cache/xnu-work/bsd/kern/bsd_init.c" 2>/dev/null | head -25
  echo ""
  echo "== D. IOKitBSDInit.cpp 999 行附近 =="
  sed -n '960,1010p' "$T/.cache/xnu-work/bsd/dev/driverkit/../../pexpert/../bsd" 2>/dev/null | head -3
  find "$T/.cache/xnu-work" -name IOKitBSDInit.cpp 2>/dev/null | head -2
  for f in $(find "$T/.cache/xnu-work" -name IOKitBSDInit.cpp 2>/dev/null | head -1); do
    echo "-- $f 975..1005 --"; sed -n '975,1005p' "$f"
  done
  echo ""
  echo "== E. linux xcrun shim 支持哪些子命令 =="
  cat UniXNU-main/scripts/linux/xcrun 2>&1 | head -40
  echo ""
  echo "== F. umi package 配置里 initrd/ramdisk 的支持 =="
  grep -rn -E 'initrd|ramdisk|Payloads/' UniXNU-umi/package/*.toml UniXNU-umi/board.toml 2>/dev/null | head -25
  echo ""
  echo "== G. mockfs_mountroot 全文（umi 树）=="
  sed -n '60,140p' "$T/.cache/xnu-work/bsd/miscfs/mockfs/mockfs_vfsops.c" 2>&1
} >> "$O" 2>&1
echo done >> "$O" 2>&1
