#!/bin/bash
# 依次跑 U 步之三的两份取证脚本（探测本体各自 exec 到 out/probes/）。
set -u
cd /mnt/e/Code/HackIos/tools-wsl || exit 1
for s in probe-manifest-linux-host probe-apfs-window-layout; do
  tr -d '\r' < "/mnt/e/Code/HackIos/tools-wsl/$s.sh" > "/tmp/$s.sh"
  bash "/tmp/$s.sh"
  echo "$s rc=$?"
done
sudo -n losetup -D 2>/dev/null
echo ALLDONE
