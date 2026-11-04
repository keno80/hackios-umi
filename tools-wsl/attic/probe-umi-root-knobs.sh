#!/bin/bash
set -u
cd /mnt/e/Code/HackIos || exit 1
O=out/umi-root-knobs.txt
: > "$O"
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
{
  echo "== 0. 工作区顶层 =="
  ls -1 /mnt/e/Code/HackIos | head -30
  echo ""
  echo "== 1. umi 工作树顶层 =="
  ls -1 "$W" 2>&1 | head -30
  echo ""
  echo "== 2. umi 板配置（board.toml / unixnu*.toml）=="
  find "$W" -maxdepth 3 -name '*.toml' 2>/dev/null | head -20
  echo ""
  echo "== 3. 本地 UniXNU-main 是否有 RamBlock/VirtioBlock/mockfs 驱动 =="
  ls -1 UniXNU-main/drivers 2>&1 | head -40
  echo ""
  echo "== 4. 本地 base 仓 mockfs fixture / ram block 脚本 =="
  ls -1 UniXNU-main/scripts 2>/dev/null | grep -i -E 'mockfs|ram|virtio|storage|verified-root|owner-root' | head -20
  echo ""
  echo "== 5. umi 内核 defconfig / config fragments 里的 ROOT/RAM/MOCKFS/STORAGE 开关 =="
  grep -rn -E 'MOCKFS|RAM_BLOCK|VIRTIO_BLOCK|OWNER_ROOT|VERIFIED_ROOT|NATIVE_UFS' "$W" 2>/dev/null | grep -v -E '\.o:|Binary' | head -40
} >> "$O" 2>&1
echo done >> "$O" 2>&1
