#!/bin/bash
# M 步：打「mockfs 假根 + 走查件 + EL0 IN/OUT」真机档。
# 内核用 QEMU 验过的同一份 source-kernel.macho（不带 --early-trace），
# 这样屏上判据与 QEMU 侧逐字节同源；INITRD 换成 12 发走查件。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/repack-walk.txt
: > "$LOG"
exec >>"$LOG" 2>&1
INITRD=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho

echo "== 0. 输入指纹 =="
sha256sum "$K"
sha256sum "$INITRD"
ls -la "$INITRD"
M=$(strings -a "$K" | grep -c mockfs)
P=$(strings -a "$K" | grep -c 'MR exhausted last=')
A1=$(strings -a "$K" | grep -c -F 'INIT try')
A2=$(strings -a "$K" | grep -c -F 'INIT exec ok')
A3=$(strings -a "$K" | grep -c -F 'INIT returned')
A4=$(strings -a "$K" | grep -c -F 'EL0 MACH')
A5=$(strings -a "$K" | grep -c -F 'EL0 IN svc=')
A6=$(strings -a "$K" | grep -c -F 'EL0 OUT svc=')
echo "mockfs=$M 挂根探针=$P init=$A1/$A2/$A3 el0=$A4/$A5/$A6"
if [ "$M" -lt 50 ] || [ "$P" -ne 1 ] || [ "$A1" -lt 1 ] || [ "$A2" -lt 1 ] || \
   [ "$A3" -lt 1 ] || [ "$A4" -lt 1 ] || [ "$A5" -lt 1 ] || [ "$A6" -lt 1 ]; then
  echo "== 拒绝出图：内核缺假根驱动或 EL0 IN/OUT 探针（mockfs=$M mr=$P init=$A1/$A2/$A3 el0=$A4/$A5/$A6）"
  echo "   上机一次的成本远高于一道断言，别把手机时间花在没带判据的档上。"
  exit 1
fi
echo
echo "== 1. payload 卷 =="
python3 /mnt/e/Code/HackIos/tools-wsl/build-xnu-payload.py \
  --kernel "$K" --title "M-WALK Mi 10 8G" --mockfs-initrd "$INITRD"
echo "payload rc=$?"
echo
echo "== 2. bootimg + 自检 + 交付"
bash /mnt/e/Code/HackIos/tools-wsl/pack-menu-xnu.sh
echo "pack rc=$?"
echo
echo "== 3. 改名交付（不留同字节的两份让人猜哪个是新的）=="
XNU=/mnt/e/Code/HackIos/out/images/umi-uefi-menu-xnu.img
NEW=/mnt/e/Code/HackIos/out/images/umi-uefi-menu-walk.img
if [ -f "$XNU" ] && [ "$XNU" -nt "$K" ]; then
  mv -f "$XNU" "$NEW"
  ls -l "$NEW" | sed 's#^# #'
  sha256sum "$NEW" | sed 's#^# #'
else
  echo "== 跳过：$XNU 不存在或不比内核新（本轮自检未过，别把上一轮的镜像当新的）"
fi
echo "== done $(date -u +%FT%TZ)"
