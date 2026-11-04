#!/bin/bash
# J7：打「mockfs 假根 + 挂根探针」真机镜像（FD 保持上机验证过的那份）
# 闸：内核里必须有 mockfs——上一轮就是刷了 mockfs=0 的 trace 档，白跑一次上机。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/repack-mockfs.txt
: > "$LOG"
exec >>"$LOG" 2>&1
INITRD=/home/unixnu/code/UniXNU-main/build/native-user-fixture-umi/launchd.macho
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho

echo "== 0. 输入指纹 =="
sha256sum "$K"
sha256sum /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
ls -la "$INITRD"
M=$(strings -a "$K" | grep -c mockfs)
P=$(strings -a "$K" | grep -c 'MR exhausted last=')
echo "mockfs 字符串=$M  探针字符串=$P"
if [ "$M" -lt 50 ] || [ "$P" -ne 1 ]; then
  echo "== 拒绝出图：内核缺假根驱动或缺探针（M=$M P=$P），别把上机时间花在已知空链上"
  exit 1
fi
echo
echo "== 1. payload 卷 =="
python3 /mnt/e/Code/HackIos/tools-wsl/build-xnu-payload.py \
  --kernel "$K" --title "Mi 10 8G - MOCKFS+PROBE" --mockfs-initrd "$INITRD"
echo "payload rc=$?"
echo
echo "== 2. bootimg + 自检 + 交付"
bash /mnt/e/Code/HackIos/tools-wsl/pack-menu-xnu.sh
echo "pack rc=$?"
echo
echo "== 3. 改名交付（不留同字节的两份让人猜哪个是新的）=="
XNU=/mnt/e/Code/HackIos/out/images/umi-uefi-menu-xnu.img
NEW=/mnt/e/Code/HackIos/out/images/umi-uefi-menu-mockfs.img
if [ -f "$XNU" ] && [ "$XNU" -nt "$K" ]; then
  mv -f "$XNU" "$NEW"
  ls -l "$NEW" | sed 's#^# #'
  sha256sum "$NEW" | sed 's#^# #'
else
  echo "== 跳过：$XNU 不存在或不比内核新（本轮自检未过，别把上一轮的镜像当新的）"
fi
echo "== done $(date -u +%FT%TZ)"
