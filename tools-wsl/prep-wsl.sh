#!/bin/bash
# WSL 侧准备：磁盘余量、工具链依赖、把工作副本放进 ext4（避免 9P 拖慢构建）
set -u
echo "=== 内存/CPU ==="
nproc
free -g | head -2
echo "=== 磁盘 ==="
df -h / /var/tmp /mnt/d 2>/dev/null | grep -v tmpfs
echo "=== apt 安装工具链依赖 ==="
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends \
  build-essential pkg-config ninja-build python3 python3-dev xz-utils libssl-dev \
  zlib1g-dev libbsd-dev libuuid-dev llvm-dev libclang-dev device-tree-compiler \
  git patch flex bison bzip2 cpio rsync curl wget ca-certificates tcsh unifdef \
  cmake clang lld mtools libelf-dev >/tmp/toolchain-apt.log 2>&1
echo "apt exit=$?"
tail -3 /tmp/toolchain-apt.log
echo "=== 缺失的 host 工具 ==="
for t in git patch pkg-config ninja python3 xz bzip2 cpio rsync curl wget tcsh unifdef cmake clang ld ar mformat mcopy dtc fdtget fdtput llvm-config; do
  command -v "$t" >/dev/null || echo "MISSING $t"
done
echo "=== 工作副本 ==="
mkdir -p /home/unixnu/code
for r in UniXNU UniXNU-main UniXNU-umi UniXNU-sheng; do
  if [ -d "/mnt/e/Code/HackIos/$r" ]; then
    if [ -d "/home/unixnu/code/$r/.git" ]; then
      echo "已有 $r：$(git -C /home/unixnu/code/$r rev-parse --short HEAD)"
    else
      rsync -a --delete --exclude 'out' "/mnt/e/Code/HackIos/$r/" "/home/unixnu/code/$r/" && \
        echo "复制 $r：$(du -sh /home/unixnu/code/$r | cut -f1)"
    fi
  fi
done
