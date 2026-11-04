#!/bin/bash
# R 步：打「mockfs 假根 + 32 发走查件（23 unix + 9 mach）+ EL0 IN/OUT 逐号 + 28z zidx 判据」真机档。
# 内核用 QEMU 验过的同一份 source-kernel.macho（不带 --early-trace），
# 这样屏上判据与 QEMU 侧逐字节同源；INITRD 换成带 mach 段的走查件。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/repack-walk.txt
: > "$LOG"
exec >>"$LOG" 2>&1
INITRD=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
NM=$TC/CommandLineTools/usr/bin/nm

echo "== 0. 输入指纹 =="
sha256sum "$K"
sha256sum "$INITRD"
ls -la "$INITRD"
M=$(strings -a "$K" | grep -c mockfs)
P=$(strings -a "$K" | grep -c 'MR exhausted last=')
A1=$(strings -a "$K" | grep -c -F 'INIT try')
A2=$(strings -a "$K" | grep -c -F 'INIT exec ok')
A3=$(strings -a "$K" | grep -c -F 'INIT returned')
# 29z 之后 mach 侧不再有 'EL0 MACH' 串（与 unix 侧统一成 EL0 IN/OUT），
# 所以 mach 探针在不在产物里只能看 nm 的两张去重表；strings 看不到函数内静态量。
A5=$(strings -a "$K" | grep -c -F 'EL0 IN svc=')
A6=$(strings -a "$K" | grep -c -F 'EL0 OUT svc=')
MS=$("$NM" "$K" 2>/dev/null | grep -c 'umi_el0_mach_seen')
MO=$("$NM" "$K" 2>/dev/null | grep -c 'umi_el0_mach_out_seen')
# 28z：zidx panic 的屏上判据（真机偶发炸在建 zone 极早期窗口，一次拍照要能分清窗口/核号/槽号）
Z=$(strings -a "$K" | grep -c -F 'UMI28 nz=')
# P 步新增：fork/wait 闭环的三段判据，缺任何一段这档就不配上机
F1=$(strings -a "$K" | grep -c -F 'FORK cx0=0')
F2=$(strings -a "$K" | grep -c -F 'REAP cpid=')
F3=$(strings -a "$K" | grep -c -F 'WAIT4 reaped-return')
# Q 步新增：走查件本身的闸——内核有探针但件还是老件，上机就是白跑一趟
W1=$(strings -a "$INITRD" | grep -c -F 'UMI-WALK-Q-PIPE-PAYLOAD')
echo "mockfs=$M 挂根探针=$P init=$A1/$A2/$A3 el0=$A5/$A6 mach表=$MS/$MO zidx判据=$Z fork=$F1/$F2/$F3 走查件Q=$W1"
if [ "$M" -lt 50 ] || [ "$P" -ne 1 ] || [ "$A1" -lt 1 ] || [ "$A2" -lt 1 ] || \
   [ "$A3" -lt 1 ] || [ "$A5" -lt 1 ] || [ "$A6" -lt 1 ] || \
   [ "$MS" -lt 1 ] || [ "$MO" -lt 1 ] || [ "$Z" -lt 1 ] || \
   [ "$F1" -lt 1 ] || [ "$F2" -lt 1 ] || [ "$F3" -lt 1 ] || [ "$W1" -lt 1 ]; then
  echo "== 拒绝出图：内核缺假根驱动、EL0 逐号探针、mach 去重表、28z zidx 判据、fork/wait 闭环探针，或走查件不是 Q 版"
  echo "   （mockfs=$M mr=$P init=$A1/$A2/$A3 el0=$A5/$A6 mach表=$MS/$MO zidx判据=$Z fork=$F1/$F2/$F3 走查件Q=$W1）"
  echo "   上机一次的成本远高于一道断言，别把手机时间花在没带判据的档上。"
  exit 1
fi
echo
echo "== 1. payload 卷 =="
python3 /mnt/e/Code/HackIos/tools-wsl/build-xnu-payload.py \
  --kernel "$K" --title "R-WALK4 Mi 10 8G" --mockfs-initrd "$INITRD"
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
