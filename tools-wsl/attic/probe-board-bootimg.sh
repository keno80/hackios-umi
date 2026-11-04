#!/bin/bash
W=/home/unixnu/code/umi-work-pin
D=/home/unixnu/code/uefi-umi-b
echo "== 1. board.toml 的 firmware / bootimg 段"
sed -n '/\[firmware\]/,/^$/p' "$W/devices/umi/board.toml" | sed 's#^#  #'
awk '/^\[bootimg/,/^\[[^b]/' "$W/devices/umi/board.toml" | head -40 | sed 's#^#  #'
echo "== 2. 该设备真正用的 config toml"
CFGNAME=$(grep -A5 "\[firmware\]" "$W/devices/umi/board.toml" | grep -o -E 'config *= *"[^"]+"' | cut -d'"' -f2)
echo "  config=$CFGNAME -> $D/Resources/Configs/$CFGNAME.toml"
grep -n -A12 -E "\[boot_image\]|\[uefi_fd\]|\[boot_shim\]" "$D/Resources/Configs/$CFGNAME.toml" 2>/dev/null | sed 's#^#  #'
echo "== 3. patch_dtb 实现"
grep -n -A30 "^def patch_dtb" "$W/sources/UniXNU/scripts/unixnu/bootimg.py" | sed 's#^#  #'
echo "== 4. 采集树里的 initrd 与 ramdisk 线索"
python3 - <<'PY'
import sys
sys.path.insert(0, "/mnt/e/Code/HackIos/tools-wsl")
try:
    import dtc_lib as L
except Exception as e:
    print("  (无 dtc_lib:", e, ")")
    sys.exit()
PY
python3 - <<'PY'
from pathlib import Path
try:
    import libfdt
except ImportError:
    print("  无 libfdt，改用 grep 方式")
else:
    pass
PY
strings -a /mnt/e/Code/HackIos/out/phone3/running.dtb | grep -E "initrd|androidboot|dtbo" | head -10 | sed 's#^#  #'
