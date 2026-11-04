#!/bin/bash
# QEMU 固件里程碑前置：装 aarch64 交叉 gcc，把 Mu_Basecore(pin) 复制到 ext4
set -u
export DEBIAN_FRONTEND=noninteractive
source /usr/local/bin/unixnu-env
apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu > /tmp/xgcc.out 2>&1
echo "交叉 gcc exit=$? $(aarch64-linux-gnu-gcc --version 2>/dev/null | head -1)"
DST=/home/unixnu/code/Mu_Basecore
if [ ! -d "$DST" ]; then
  ts=$(date +%s)
  cp -a /mnt/e/Code/HackIos/uefi-umi/Mu_Basecore "$DST"
  echo "复制 exit=$? 用时=$(( $(date +%s) - ts ))s 文件=$(find "$DST" -type f | wc -l)"
fi
echo "Mu_Basecore HEAD=$(git -C "$DST" rev-parse HEAD 2>/dev/null)"
echo "期望               cfb93724a06ff86ff5ba971413368a7809ee42a5"
du -sh "$DST"
