#!/bin/bash
# 在 ext4 里组装 uefi-umi 构建树（NTFS 副本不可用：嵌套 submodule 空、CRLF）
set -uo pipefail
SRC=/mnt/e/Code/HackIos/uefi-umi
DST=/home/unixnu/code/uefi-umi-b
MB=/home/unixnu/code/Mu_Basecore
WS=/home/unixnu/code/umi-work-pin
PIN=$(python3 -c 'import json;print(json.load(open("/home/unixnu/code/UniXNU-umi/source-lock.json"))["uefi-umi"])')
echo "pin uefi-umi = $PIN"
echo "E: HEAD      = $(git -C "$SRC" rev-parse HEAD)"
echo "E: 子模块 eol = $(git -C "$SRC" ls-files --eol Resources/MuPatches | head -4)"

if [ ! -d "$DST/.git" ]; then
  echo "== clone"
  git clone -q "file://$SRC" "$DST" || { echo "clone 失败"; exit 1; }
fi
git -C "$DST" cat-file -e "${PIN}^{commit}" 2>/dev/null || git -C "$DST" fetch -q --depth 1 "file://$SRC" "$PIN"
git -C "$DST" checkout -q -f "$PIN" || { echo "checkout pin 失败"; exit 1; }
echo "DST HEAD = $(git -C "$DST" rev-parse HEAD)"
echo "DST eol  = $(git -C "$DST" ls-files --eol Resources/MuPatches | head -4)"

echo "== 填子模块内容（Mu / Mu_OEM_Sample / Silicium-ACPI / openssl）"
for d in Common/Mu Common/Mu_OEM_Sample Silicium-ACPI Silicon/Silicium/OpensslPkg/Library/OpensslLib/openssl; do
  mkdir -p "$DST/$d"
  rsync -a --delete --exclude '.git' "$SRC/$d/" "$DST/$d/" || echo "  rsync 失败: $d"
  printf "  %-58s files=%s\n" "$d" "$(find "$DST/$d" -type f | wc -l)"
done

echo "== Mu_Basecore 用已完整的 ext4 克隆（嵌套 libfdt/brotli/oniguruma/mipisyst 有内容）"
if [ -d "$DST/Mu_Basecore" ] && [ ! -L "$DST/Mu_Basecore" ]; then
  rmdir "$DST/Mu_Basecore" 2>/dev/null || { echo "  Mu_Basecore 是含文件的实目录，停手"; ls -A "$DST/Mu_Basecore" | head; exit 1; }
fi
[ -L "$DST/Mu_Basecore" ] && rm "$DST/Mu_Basecore"
ln -s "$MB" "$DST/Mu_Basecore"
echo "  link: $(readlink "$DST/Mu_Basecore") head=$(git -C "$DST/Mu_Basecore" rev-parse HEAD) dirty=$(git -C "$DST/Mu_Basecore" status --porcelain | wc -l)"

echo "== 工作区 sources/uefi-umi 改指 ext4 树"
echo "  旧: $(readlink "$WS/sources/uefi-umi")"
ln -sfn "$DST" "$WS/sources/uefi-umi"
echo "  新: $(readlink "$WS/sources/uefi-umi")"

echo "== overlay 与依赖检查"
ls -d /home/unixnu/code/UniXNU-umi/overlay/Platforms/Xiaomi/umiPkg >/dev/null 2>&1 && echo "  overlay/Platforms/Xiaomi/umiPkg OK" || echo "  overlay 路径缺失"
printf "  overlay 文件数=%s\n" "$(find /home/unixnu/code/UniXNU-umi/overlay -type f 2>/dev/null | wc -l)"
grep -rl "Binaries/umi" /home/unixnu/code/UniXNU-umi/overlay/Platforms/Xiaomi/umiPkg/Include 2>/dev/null | sed 's#^#  #'
for t in rsync fdtoverlay dtc mformat llvm-objcopy aarch64-linux-gnu-gcc; do
  printf "  %-22s %s\n" "$t" "$(command -v $t || echo MISSING)"
done
echo "== 菜单包基线（UniXNU/package）"
printf "  package 文件数=%s\n" "$(find /home/unixnu/code/UniXNU-pin/package -type f | wc -l)"
echo DONE
