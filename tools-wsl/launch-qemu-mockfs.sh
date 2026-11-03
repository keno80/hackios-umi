#!/bin/bash
# run-13-mockfs：用 --mockfs-initrd 把静态 launchd 发布成 RAMDisk，rd=md0 让内核挂 mockfs 假根
set -u
NAME=${1:-run-13-mockfs}
IMG=${2:-/home/unixnu/code/UniXNU-main/build/native-user-fixture-umi/launchd.macho}
# 第三参 go：不在 mountroot 入口停，让引导继续走到 exec launchd
if [ "${3:-}" = "go" ]; then ALSO=(); else ALSO=(--also-stop _mockfs_mountroot); fi
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
cd /mnt/e/Code/HackIos || exit 1
echo "IMG=$IMG size=$(stat -c %s "$IMG" 2>/dev/null)" >> "$LOGD/$NAME.launch.log"
setsid nohup bash tools-wsl/run-umi-qemu.sh "$NAME" \
  --mockfs-initrd "$IMG" \
  --args "-v keepsyms=1 kt_fixed_zones=120" \
  "${ALSO[@]}" \
  --capture-screen --timeout 300 \
  > "$LOGD/qemu-$NAME.launch.log" 2>&1 &
echo "pid=$! LOG=$LOGD/qemu-$NAME.launch.log"
sleep 8
pgrep -fa qemu-system-aarch64 | head -2
echo LAUNCHED
