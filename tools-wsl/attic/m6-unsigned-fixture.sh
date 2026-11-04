set -u
exec >>/mnt/e/Code/HackIos/out/probes/m6-unsigned-fixture.txt 2>&1
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CLT=$TC/CommandLineTools/usr
XCTC=$TC/XcodeDefault.xctoolchain/usr
export PATH="$CLT/bin:$TC/bin:$PATH"
export XNU_TOOLCHAIN_BIN="$CLT/bin $XCTC/bin"
FAKEROOT=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/fakeroot
export UNIXNU_SDKROOT=$FAKEROOT UNIXNU_SDK_VERSION=17.0
export UNIXNU_PLATFORM_PATH=$FAKEROOT/Platforms/iPhoneOS.platform
S=/home/unixnu/code/UniXNU-main
O=/tmp/fx-unsigned
rm -rf $O && mkdir -p $O
echo "== 0. SDKROOT =="
echo "UNIXNU_SDKROOT=$UNIXNU_SDKROOT"
ls -d "$UNIXNU_SDKROOT" 2>/dev/null || echo "(sdkroot 不存在，纯汇编不需要头文件)"
echo
echo "== 1. clang 编 .S =="
"$CLT/bin/clang" -target arm64-apple-ios17.0 -isysroot "$UNIXNU_SDKROOT" \
  -c $S/scripts/qemu-entry/native-user.S -o $O/user.o
echo "clang rc=$?"
ls -la $O/user.o
sha256sum $O/user.o
echo "上游 user.o sha = 0f636931e5613bb5d1ce3a35fa0d5bd3fdcc42e9581e47e84301c7c634c16fad"
echo
echo "== 2. ld64 静态链接 =="
"$CLT/bin/ld" -arch arm64 -static -e _start -platform_version ios 17.0 17.0 \
  $O/user.o -o $O/launchd-static.macho
echo "ld rc=$?"
ls -la $O/launchd-static.macho 2>/dev/null
echo
echo "== 3. vtool 打 build version =="
"$CLT/bin/vtool" -set-build-version ios 17.0 17.0 -replace \
  -output $O/launchd.macho $O/launchd-static.macho
echo "vtool rc=$?"
ls -la $O/launchd.macho 2>/dev/null
sha256sum $O/launchd.macho 2>/dev/null
echo
echo "== 4. load command 摘要（看有没有 LC_CODE_SIGNATURE）=="
"$CLT/bin/otool" -l $O/launchd.macho 2>/dev/null | grep -E "cmd |cmdsize|segname|vmaddr|vmsize" | head -40
echo "-- 上游件的对照"
"$CLT/bin/otool" -l $S/build/native-user-fixture-umi/launchd.macho 2>/dev/null | grep -E "cmd |cmdsize" | head -40
echo
echo "== 5. 尺寸差（上游有签名块）=="
stat -c '%n %s' $O/launchd.macho $S/build/native-user-fixture-umi/launchd.macho 2>/dev/null
echo "== done =="
