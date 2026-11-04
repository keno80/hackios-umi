set -u
exec >>/mnt/e/Code/HackIos/out/probes/m8-build-walk.txt 2>&1
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CLT=$TC/CommandLineTools/usr
XCTC=$TC/XcodeDefault.xctoolchain/usr
export PATH="$CLT/bin:$TC/bin:$PATH"
export XNU_TOOLCHAIN_BIN="$CLT/bin $XCTC/bin"
FAKEROOT=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/fakeroot
export UNIXNU_SDKROOT=$FAKEROOT UNIXNU_SDK_VERSION=17.0
export UNIXNU_PLATFORM_PATH=$FAKEROOT/Platforms/iPhoneOS.platform
SRC=/mnt/e/Code/HackIos/tools-wsl/umi-fixture/walk-user.S
OUTD=/mnt/e/Code/HackIos/out/fixtures
mkdir -p $OUTD
W=/tmp/fx-walk
rm -rf $W && mkdir -p $W

echo "== 1. clang 编 walk-user.S =="
"$CLT/bin/clang" -target arm64-apple-ios17.0 -isysroot "$UNIXNU_SDKROOT" \
  -c "$SRC" -o $W/walk.o
echo "clang rc=$?"
ls -la $W/walk.o

echo "== 2. ld64 静态链接 =="
"$CLT/bin/ld" -arch arm64 -static -e _start -platform_version ios 17.0 17.0 \
  $W/walk.o -o $W/launchd-walk.macho
echo "ld rc=$?"

echo "== 3. vtool 打 build version =="
"$CLT/bin/vtool" -set-build-version ios 17.0 17.0 -replace \
  -output $OUTD/launchd-walk.macho $W/launchd-walk.macho
echo "vtool rc=$?"
ls -la $OUTD/launchd-walk.macho
sha256sum $OUTD/launchd-walk.macho

echo "== 4. 符号地址（上游判据必须不动）=="
"$CLT/bin/nm" -n $OUTD/launchd-walk.macho 2>/dev/null | grep -E "_results|_user_page_size|_old_length|_walk|_nz|_checkpoint|_start"
echo "-- 期望 _results=0x100004000 _user_page_size=0x100004028 _old_length=0x100004030"

echo "== 5. 与上游件的判据偏移对照 =="
"$CLT/bin/nm" -n /home/unixnu/code/UniXNU-main/build/native-user-fixture-umi/launchd.macho | grep -E "_results|_user_page_size|_old_length|_checkpoint"

echo "== 6. load command 摘要 =="
"$CLT/bin/otool" -l $OUTD/launchd-walk.macho | grep -E "^ *cmd |^ *cmdsize" | head -24
echo "== done =="
