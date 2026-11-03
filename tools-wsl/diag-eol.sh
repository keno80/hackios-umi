#!/bin/bash
# 定性 umi 补丁失败原因：换行符 / 行尾空格 / -v 的逐 hunk 结果
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
work=$W/.cache/xnu-work
P=$W/patches/umi-xnu/early-entry-trace.patch
echo "== 补丁与目标的行尾 =="
file "$P" "$work/osfmk/arm64/start.s" "$work/osfmk/arm/arm_init.c"
echo "补丁 CRLF 行数=$(grep -c $'\r' "$P")"
echo "start.s CRLF 行数=$(grep -c $'\r' "$work/osfmk/arm64/start.s")"
echo "device 仓内补丁 CRLF 行数=$(grep -c $'\r' /home/unixnu/code/UniXNU-umi/patches/umi-xnu/early-entry-trace.patch)"
echo "git 里存的 blob：$(git -C /home/unixnu/code/UniXNU-umi ls-files --eol patches/umi-xnu/early-entry-trace.patch)"
echo
echo "== git apply --check -v =="
git -C "$work" apply --check -v "$P" 2>&1 | head -12
echo
echo "== 加 --ignore-whitespace =="
git -C "$work" apply --check --ignore-whitespace -v "$P" 2>&1 | head -12
echo
echo "== 第 37 行的字节（cat -A 前 4 行） =="
sed -n '36,40p' "$work/osfmk/arm64/start.s" | cat -A | head -6
echo "== 补丁前 12 行字节 =="
head -12 "$P" | cat -A
