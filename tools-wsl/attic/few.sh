#!/bin/bash
# 只打印短行里的报错（edk2 日志里编译命令是超长行，会淹没真正的 error）
f=$1
awk 'length($0) < 400' "$f" | grep -n -i -E "error|fatal|cannot|not found|no such|undefined|failed" | grep -v -i "Werror\|error 7000: Failed to execute command\|m a k e" | tail -25
