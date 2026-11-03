#!/bin/bash
# 依赖补齐（修正包名）+ 动态写入 apt 代理 + 工具链自检
set -u
gw=$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')
if [ -n "$gw" ]; then
  printf 'Acquire::http::Proxy "http://%s:8090";\nAcquire::https::Proxy "http://%s:8090";\n' "$gw" "$gw" > /etc/apt/apt.conf.d/95unixnu-proxy
  echo "apt proxy -> $gw:8090"
fi
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends \
  build-essential pkg-config ninja-build python3 python3-dev xz-utils libssl-dev \
  zlib1g-dev libbsd-dev uuid-dev llvm-dev libclang-dev device-tree-compiler \
  git patch flex bison bzip2 cpio rsync curl wget ca-certificates tcsh unifdef \
  cmake clang lld mtools libelf-dev > /tmp/toolchain-apt.log 2>&1
echo "apt exit=$?"
tail -3 /tmp/toolchain-apt.log
echo "=== 缺失的 host 工具 ==="
for t in git patch pkg-config ninja python3 xz bzip2 cpio rsync curl wget tcsh unifdef cmake clang ld ar mformat mcopy dtc fdtget fdtput llvm-config; do
  command -v "$t" >/dev/null || echo "MISSING $t"
done
echo "=== setup-toolchain --check ==="
cd /home/unixnu/code/UniXNU-main || exit 1
TMPDIR=/var/tmp python3 scripts/linux/setup-toolchain.py --check --package-manager none 2>&1 | tail -20
echo "check exit=$?"
