#!/bin/bash
# 把我们自制的 umi XNU 补丁在「设备仓工作树」与「hackios-umi 仓库」之间双向同步。
# 用法：sync-umi-patches.sh save | restore
set -eu
OURS=(
  zzzzzzzzzzzzzzzzz-umi-screen.patch
  zzzzzzzzzzzzzzzzzz-umi-crypto-kit.patch
  zzzzzzzzzzzzzzzzzzz-umi-amfi-guard.patch
  zzzzzzzzzzzzzzzzzzzz-umi-boot-stage.patch
)
DEV=/home/unixnu/code/UniXNU-umi/patches/umi-xnu
REPO=/mnt/e/Code/HackIos/patches/umi-xnu
case "${1:-save}" in
  save)
    mkdir -p "$REPO"
    for p in "${OURS[@]}"; do
      [ -f "$DEV/$p" ] || { echo "缺 $DEV/$p"; exit 1; }
      cp "$DEV/$p" "$REPO/$p"
    done
    sha256sum "${OURS[@]/#/$REPO/}"
    echo "SAVED"
    ;;
  restore)
    command -v ensure-dev-bind >/dev/null 2>&1 || bash /mnt/e/Code/HackIos/tools-wsl/ensure-dev-bind.sh
    for p in "${OURS[@]}"; do
      [ -f "$REPO/$p" ] || { echo "缺 $REPO/$p"; exit 1; }
      cp "$REPO/$p" "$DEV/$p"
      sed -i 's/\r$//' "$DEV/$p"
    done
    ls -la "$DEV" | tail -6
    echo "RESTORED"
    ;;
  *) echo "用法: $0 save|restore"; exit 2;;
esac
