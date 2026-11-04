#!/bin/bash
# 真机 mockfs 落地前的事实核对：菜单 toml 的 args 长什么样、谁用哪个 diagnostic、上机镜像怎么打
W=/home/unixnu/code/umi-work-pin
echo "== unixnu-xnu-prelink.toml =="
cat $W/devices/umi/package/unixnu-xnu-prelink.toml
echo
echo "== 谁调用 make_umi_payload（含 diagnostic）=="
grep -rn "make_umi_payload" $W/devices/umi $W/tools $W/bringup 2>/dev/null | grep -v "^Binary" | grep -v "make_umi_payload.py:" | head -20
echo
echo "== board.toml kernel_args 被谁消费 =="
grep -rn "kernel_args" $W/devices/umi/scripts/*.py $W/devices/umi/bringup/tools/*.py $W/tools/*.py 2>/dev/null | head -15
