#!/bin/bash
# 摸清真机 payload 通路：initrd/RAMDisk/kernel_args 各自在哪一步落地
P=$(find /home/unixnu/code/umi-work-pin/devices -name "make_umi_payload.py" | head -1)
echo "== payload tool: $P"
grep -nE "initrd|RAMDisk|memory-map|kernel_args|adt_storage_delta|args" "$P" | head -40
echo
echo "== board.toml kernel_args =="
grep -n -B3 -A6 "kernel_args" /home/unixnu/code/umi-work-pin/devices/umi/board.toml | head -40
echo
echo "== who writes unixnu.toml (真机菜单包) =="
grep -rln "unixnu.toml" /home/unixnu/code/umi-work-pin/devices/umi/scripts /home/unixnu/code/umi-work-pin/tools 2>/dev/null | head -10
echo
echo "== RAMDisk 占位在真机 adt 里怎么来 =="
grep -rn "RAMDisk" /home/unixnu/code/umi-work-pin/devices/umi/scripts/*.py 2>/dev/null | head -15
