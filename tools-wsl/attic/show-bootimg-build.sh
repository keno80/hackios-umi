#!/bin/bash
W=/home/unixnu/code/umi-work-pin
D=/home/unixnu/code/uefi-umi-b
echo "===== bootimg.build 全文"
sed -n '60,150p' "$W/sources/UniXNU/scripts/unixnu/bootimg.py" | sed 's#^#  #'
echo "===== UmiRamPayload.c 130-215（initrd 定位逻辑）"
sed -n '130,215p' "$D/Platforms/Xiaomi/umiPkg/Drivers/UmiRamPayloadDxe/UmiRamPayload.c" | sed 's#^#  #'
