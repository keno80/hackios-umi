#!/bin/bash
# 手工复现 Info.obj 那次编译（用日志里的原命令，一条不差）
L=/home/unixnu/code/umi-work-pin/out/umi-fw/run-05/firmware.log
D=/home/unixnu/code/umi-work-pin/out/umi-fw/manual
mkdir -p $D
grep -o '"[^"]*clang" -MMD -MF [^ ]*EnhancedFatDxe/Fat/OUTPUT/Info.obj.deps.*' $L | tail -1 > $D/info-cmd.txt
{
echo "== 命令长度: $(wc -c < $D/info-cmd.txt)"
echo "== 尾巴 200 字符"
tail -c 200 $D/info-cmd.txt
echo "== 单独执行"
bash $D/info-cmd.txt
echo "rc=$?"
echo "== 产物"
ls -l /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/AARCH64/FatPkg/EnhancedFatDxe/Fat/OUTPUT/Info.obj 2>&1
echo "== seed-data-grow.py 头部"
head -30 /home/unixnu/code/umi-work-pin/devices/umi/package/data-store/seed-data-grow.py
} > $D/info-out.txt 2>&1
cp $D/info-out.txt /mnt/e/Code/HackIos/out/probes/fw06-info.txt
echo WROTE
