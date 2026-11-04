#!/bin/bash
# 用新内核（带 boot-stage 桩）重打真机 mockfs 镜像，不改手机。
set -u
LOG=/mnt/e/Code/HackIos/out/repack-stage.txt
: > "$LOG"
exec >>"$LOG" 2>&1
INITRD=/home/unixnu/code/UniXNU-main/build/native-user-fixture-umi/launchd.macho
echo "== 0. 内核指纹 =="
sha256sum /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
ls -la "$INITRD" 2>&1
echo
echo "== 1. payload 卷 =="
python3 /mnt/e/Code/HackIos/tools-wsl/build-xnu-payload.py --mockfs-initrd "$INITRD"
echo "payload rc=$?"
echo
echo "== 2. bootimg + 自检 =="
bash /mnt/e/Code/HackIos/tools-wsl/pack-menu-xnu.sh
echo "pack rc=$?"
echo "== done =="
