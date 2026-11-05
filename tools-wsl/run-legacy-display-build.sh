#!/bin/bash
# U 步之九之二：跑官方 build_umi_data_display.py --component display（本机首次，靠上一步产的参照件）
#
# 这一步验的是整条显示链的中间闸：官方 display() 会
#   1) 断言参照件 sha 自洽 + original_sha256 == f18b4df8…（build_umi_data_display.py:70-73）
#   2) 把它 symlink 成 tree/build/native-prelink/native-owner-mobile-graphics-candidate.{macho,json}
#   3) 抄一份上游 audit-mobile-graphics-legacy.py、剪掉历史 runtime 判据，跑出原版 ABI 绑定表
#   4) 用 sheng 的 build-native-legacy-display.py（改写 ROOT/探针路径后）真编
#      LegacyDisplayProbe.o + KeyStoreProbe.o + NativeGOPPresenter.late.o + NativeKeyStoreEvents.late.o
#      → tree/build/native-legacy-display/libNativeLegacyDisplay.late.a + build-report.json
# 只有全绿，--legacy-display 那档内核才有东西可链。
#
# 用法：run-legacy-display-build.sh
#   FORCE=1 时先把 tree/build/native-legacy-display 与 native-prelink 里的同名链接改名保留
set -u
source /usr/local/bin/unixnu-env
WS=/home/unixnu/code/umi-work-pin
TREE=$WS/out/umi-xnu/umi/tree
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CLT=$TC/CommandLineTools/usr
XCTC=$TC/XcodeDefault.xctoolchain/usr
export PATH="$CLT/bin:$TC/bin:$PATH"
export LC_ALL=C CLT_PREFIX=$CLT XCTOOLCHAIN_PREFIX=$XCTC
export XNU_TOOLCHAIN_BIN="$CLT/bin $XCTC/bin"
export UNIXNU_SDKROOT=$TREE/.cache/fakeroot UNIXNU_SDK_VERSION=17.0
export UNIXNU_PLATFORM_PATH=$TREE/.cache/fakeroot/Platforms/iPhoneOS.platform
export CROSS_CLANG=$TC/llvm/bin/clang DARWIN_TRIPLE=arm64-apple-ios17.0
export CROSS_EXTRA_FLAGS="-mllvm -disable-atexit-based-global-dtor-lowering"
export CCC_OVERRIDE_OPTIONS='# +-Wno-missing-designated-field-initializers +-Wno-unused-but-set-global +-Wno-unnecessary-virtual-specifier +-Wno-deprecated-enum-enum-conversion'
cd "$WS" || exit 1

REF=$WS/out/umi-xnu/umi/kernel/display-reference.macho
[ -f "$REF" ] || { echo "停手：缺参照件 $REF（先跑 run-display-reference.sh）"; exit 1; }
[ -f "$WS/tools/build_umi_data_display.py" ] || { echo "停手：缺 tools/build_umi_data_display.py"; exit 1; }
for f in kits/umi/legacy-display/LegacyDisplayProbe.cpp kits/umi/legacy-display/KeyStoreProbe.cpp \
         drivers/NativeMobileDisplay/NativeLegacyDisplay.cpp drivers/NativeMobileDisplay/NativeGOPPresenter.cpp; do
  [ -f "$TREE/$f" ] || { echo "停手：TREE 缺 $f"; exit 1; }
done
[ -x /usr/local/bin/llvm-objcopy ] || { echo "停手：缺 llvm-objcopy Mach-O shim（跑 sync-helpers.sh）"; exit 1; }

OUT=$TREE/build/native-legacy-display
if [ -e "$OUT/build-report.json" ] && [ "${FORCE:-0}" != 1 ]; then
  echo "已有的 display 归档报告在位（官方件拒绝重跑覆盖就停）：$OUT/build-report.json"
  python3 -c "import json,pathlib;d=json.loads(pathlib.Path('$OUT/build-report.json').read_text());print('  archive_sha256=',d.get('archive_sha256'));print('  runtime_qualified=',d.get('runtime_qualified'))"
  exit 0
fi
if [ "${FORCE:-0}" = 1 ] && [ -d "$OUT" ]; then
  mv "$OUT" "$OUT.stale-$(date +%Y%m%d-%H%M%S)"
fi
for s in .macho .json; do
  L=$TREE/build/native-prelink/native-owner-mobile-graphics-candidate$s
  if [ -e "$L" ] && [ ! -L "$L" ]; then echo "停手：$L 是实体件不是链接，官方 display() 会 assert 死"; exit 1; fi
done

ts=$(date +%Y%m%d-%H%M%S)
LOG=/home/unixnu/code/UniXNU-main/out/unixnu-logs/legacy-display-build-$ts.log
echo "$LOG" > /home/unixnu/code/UniXNU-main/out/unixnu-logs/legacy-display-build-latest.txt
echo "== 跑官方 --component display，日志 $LOG =="
python3 -u tools/build_umi_data_display.py --component display > "$LOG" 2>&1
rc=$?
echo "   exit=$rc"
tail -30 "$LOG"
echo
if [ $rc -eq 0 ] && [ -f "$OUT/build-report.json" ]; then
  echo "== 归档与判据 =="
  python3 - <<'PY'
import hashlib, json, pathlib
out = pathlib.Path("out/umi-xnu/umi/tree/build/native-legacy-display")
r = json.loads((out / "build-report.json").read_text())
arc = out / "libNativeLegacyDisplay.late.a"
print(f"   归档 {arc.name} {arc.stat().st_size if arc.is_file() else '★缺'} B")
for k in ("archive_sha256", "late_object_sha256", "compiled_object_sha256", "original_candidate_sha256",
          "generated_abi_sha256", "bindings", "virtual_entries", "owned_entries", "inherited_native_entries",
          "original_instructions_modified", "runtime_qualified", "keystore_state_service",
          "auxiliary_sheng_hardware_selected", "reference_candidate"):
    v = r.get(k)
    if isinstance(v, dict):
        print(f"   {k}: {len(v)} 条绑定，前 6 = {list(v.items())[:6]}")
    else:
        print(f"   {k} = {v}")
print(f"   自洽：archive_sha256 == 实读 {'✓' if arc.is_file() and hashlib.sha256(arc.read_bytes()).hexdigest() == r.get('archive_sha256') else '★不符'}")
PY
else
  echo "★这步没过。上面日志尾就是要归因的第一手证据。"
fi
echo
echo "== run-legacy-display-build 结束 =="
