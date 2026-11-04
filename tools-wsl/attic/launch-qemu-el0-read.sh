#!/bin/bash
# 让引导一路跑到 EL0，超时时读回 fixture 的 _results/_user_page_size/_old_length
set -u
NAME=${1:-run-17-el0-read}
IMG=${2:-/home/unixnu/code/UniXNU-main/build/native-user-fixture-umi/launchd.macho}
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
cd /mnt/e/Code/HackIos || exit 1
setsid nohup bash tools-wsl/run-umi-qemu.sh "$NAME" \
  --mockfs-initrd "$IMG" \
  --args "-v keepsyms=1 kt_fixed_zones=120" \
  --read-user-address 100004000:20 \
  --read-user-address 100004028:8 \
  --read-user-address 100004030:8 \
  --capture-screen --timeout 360 \
  > "$LOGD/qemu-$NAME.launch.log" 2>&1 &
echo "pid=$! LOG=$LOGD/qemu-$NAME.launch.log"
sleep 8
pgrep -fa run_umi_qemu | head -2
echo LAUNCHED
