#!/bin/bash
# Linux 上编 umi 的 SILICIUM_UEFI.fd（走 UniXNU 声明式 builder，CLANGPDB + LLVM18 farm）
set -uo pipefail
WS=/home/unixnu/code/umi-work-pin
FARM=/home/unixnu/code/clang-edk2
NAME=${1:-run-01}
LOG=$WS/out/umi-fw-$NAME
mkdir -p "$LOG"

# 整套 binutils 必须同一 LLVM 版本（混用 LLVM24 clang + LLVM18 llvm-lib 会在归档期炸）
export PATH="$FARM:/usr/local/bin:/usr/bin:/bin"
export CLANG_BIN="$FARM"
export JOBS=4
cd "$WS" || exit 1

echo "== 前置状态"
printf "  clang      : %s (%s)\n" "$(command -v clang)" "$(clang --version | head -1)"
printf "  lld-link   : %s\n" "$(command -v lld-link || echo MISSING)"
printf "  BaseTools  : GenFw=$([ -f $WS/sources/uefi-umi/Mu_Basecore/BaseTools/Source/C/bin/GenFw ] && echo yes || echo 'will-build')"
printf "  edk2 dirty : %s\n" "$(git -C sources/uefi-umi/Mu_Basecore status --porcelain | wc -l)"
printf "  菜单包     : %s 文件\n" "$(find out/umi-menu-package -type f | wc -l)"

echo "== build firmware"
python3 sources/UniXNU/unixnu build firmware \
  -D devices/umi --out out/unixnu \
  --uefi sources/uefi-umi \
  --edk2 sources/uefi-umi/Mu_Basecore \
  --local-module "refer:edk2=$WS/sources/uefi-umi/Mu_Basecore" \
  --local-package out/umi-menu-package \
  --target DEBUG -j 4 > "$LOG/cli.log" 2>&1
rc=$?
echo "  rc=$rc"
tail -25 "$LOG/cli.log" | sed 's/^/  | /'
FL=$(find out/unixnu -name 'firmware.log' -newermt '-45 minutes' 2>/dev/null | head -1)
if [ -n "$FL" ]; then
  echo "== $FL 里的 error（前 20 条）"
  grep -n -m 20 -E "error:|Error |FAILED|not found|No such file" "$FL" | sed 's/^/  /'
  echo "== 末尾 20 行"
  tail -20 "$FL" | sed 's/^/  | /'
fi
FD=sources/uefi-umi/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
if [ -f "$FD" ]; then
  printf "== FD: %s bytes  sha256=%s\n" "$(stat -c %s "$FD")" "$(sha256sum "$FD" | cut -d' ' -f1)"
  ls -l "$FD" | sed 's/^/  /'
else
  echo "== FD 未产出"
fi
echo "edk2 dirty after: $(git -C sources/uefi-umi/Mu_Basecore status --porcelain | wc -l)"
echo DONE
