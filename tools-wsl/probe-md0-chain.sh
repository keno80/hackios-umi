#!/bin/bash
set -u
cd /mnt/e/Code/HackIos || exit 1
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=out/mockfs-md0-chain.txt
: > "$O"
{
  echo "== A. RAMDEV 的使用点 =="
  grep -rn 'RAMDEV' "$T/bsd" 2>/dev/null | head -20
  echo ""
  echo "== B. bsd_init.c 430..470 上下文 =="
  sed -n '425,475p' "$T/bsd/kern/bsd_init.c"
  echo ""
  echo "== C. mockfs_mountroot 的调用者与 vfs_mountroot 选 fs 的地方 =="
  grep -rn -E 'mockfs_mountroot|vfs_mountroot\b|rootonly|mount_root\(' "$T/bsd" 2>/dev/null | head -25
  echo ""
  echo "== D. IOKitBSDInit 里 rd=/root= 与 RAM 盘短路 =="
  grep -n -E '"rd=|rd=|rootdev|BSD_ROOT|PE_RamDiskAddress|ramDisk|md0' "$T/iokit/bsddev/IOKitBSDInit.cpp" 2>/dev/null | head -30
  echo ""
  echo "== E. create_memdev / DKIOCGETMEMDEVINFO 的建立者 =="
  grep -rn -E 'create_memdev|DKIOCGETMEMDEVINFO' "$T/bsd" 2>/dev/null | head -20
  echo ""
  echo "== F. PE_RamDisk* 引导信息 =="
  grep -rn -E 'PE_RamDiskAddress|PE_RamDiskSize' "$T" 2>/dev/null | head -12
} >> "$O" 2>&1
echo done >> "$O" 2>&1
