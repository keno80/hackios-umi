#!/bin/bash
# 跑 GPT/卷 UUID 取证 + Linux host 自检重试（两件事互不依赖，一趟出）。
exec > /mnt/e/Code/HackIos/out/probes/u101-run.txt 2>&1
set -u
PIN=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
T=$PIN/out/umi-xnu/umi/tree
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C CLT_PREFIX=$TC/CommandLineTools/usr XCTOOLCHAIN_PREFIX=$TC/XcodeDefault.xctoolchain/usr
export XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"
export UNIXNU_SDKROOT=$T/.cache/fakeroot UNIXNU_SDK_VERSION=17.0
export UNIXNU_PLATFORM_PATH=$T/.cache/fakeroot/Platforms/iPhoneOS.platform

echo "== 0. 宿主编译器 =="
for c in /usr/bin/gcc /usr/bin/cc /usr/bin/clang; do
  printf '  %-14s %s\n' "$c" "$([ -x "$c" ] && $c --version 2>&1 | head -1 || echo 无)"; done
echo "  multiarch=$(gcc -print-multiarch 2>&1)  /usr/include/$(gcc -print-multiarch 2>/dev/null)=$([ -d /usr/include/$(gcc -print-multiarch 2>/dev/null) ] && echo 有 || echo 缺)"

echo
echo "== 1. GPT 与卷 UUID =="
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/probe-gpt-volume-uuid.sh > /tmp/probe-gpt-volume-uuid.sh
timeout 900 bash /tmp/probe-gpt-volume-uuid.sh; echo "gpt rc=$?"

echo
echo "== 2. Linux host 自检重试 =="
rm -rf /tmp/vr-linux; mkdir -p /tmp/vr-linux
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/verified-root-host-check-linux.py > /tmp/vrcheck.py
timeout 600 python3 -u /tmp/vrcheck.py --output /tmp/vr-linux \
  --kit $PIN/sources/UniXNU/kits/VerifiedRoot --openssl-prefix /usr 2>&1 | tail -25
echo "host-check rc=${PIPESTATUS[0]}"
echo
ls -la /tmp/vr-linux 2>&1
file /tmp/vr-linux/verified-root.dylib 2>&1
file /tmp/vr-linux/verified-root-arm64.o 2>&1
cat /tmp/vr-linux/checks.json 2>&1
echo done
