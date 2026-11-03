#!/bin/bash
# 重发：QEMU run-11-kit2 + 打包 rev4；父进程驻留 20s 确认子进程活着
set -u
OUTD=/mnt/e/Code/HackIos/out
cd /mnt/e/Code/HackIos || exit 1
setsid nohup bash tools-wsl/launch-qemu-screen.sh run-11-kit2 > "$OUTD/kit2-qemu-launch.txt" 2>&1 &
echo "qemu-launcher=$!"
setsid nohup bash tools-wsl/run-pack-rev3.sh > "$OUTD/kit2-pack-launch.txt" 2>&1 &
echo "pack-launcher=$!"
sleep 20
{
  echo "== 20s 后进程"
  pgrep -af 'run_umi_qemu|qemu-system-aarch64|build-xnu-payload|pack-menu-xnu' | head -6
  echo "== launch 文件"
  ls -l "$OUTD/kit2-qemu-launch.txt" "$OUTD/kit2-pack-launch.txt" 2>&1
  cat "$OUTD/kit2-qemu-launch.txt" 2>&1
  echo "== run dir"
  ls -d /home/unixnu/code/umi-work-pin/out/umi-qemu/run-11-kit2 2>&1
} > "$OUTD/kit2-relaunch.txt" 2>&1
echo done
