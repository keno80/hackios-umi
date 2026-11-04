#!/bin/bash
set -u
cd /mnt/e/Code/HackIos || exit 1
B=UniXNU-main/scripts/build-xnu-4k-baseline.sh
{
  echo "== A. umi 仓 scripts 清单 =="
  ls -1 UniXNU-umi/scripts 2>&1 | head -40
  echo ""
  echo "== B. build_umi_xnu.py 里 owner-root / storage / 环境开关 =="
  grep -n -E 'owner.root|OWNER_ROOT|SOURCE_STORAGE|VIRTIO|RAM_BLOCK|MOCKFS|XNU_[A-Z_]+' UniXNU-umi/scripts/build_umi_xnu.py 2>&1 | head -60
  echo ""
  echo "== C. baseline 脚本关键判定段 =="
  echo "-- 78..120 --"; sed -n '78,120p' "$B"
  echo "-- 195..260 --"; sed -n '195,260p' "$B"
  echo "-- 275..305 --"; sed -n '275,305p' "$B"
  echo "-- 680..740 --"; sed -n '680,740p' "$B"
  echo ""
  echo "== D. virtio-mmio-block 归档由谁产出、是否需 Apple 件 =="
  grep -n -E 'ipsw|kernelcache|original|audit|sha256|require' UniXNU-main/scripts/build-virtio-mmio-bindings.py 2>&1 | head -30
  echo ""
  echo "== E. RamBlock 驱动源文件 =="
  find UniXNU-main/drivers/RamBlock UniXNU-main/drivers/VirtioMmioBlock -maxdepth 1 -type f 2>&1 | head -20
} > out/umi-owner-root-profile.txt 2>&1
echo done >> out/umi-owner-root-profile.txt
