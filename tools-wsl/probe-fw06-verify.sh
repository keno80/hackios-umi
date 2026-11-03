#!/bin/bash
# #8 完成核验：FD 时间戳/尺寸/内容 + 日志结论行
L=/home/unixnu/code/umi-work-pin/out/umi-fw/run-06/firmware.log
FD=/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
{
echo "== 日志结论行"
grep -nE "^- (Done|Failed) -|Build total time|GenFv|build rc=" $L | tail -6
echo "== 外层收尾"
tail -12 /home/unixnu/code/umi-work-pin/out/umi-fw/run-06.outer.log | awk 'length($0)<300'
echo "== FD 时间戳与尺寸"
ls -l --time-style=full-iso $FD
stat -c '%s bytes  mtime=%y' $FD
echo "== 同目录其它 FV 产物"
ls -l /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/ | head -8
echo "== FD 头 16 字节（应为 EFI_FVH 特征）"
xxd -l 32 $FD
echo "== 菜单模块是否进镜像（找 UnixNU/Menu 相关 efi 名）"
ls /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/AARCH64/ -d 2>/dev/null | head -1
find /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/AARCH64 -maxdepth 1 -name '*.efi' | sed 's#.*/##' | grep -iE 'menu|unixnu|bringup|shell' | head -10
echo "== edk2 是否已回滚干净 + 软链复位"
git -C /home/unixnu/code/Mu_Basecore status --porcelain | wc -l
ls -ld /home/unixnu/code/uefi-umi-b/Mu_Basecore
} > /mnt/e/Code/HackIos/out/fw06-verify.txt 2>&1
echo WROTE
