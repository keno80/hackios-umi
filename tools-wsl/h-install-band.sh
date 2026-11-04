#!/bin/bash
# H 步：把仓库归档的画屏进度带（UMI_BAND）装进构建真正消费的 UniXNU-umi 树源
# 构建读的是 ext4 那份克隆，Windows 侧改动不会自动生效——装错地方就是白跑一场。
set -u
SRC=/mnt/e/Code/HackIos
ROOT=/home/unixnu/code/UniXNU-umi
LOG=/mnt/e/Code/HackIos/out/probes/h-install-band.txt
: > "$LOG"
exec >>"$LOG" 2>&1

echo "== 1. 归档指纹 =="
sha256sum "$SRC/patches/umi-xnu/early-entry-trace.patch" \
          "$SRC/patches/umi-scripts/umi-early-trace.inc"

echo "== 2. 安装前目标树 =="
for f in patches/umi-xnu/early-entry-trace.patch scripts/umi-early-trace.inc; do
  printf '%s: band=%s\n' "$f" "$(grep -c UMI_BAND "$ROOT/$f" || true)"
done

cp -f "$SRC/patches/umi-xnu/early-entry-trace.patch" "$ROOT/patches/umi-xnu/early-entry-trace.patch"
cp -f "$SRC/patches/umi-scripts/umi-early-trace.inc" "$ROOT/scripts/umi-early-trace.inc"

echo "== 3. 安装后自检 =="
fail=0
for f in patches/umi-xnu/early-entry-trace.patch scripts/umi-early-trace.inc; do
  b=$(grep -c UMI_BAND "$ROOT/$f")
  cr=$(tr -dc '\r' <"$ROOT/$f" | wc -c)
  printf '%s: UMI_BAND=%s CR=%s\n' "$f" "$b" "$cr"
  [ "$b" -ge 1 ] || fail=1
  [ "$cr" -eq 0 ] || fail=1
done
[ "$fail" -eq 0 ] && echo "INSTALL OK" || echo "INSTALL FAIL"

echo "== 4. 归档与目标逐字节一致 =="
diff -q "$SRC/patches/umi-xnu/early-entry-trace.patch" "$ROOT/patches/umi-xnu/early-entry-trace.patch" && echo "patch same"
diff -q "$SRC/patches/umi-scripts/umi-early-trace.inc" "$ROOT/scripts/umi-early-trace.inc" && echo "inc same"
echo "== done $(date -u +%FT%TZ)"
exit "$fail"
