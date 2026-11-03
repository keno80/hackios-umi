#!/bin/bash
# 重跑路A（pin + Linux 回移），这次带 pbxproj/kernel_target/xnu_symbols 的纯 Python 回移
set -u
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs
pp=$(cat "$L/kernel-pin.pid" 2>/dev/null || true)
if [ -n "$pp" ] && kill -0 "$pp" 2>/dev/null; then echo "路A 仍在运行 pid=$pp"; exit 0; fi
run-kernel-pin
sleep 60
ab-status | sed -n '/路A/,$p'
