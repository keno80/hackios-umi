#!/bin/bash
# U 步：用作者的 build_umi_native_ufs.py 造官方只读 UFS 块件（NativeUfsBlock）+ 绑定表
# 前置：out/umi/storage-abi/interface-audit.json（由 run-storage-abi-snapshot.sh 出）
# 用法：run-native-ufs [qemu|phone]
set -u
PROFILE=${1:-qemu}
PIN=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
T=$PIN/out/umi-xnu/umi/tree
OUT=$T/build/native-ufs

source /usr/local/bin/unixnu-env 2>/dev/null
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C CLT_PREFIX=$TC/CommandLineTools/usr XCTOOLCHAIN_PREFIX=$TC/XcodeDefault.xctoolchain/usr
export XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"
export UNIXNU_SDKROOT=$T/.cache/fakeroot UNIXNU_SDK_VERSION=17.0
export UNIXNU_PLATFORM_PATH=$T/.cache/fakeroot/Platforms/iPhoneOS.platform
export CCC_OVERRIDE_OPTIONS='# +-Wno-missing-designated-field-initializers +-Wno-unused-but-set-global +-Wno-unnecessary-virtual-specifier +-Wno-deprecated-enum-enum-conversion'

cd "$PIN" || exit 1
echo "== 前置件 =="
for f in out/umi/storage-abi/interface-audit.json out/umi/storage-abi/include; do
  printf '  %-48s %s\n' "$f" "$([ -e "$f" ] && echo 有 || echo 缺)"; done

# 绑定脚本的守卫要求「被审计的那件内核」正躺在 out/umi-xnu/umi/kernel/qemu-storage-apfs.macho，
# 且 sha 等于 audit 里的 candidate_sha256。作者的工具只用这个上游名字，本仓 prelink 档叫
# apfs-prelink-kernel.macho，所以这里按 audit 记录做一次身份核对后再落名；对不上就停手，
# 免得用一份过期的 audit 去绑内核地址。
AUD=$PIN/out/umi/storage-abi/interface-audit.json
SRC_K=$PIN/out/umi-xnu/umi/kernel/apfs-prelink-kernel.macho
PIN_K=$PIN/out/umi-xnu/umi/kernel/qemu-storage-apfs.macho
WANT=$(python3 -c "import json;print(json.loads(open('$AUD').read())['candidate_sha256'])" 2>/dev/null)
HAVE=$(sha256sum "$SRC_K" 2>/dev/null | cut -d' ' -f1)
echo
echo "== 绑定守卫的前置：把被审内核落名 qemu-storage-apfs.macho =="
printf '  audit candidate_sha256   %s\n  apfs-prelink-kernel      %s\n' "${WANT:0:16}" "${HAVE:0:16}"
if [ -z "$WANT" ] || [ "$WANT" != "$HAVE" ]; then
  echo "  判死：prelink 件与 audit 记录不一致（audit 过期或内核换档）。先重跑 run-storage-abi-snapshot.sh，别硬绑。"
  exit 1
fi
if [ -f "$PIN_K" ] && [ "$(sha256sum "$PIN_K" | cut -d' ' -f1)" = "$WANT" ]; then
  echo "  qemu-storage-apfs.macho 已是同一件，不动"
else
  cp -f "$SRC_K" "$PIN_K"
  echo "  已拷入 qemu-storage-apfs.macho  sha=$(sha256sum "$PIN_K" | cut -c1-16)…"
fi
echo
echo "== build_umi_native_ufs.py --profile $PROFILE =="
time python3 -u tools/build_umi_native_ufs.py --profile "$PROFILE" 2>&1 | tail -40
echo "退出码=${PIPESTATUS[0]}"
echo
echo "== 产物 =="
ls -la $OUT 2>&1 | head -20
[ -f $OUT/build-report.json ] && head -40 $OUT/build-report.json
