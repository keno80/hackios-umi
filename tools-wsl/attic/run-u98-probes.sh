#!/bin/bash
# 收尾：杀掉 u95 的笨扫描，跑紧凑版 APFS 定位探测。
exec > /mnt/e/Code/HackIos/out/probes/u99-kill-and-run.txt 2>&1
set -u
echo "== 杀 u95 =="
pkill -f probe-apfs-window-layout 2>&1; echo "pkill rc=$?"
sleep 1
ps -eo pid,etimes,cmd | grep -E "probe-apfs|python3 -" | grep -v grep
sudo -n losetup -D 2>/dev/null
echo
echo "== 跑 u98 =="
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/probe-apfs-sb-and-uuid.sh > /tmp/probe-apfs-sb-and-uuid.sh
timeout 600 bash /tmp/probe-apfs-sb-and-uuid.sh
echo "u98 rc=$?"
echo
echo "== 顺带跑 Linux host 自检（不依赖 APFS 结果） =="
PIN=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
T=$PIN/out/umi-xnu/umi/tree
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C CLT_PREFIX=$TC/CommandLineTools/usr XCTOOLCHAIN_PREFIX=$TC/XcodeDefault.xctoolchain/usr
export XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"
export UNIXNU_SDKROOT=$T/.cache/fakeroot UNIXNU_SDK_VERSION=17.0
export UNIXNU_PLATFORM_PATH=$T/.cache/fakeroot/Platforms/iPhoneOS.platform
echo "  宿主编译器：$(command -v cc || echo 无) / $(command -v clang || echo 无)"
echo "  SDKROOT=$UNIXNU_SDKROOT 存在=$([ -d "$UNIXNU_SDKROOT" ] && echo 有 || echo 缺)"
echo "  xcrun=$(command -v xcrun || echo 无)"
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/verified-root-host-check-linux.py > /tmp/vrcheck.py
mkdir -p /tmp/vr-linux
timeout 600 python3 -u /tmp/vrcheck.py --output /tmp/vr-linux \
  --kit $PIN/sources/UniXNU/kits/VerifiedRoot \
  --openssl-prefix /usr 2>&1 | tail -30
echo "host-check rc=${PIPESTATUS[0]}"
echo
echo "== 产物 =="
ls -la /tmp/vr-linux 2>&1
file /tmp/vr-linux/verified-root.dylib 2>&1
file /tmp/vr-linux/verified-root-arm64.o 2>&1
cat /tmp/vr-linux/checks.json 2>&1
sudo -n losetup -D 2>/dev/null
echo done
