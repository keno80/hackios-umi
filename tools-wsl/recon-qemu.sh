#!/bin/bash
# 只读侦察：QEMU 运行器与 boot-args 注入通道；输出限长
W=/home/unixnu/code/umi-work-pin
{
echo '== 工作区 tools 目录'
ls $W/tools 2>/dev/null | head -30
echo '== run_umi_qemu.py 里的参数'
grep -n "add_argument\|boot_args\|boot-args\|kernel_args" $W/tools/run_umi_qemu.py 2>/dev/null | head -40
echo '== audit_umi_qemu.py 里 kt_fixed_zones 的用法'
grep -rn "kt_fixed_zones" $W/tools $W/../UniXNU-umi/bringup/tools 2>/dev/null | head -20
echo '== 全仓搜 kt_fixed_zones（排除 Build/.git）'
grep -rn --include=*.py --include=*.toml --include=*.md --include=*.c --include=*.h "kt_fixed_zones" \
  /home/unixnu/code/UniXNU /home/unixnu/code/umi-work-pin /home/unixnu/code/uefi-umi 2>/dev/null \
  | grep -v "/Build/" | head -20
echo '== 现有 out 目录'
ls -d $W/out/* 2>/dev/null | head -20
echo '== 内核产物'
ls -l $W/out/umi-xnu/umi/kernel/*.macho 2>/dev/null | head
echo DONE
} > /mnt/e/Code/HackIos/out/probes/qemu-recon.txt 2>&1
