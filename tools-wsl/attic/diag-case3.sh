#!/bin/bash
set -u
D=/home/unixnu/code/uefi-umi-b
M=/home/unixnu/code/Mu_Basecore
echo "== SecureBoot-Keys.inc 全文行数与内容"
wc -l "$D/Silicon/Silicium/SiliciumPkg/SecureBoot-Keys.inc"
cat -A "$D/Silicon/Silicium/SiliciumPkg/SecureBoot-Keys.inc" | sed 's/\$$//' | head -40 | sed 's/^/  | /'
echo "== edk2 Misc.py 的核对函数"
sed -n '1560,1600p' "$M/BaseTools/Source/Python/Common/Misc.py" | sed 's/^/  /'
echo DONE
