#!/bin/bash
D=/home/unixnu/code/uefi-umi-b
W=/home/unixnu/code/umi-work-pin
echo "== 1. UmiRamPayloadDxe 从哪读 FAT"
F=$(find "$D/Platforms/Xiaomi/umiPkg/Drivers/UmiRamPayloadDxe" -name '*.c' | head -1)
echo "  $F"
grep -n -E "Hob|Guid|ramdisk|Ramdisk|RAMDisk|DevicePath|Fat|Volume|signature|magic|0x" "$F" | head -30 | sed 's#^#  #'
echo "== 2. 驱动全文头 60 行"
sed -n '1,60p' "$F" | sed 's#^#  #'
echo "== 3. bootimg 对 --ramdisk 的处理"
grep -n -E "ramdisk|second|page_size|ramdisk_load" "$W/sources/UniXNU/scripts/unixnu/bootimg.py" | head -25 | sed 's#^#  #'
echo "== 4. 谁把 boot.img ramdisk 交给固件（ShimLoader/Sec）"
grep -rn -E "ramdisk|Ramdisk|RAMDisk" "$D/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/ShimLoader.c" "$D/Silicon/Silicium/SiliciumPkg/Sec/Sec.c" 2>/dev/null | head -15 | sed 's#^#  #'
