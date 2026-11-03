#!/bin/bash
W=/home/unixnu/code/umi-work-pin
D=/home/unixnu/code/uefi-umi-b
echo "== 1. 设备 bootimg 配置（base/offset/dtb_node）"
sed -n '1,80p' "$W/devices/umi/board.toml" 2>/dev/null | grep -n -A25 -E "bootimg|dtb_node" | sed 's#^#  #'
echo "-- 若无 board.toml，找设备主配置"
ls -1 "$W/devices/umi/" | sed 's#^#  #'
echo "== 2. Resources/Configs/umi.toml 的 boot_image / boot_shim / uefi_fd"
CFG=$(grep -l -E "uefi_fd" "$D/Resources/Configs/"*.toml 2>/dev/null | head -1)
echo "  $CFG"; sed -n '1,80p' "$CFG" | sed 's#^#  #'
echo "== 3. 谁引用 0xA0000000 窗口"
grep -rn -E "0xA0000000|0xa0000000" "$D/Silicon" "$D/Platforms/Xiaomi" "$W/devices/umi" 2>/dev/null | cut -c1-160 | head -20 | sed 's#^#  #'
echo "== 4. prepare 给 Sec.c / ShimLoader.c 打的补丁"
git -C "$D" diff -- Silicon/Silicium/SiliciumPkg/Sec/Sec.c | head -40 | sed 's#^#  #'
git -C "$D" diff -- Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/ShimLoader.c | head -40 | sed 's#^#  #'
