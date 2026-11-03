#!/bin/bash
# 取证：启动 QEMU 自测（crypto kit 内核），状态落 out/qemu-kick.txt
OUTD=/mnt/e/Code/HackIos/out
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs
{
  echo "== kick $(date -Is)"
  ls -l "$L"/qemu-run-10-kit* 2>&1 | head -3
  cd /mnt/e/Code/HackIos || exit 1
  setsid nohup bash tools-wsl/launch-qemu-screen.sh run-10-kit \
    > "$OUTD/qemu-run10-inner.txt" 2>&1 &
  echo "launcher-pid=$!"
  sleep 8
  echo "== after 8s"
  pgrep -af 'qemu-system|run_umi_qemu' | head -5
  ls -l "$L"/qemu-run-10-kit.launch.log 2>&1
} > "$OUTD/qemu-kick.txt" 2>&1
