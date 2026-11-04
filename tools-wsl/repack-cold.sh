#!/bin/bash
# L 步：打「红带 + mockfs 假根 + EL0 探针」冷启动归因档真机镜像
# 与 repack-mockfs.sh 同一条流水线，只把内核换成 entry-trace-kernel.macho，并多一道红带闸。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/repack-cold.txt
: > "$LOG"
exec >>"$LOG" 2>&1
INITRD=/home/unixnu/code/UniXNU-main/build/native-user-fixture-umi/launchd.macho
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/entry-trace-kernel.macho

echo "== 0. 输入指纹 =="
sha256sum "$K"
sha256sum /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
ls -la "$INITRD"
R=$(strings -a "$K" | grep -c 'UMI XNU')
M=$(strings -a "$K" | grep -c mockfs)
P=$(strings -a "$K" | grep -c 'MR exhausted last=')
A1=$(strings -a "$K" | grep -c -F 'INIT try')
A2=$(strings -a "$K" | grep -c -F 'INIT exec ok')
A3=$(strings -a "$K" | grep -c -F 'INIT returned')
A4=$(strings -a "$K" | grep -c -F 'EL0 MACH')
A5=$(strings -a "$K" | grep -c -F 'EL0 UNIX')
echo "红带=$R mockfs=$M 挂根探针=$P el0=$A1/$A2/$A3/$A4/$A5"
if [ "$R" -lt 1 ] || [ "$M" -lt 50 ] || [ "$P" -ne 1 ] || [ "$A1" -lt 1 ] || \
   [ "$A2" -lt 1 ] || [ "$A3" -lt 1 ] || [ "$A4" -lt 1 ] || [ "$A5" -lt 1 ]; then
  echo "== 拒绝出图：内核缺红带仪器、假根驱动或 EL0 探针（红带=$R mockfs=$M mr=$P init=$A1/$A2/$A3 el0=$A4/$A5）"
  echo "   上机一次的成本远高于一道断言，别把手机时间花在没带判据的档上。"
  exit 1
fi
echo
echo "== 1. payload 卷 =="
python3 /mnt/e/Code/HackIos/tools-wsl/build-xnu-payload.py \
  --kernel "$K" --title "L-COLD Mi 10 8G" --mockfs-initrd "$INITRD"
echo "payload rc=$?"
echo
echo "== 2. bootimg + 自检 + 交付"
bash /mnt/e/Code/HackIos/tools-wsl/pack-menu-xnu.sh
echo "pack rc=$?"
echo
echo "== 3. 改名交付（不留同字节的两份让人猜哪个是新的）=="
XNU=/mnt/e/Code/HackIos/out/images/umi-uefi-menu-xnu.img
NEW=/mnt/e/Code/HackIos/out/images/umi-uefi-menu-cold.img
if [ -f "$XNU" ] && [ "$XNU" -nt "$K" ]; then
  mv -f "$XNU" "$NEW"
  ls -l "$NEW" | sed 's#^# #'
  sha256sum "$NEW" | sed 's#^# #'
else
  echo "== 跳过：$XNU 不存在或不比内核新（本轮自检未过，别把上一轮的镜像当新的）"
fi
echo "== done $(date -u +%FT%TZ)"
