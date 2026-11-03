#!/bin/bash
# QEMU 固件里程碑的前置检查：edk2/Mu_Basecore、交叉 gcc、BaseTools、venv python
set -u
echo "== Mu_Basecore / edk2 位置 =="
for d in /home/unixnu/code/Mu_Basecore /home/unixnu/code/uefi-umi/Mu_Basecore \
         /mnt/e/Code/HackIos/uefi-umi/Mu_Basecore \
         /home/unixnu/code/UniXNU-main/out/feeds/edk2*; do
  [ -e "$d" ] && echo "存在 $d ($(ls "$d" 2>/dev/null | wc -l) 项)" || echo "缺失 $d"
done
echo "== UniXNU package 目录 =="
ls /home/unixnu/code/UniXNU-main/package 2>/dev/null | head -8
echo "== 交叉工具链 =="
for t in aarch64-linux-gnu-gcc aarch64-linux-gnu-g++ dtc; do
  command -v "$t" >/dev/null && echo "OK   $t $($t --version 2>/dev/null | head -1)" || echo "缺失 $t"
done
echo "== qemu =="
command -v qemu-system-aarch64 >/dev/null && qemu-system-aarch64 --version | head -1 || echo "缺失 qemu"
ls /usr/share/qemu-efi-aarch64/ 2>/dev/null
echo "== host clang（edk2 CLANGPDB 需要能出 ELF aarch64） =="
command -v clang >/dev/null && clang --version | head -2 || echo "无 host clang"
echo "== 内核构建产物 =="
ls -la /home/unixnu/code/umi-work/out/umi-xnu/umi/kernel/ 2>/dev/null | head -5
ls -la /home/unixnu/code/UniXNU-main/out/ 2>/dev/null | head -10
