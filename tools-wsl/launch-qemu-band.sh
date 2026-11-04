#!/bin/bash
# H 步自测：用 trace 档内核在 QEMU 里跑一遍，读回 screen.png 看画屏进度带是否真的出现
# 出现红/蓝/黄带 = 仪器成立；只剩绿带 = 仪器不成立（内核已越过开 MMU）
set -u
NAME=${1:-run-19-band}
IMG=${2:-/home/unixnu/code/UniXNU-main/build/native-user-fixture-umi/launchd.macho}
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
cd /mnt/e/Code/HackIos || exit 1
export KERNEL=out/umi-xnu/umi/kernel/entry-trace-kernel.macho
setsid nohup bash tools-wsl/run-umi-qemu.sh "$NAME" \
  --mockfs-initrd "$IMG" \
  --args "-v keepsyms=1 kt_fixed_zones=120" \
  --capture-screen --timeout 240 \
  > "$LOGD/qemu-$NAME.launch.log" 2>&1 &
echo "pid=$! NAME=$NAME LOG=$LOGD/qemu-$NAME.launch.log"
