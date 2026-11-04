#!/bin/bash
set -u
cd /mnt/e/Code/HackIos || exit 1
O=out/umi-root-provider.txt
: > "$O"
{
  echo "== A. UniXNU-umi 设备仓结构 =="
  ls -1 UniXNU-umi 2>&1 | head -25
  echo "-- board/config 文件 --"
  find UniXNU-umi -maxdepth 2 -name '*.toml' -o -maxdepth 2 -name '*defconfig*' -o -maxdepth 2 -name 'configs' -type d 2>/dev/null | head -20
  echo ""
  echo "== B. umi defconfig 全文（前 80 行）=="
  find UniXNU-umi -name '*umi*defconfig*' 2>/dev/null | head -3
  for f in $(find UniXNU-umi -name '*umi*defconfig*' 2>/dev/null | head -1); do sed -n '1,80p' "$f"; done
  echo ""
  echo "== C. 上游 RamBlock / VirtioMmioBlock / ArmVirtPlatform 驱动文件 =="
  ls -1 UniXNU-main/drivers/RamBlock 2>&1 | head -15
  ls -1 UniXNU-main/drivers/VirtioMmioBlock 2>&1 | head -15
  ls -1 UniXNU-main/drivers/ArmVirtPlatform 2>&1 | head -15
  echo ""
  echo "== D. components.toml 里这几个组件的条目 =="
  grep -n -A12 -E '^\[?(RamBlock|VirtioMmioBlock|ArmVirtPlatform|VerifiedRoot|XnuPrelink)' UniXNU-main/components.toml 2>&1 | head -80
  echo ""
  echo "== E. 构建系统里 SOURCE_MOCKFS / NATIVE_RAM_BLOCK / NATIVE_VIRTIO_BLOCK 的落点 =="
  grep -rn -E 'SOURCE_MOCKFS|NATIVE_RAM_BLOCK|NATIVE_VIRTIO_BLOCK|OWNER_ROOT_AUDIT' UniXNU-main/unixnu UniXNU-main/scripts UniXNU-main/profiles 2>/dev/null | head -30
} >> "$O" 2>&1
echo done >> "$O" 2>&1
