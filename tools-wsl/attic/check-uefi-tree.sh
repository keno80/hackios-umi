#!/bin/bash
# 检查 uefi-umi 各子模块在 ext4 / Windows 侧的完整度
set -u
E=/mnt/e/Code/HackIos/uefi-umi
M=/home/unixnu/code/Mu_Basecore

echo "== UniXNU-umi source-lock"
python3 - <<'PY'
import json
d = json.load(open("/home/unixnu/code/UniXNU-umi/source-lock.json"))
for k, v in d.items():
    print(f"  {k}: {v if isinstance(v,str) else json.dumps(v)[:120]}")
PY

echo "== ext4 Mu_Basecore ($M)"
if [ -d "$M" ]; then
  echo "  HEAD: $(git -C "$M" rev-parse HEAD 2>/dev/null)"
  echo "  dirty lines: $(git -C "$M" status --porcelain 2>/dev/null | wc -l)"
  git -C "$M" status --porcelain 2>/dev/null | head -5
  echo "  nested submodule paths:"
  git -C "$M" config --file .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print "    "$2}'
  for d in $(git -C "$M" config --file .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}'); do
    printf "    %-50s files=%s\n" "$d" "$(find "$M/$d" -type f 2>/dev/null | wc -l)"
  done
else
  echo "  ABSENT"
fi

echo "== Windows uefi-umi submodule content ($E)"
for d in Common/Mu Common/Mu_OEM_Sample Silicium-ACPI Mu_Basecore Silicon/Silicium/OpensslPkg/Library/OpensslLib/openssl; do
  printf "  %-56s files=%-7s head=%s\n" "$d" "$(find "$E/$d" -type f 2>/dev/null | wc -l)" "$(git -C "$E/$d" rev-parse HEAD 2>/dev/null | cut -c1-8)"
done

echo "== openssl key files"
for f in crypto/x509/x509_lib.c crypto/rsa/rsa_lib.c ssl/d1_lib.c crypto/bn/bn_lib.c; do
  if [ -f "$E/Silicon/Silicium/OpensslPkg/Library/OpensslLib/openssl/$f" ]; then echo "  OK   $f"; else echo "  MISS $f"; fi
done

echo "== Windows Mu_Basecore nested submodules"
for d in $(git -C "$E/Mu_Basecore" config --file .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}'); do
  printf "  %-50s files=%s\n" "$d" "$(find "$E/Mu_Basecore/$d" -type f 2>/dev/null | wc -l)"
done

echo "== umiPkg 里是否有 Binaries/umi 引用（inherited profile 会不会残留）"
grep -rn "Binaries/umi" "$E/Platforms/Xiaomi/umiPkg" | sed 's#^#  #' | head -20
echo "== overlay 侧同样检查"
grep -rn "Binaries/umi" /home/unixnu/code/UniXNU-umi/devices/umi/overlay/Platforms/Xiaomi/umiPkg 2>/dev/null | sed 's#^#  #' | head -20
