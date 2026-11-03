#!/bin/bash
set -u
cd /mnt/e/Code/HackIos || exit 1
G="git -C UniXNU-main"
F=FETCH_HEAD
O=out/upstream-root-recipe2.txt
: > "$O"
{
  echo "== A. PackedRAMDisk / DBRDISK1 的产生者与读者 =="
  $G grep -n -E 'DBRDISK1|PackedRAMDisk|packed_data_ramdisk' $F 2>&1 | head -40
  echo ""
  echo "== B. devices 目录清单（有哪些板、有没有 qemu）=="
  $G ls-tree --name-only $F -- devices 2>&1 | head -40
  echo ""
  echo "== C. umi 的 board.toml 全文 =="
  $G show $F:devices/umi/board.toml 2>&1 | head -120
  echo ""
  echo "== D. 谁写 root= 内核参数 / IOFindBSDRoot 的根说明 =="
  $G grep -n -E "root=|IOFindBSDRoot|BSD root|boot-root" $F -- 'devices' 'loader' 'scripts' 'src' 'kits' 'docs/.vitepress/guide' 2>&1 | head -50
} >> "$O" 2>&1
echo done >> "$O" 2>&1
