#!/bin/bash
# run-05 的真实编译报错 + --data-ramdisk 的输入契约
L=/home/unixnu/code/umi-work-pin/out/umi-fw/run-05/firmware.log
F=/home/unixnu/code/umi-work-pin/devices/umi/bringup/tools/build_umi_xnu.py
{
echo "== error: 上下文"
grep -n "error:" $L | head -10 | cut -c1-400
echo "== Info.obj 那次编译前后 30 行（截断到 300 字符）"
N=$(grep -n "EnhancedFatDxe/Fat/OUTPUT/Info.obj" $L | tail -1 | cut -d: -f1)
sed -n "$((N-25)),$((N+12))p" $L | cut -c1-260
echo "== --data-ramdisk 定义与 seed 契约（78..96）"
sed -n '50,56p;78,96p' $F
} > /mnt/e/Code/HackIos/out/probes/fw05-err.txt 2>&1
echo WROTE
