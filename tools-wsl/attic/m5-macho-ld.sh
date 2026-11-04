set -u
exec >>/mnt/e/Code/HackIos/out/probes/m5-macho-ld.txt 2>&1
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CLT=$TC/CommandLineTools/usr
XCTC=$TC/XcodeDefault.xctoolchain/usr
export XNU_TOOLCHAIN_BIN="$CLT/bin $XCTC/bin"
export UNIXNU_SDKROOT=$CLT/.build/aarch64-apple-ios17.0
echo "== 1. xcrun shim 尾段（怎么 exec）=="
sed -n '60,140p' /usr/bin/xcrun
echo
echo "== 2. codesign shim 头 40 行 =="
sed -n '1,40p' /usr/bin/codesign
echo
echo "== 3. 工具链里的 Mach-O 件 =="
for d in "$CLT/bin" "$XCTC/bin" "$TC/bin"; do
  echo "-- $d"
  ls -1 "$d" 2>/dev/null | head -40
done
echo
echo "== 4. -find 解析 =="
for t in clang ld vtool lipo codesign nm; do
  printf '%-9s -> %s\n' "$t" "$(xcrun -sdk iphoneos -find $t 2>&1)"
done
echo
echo "== 5. ld 的真身 =="
L=$(xcrun -sdk iphoneos -find ld 2>/dev/null)
echo "ld=$L"
[ -n "$L" ] && file "$L" && "$L" -v 2>&1 | head -3
echo "== done =="
