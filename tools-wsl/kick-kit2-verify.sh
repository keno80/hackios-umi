#!/bin/bash
# 静态验证新内核 kit（AES mode 是否进 kit）+ 后台起 QEMU 自测 + 打包 rev4
set -u
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped
SK=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
OUT=/mnt/e/Code/HackIos/out/kit2-verify.txt
{
  echo "== source-kernel sha"
  sha256sum "$SK" | cut -c1-32
  ls -l "$SK"
  echo "== register 里取的模式访问器"
  llvm-nm -n --defined-only "$K" | grep -E '_umi_crypto_kit_register$'
  A=$(llvm-nm --defined-only "$K" | awk '/_umi_crypto_kit_register$/{print $1}')
  START=0x$A
  # 函数长度未知：反汇编到下一个符号前
  END=$(llvm-nm -n --defined-only "$K" | awk -v s="$A" '$1>s{print "0x"$1; exit}')
  llvm-objdump -d --start-address=$START --stop-address=$END "$K" 2>/dev/null | grep -oE '<_[a-z0-9_]+>' | sort -u | tr -d '<>'
  echo "== 计数"
  llvm-objdump -d --start-address=$START --stop-address=$END "$K" 2>/dev/null | grep -cE 'bl'
} > "$OUT" 2>&1
cd /mnt/e/Code/HackIos || exit 1
setsid nohup bash tools-wsl/launch-qemu-screen.sh run-11-kit2 > /mnt/e/Code/HackIos/out/kit2-qemu-launch.txt 2>&1 &
echo "qemu-launcher-pid=$!"
setsid nohup bash tools-wsl/run-pack-rev3.sh > /mnt/e/Code/HackIos/out/kit2-pack-launch.txt 2>&1 &
echo "pack-launcher-pid=$!"
echo done
