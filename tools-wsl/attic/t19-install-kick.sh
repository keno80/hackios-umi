#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/t19-install-kick.txt
: > "$OUT"; exec >>"$OUT" 2>&1
SRC=/mnt/e/Code/HackIos
ROOT=/home/unixnu/code/UniXNU-umi
NEW=zzzzzzzzzzzzzzzzzzzzzzzzzzzzzz-umi-cs-amfi.patch

echo "== 1. 装补丁（全量 zz*.patch 覆盖） =="
bash /mnt/e/Code/HackIos/tools-wsl/h-install-band.sh
echo "install-rc=$?"
ls -la "$ROOT/patches/umi-xnu/" | tail -4
cmp -s "$SRC/patches/umi-xnu/$NEW" "$ROOT/patches/umi-xnu/$NEW" && echo "NEW-INSTALLED" || echo "NEW-MISSING"
echo "CR 字节数=$(tr -dc '\r' < "$ROOT/patches/umi-xnu/$NEW" | wc -c)"

echo
echo "== 2. 起内核构建 =="
bash "$SRC/tools-wsl/run-kernel-walk.sh"
echo
echo "== 3. 记录基线 sha（用于判新鲜度） =="
sha256sum /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
echo "marker=$(ls -la /tmp/walk-start-marker 2>&1)"
echo "done $(date -u +%FT%TZ)"
