#!/bin/bash
set -u
D=/home/unixnu/code/uefi-umi-b
M=/home/unixnu/code/Mu_Basecore
echo "== edk2 里的检查代码（搞清 case mismatch 判据）"
grep -rn "case mismatch" "$M/BaseTools/Source/Python" | head -5
F=$(grep -rl "case mismatch" "$M/BaseTools/Source/Python" | head -1)
echo "-- $F 上下文"
grep -n -B 18 "case mismatch" "$F" | tail -30 | sed 's/^/  /'
echo "== 同名可达路径"
ls -d "$D"/Common/Mu/MdePkg "$D"/MdePkg 2>/dev/null | sed 's/^/  /'
echo "  Mu 里有 .dec 的包: $(ls "$D/Common/Mu" | tr '\n' ' ')"
echo "== 谁引用 MdeLibs.dsc.inc"
grep -rn "MdeLibs.dsc.inc" "$D/Silicon/Silicium/SiliciumPkg/SecureBoot-Keys.inc" 2>/dev/null | sed 's/^/  /'
sed -n '118,128p' "$D/Silicon/Silicium/SiliciumPkg/SecureBoot-Keys.inc" | sed 's/^/  | /'
echo "== 当前 Mu_Basecore 链接状态"
ls -ld "$D/Mu_Basecore"
readlink -f "$D/Mu_Basecore/MdePkg/MdeLibs.dsc.inc"
echo DONE
