#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/apfs-rw-module.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
K=$(uname -r)

say "== 1. WSL 内核头与版本判定 =="
say "kernel=$K build=$(readlink -f /lib/modules/$K/build 2>/dev/null)"
test -f /lib/modules/$K/build/Makefile && head -6 /lib/modules/$K/build/Makefile >> "$OUT"
make --version 2>&1 | head -2 >> "$OUT"
say "-- 源码里记录的版本限制 --"
grep -rn 'LINUX_VERSION_CODE\|KERNEL_VERSION' /usr/src/linux-apfs-rw*/ 2>/dev/null | head -10 >> "$OUT"
ls /usr/src 2>/dev/null | grep -i apfs >> "$OUT"

say
say "== 2. dkms 到底为什么拒绝 =="
tail -30 /var/lib/dkms/linux-apfs-rw/*/build/make.log 2>/dev/null | head -40 >> "$OUT"
say "-- dkms.conf --"
cat /usr/src/linux-apfs-rw*/dkms.conf 2>/dev/null | head -20 >> "$OUT"

say
say "== 3. 手工编译模块（绕开 dkms 的包名判定）=="
SRC=$(ls -d /usr/src/linux-apfs-rw* 2>/dev/null | head -1)
say "SRC=$SRC"
if [ -n "$SRC" ]; then
  rm -rf /tmp/apfs-build; mkdir -p /tmp/apfs-build
  cp -r "$SRC"/* /tmp/apfs-build/ 2>/dev/null
  cd /tmp/apfs-build
  say "-- 目录 --"; ls >> "$OUT"
  say "-- 试编 --"
  timeout 300 make -C "/lib/modules/$K/build" M=/tmp/apfs-build modules 2>&1 | tail -40 >> "$OUT"
  say "make rc=${PIPESTATUS[0]}"
  ls -l /tmp/apfs-build/*.ko* 2>/dev/null >> "$OUT" || say "no ko produced"
fi
say done
