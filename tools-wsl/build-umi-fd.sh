#!/bin/bash
# 手工复刻 UniXNU firmware.py 的构建（Linux 大小写敏感 + tree/package 是符号链接，
# edk2 会把 symlink 的 Root 与 realpath 比成 FILE_CASE_MISMATCH，所以直接用真实路径）
set -uo pipefail
WS=/home/unixnu/code/umi-work-pin
UEFI=/home/unixnu/code/uefi-umi-b
EDK2=/home/unixnu/code/Mu_Basecore
PKG=$WS/out/umi-menu-package
NAME=${1:-run-02}
FARM=/home/unixnu/code/clang-edk2
LOGD=$WS/out/umi-fw/$NAME
mkdir -p "$LOGD"
JOBSN=${JOBSN:-4}

export WORKSPACE=$UEFI
export EDK_TOOLS_PATH=$EDK2/BaseTools
export CONF_PATH=$WS/out/unixnu/umi/edk2-conf
export PACKAGES_PATH=$UEFI:$UEFI/Platforms/Xiaomi:$PKG:$EDK2:$UEFI/Common/Mu:$UEFI/Common/Mu_OEM_Sample:$UEFI/Silicon/Qualcomm:$UEFI/Silicon/Silicium
export PYTHON_COMMAND=python3
export PATH=$EDK2/BaseTools/BinWrappers/PosixLike:$EDK2/BaseTools/Source/C/bin:$FARM:/usr/local/bin:/usr/bin:/bin
export CLANG_BIN=$FARM
export SOURCE_DATE_EPOCH=$(git -C "$UEFI" log -1 --format=%ct)
mkdir -p "$CONF_PATH"
for n in target tools_def build_rule; do
  [ -f "$CONF_PATH/$n.txt" ] || cp "$EDK2/BaseTools/Conf/$n.template" "$CONF_PATH/$n.txt"
done

P='Gic-Spurious Mac-Bash3 Dxe-Trace Display-Services-Trace'
LINKBAK=$WS/Mu_Basecore.link-out
reverse() {
  for p in Display-Services-Trace Dxe-Trace Mac-Bash3 Gic-Spurious; do
    git -C "$EDK2" apply --reverse "$UEFI/Resources/MuPatches/$p.patch" 2>/dev/null || true
  done
  echo "== 回滚后 edk2 dirty=$(git -C "$EDK2" status --porcelain | wc -l)"
  # 把 WORKSPACE 顶层的 edk2 符号链接放回原位
  [ -e "$LINKBAK" ] && mv "$LINKBAK" "$UEFI/Mu_Basecore" && echo "== 已恢复 $UEFI/Mu_Basecore 链接"
  echo DONE_ROLLBACK
}
trap reverse EXIT

# edk2 DirCache 以 WORKSPACE 为根：顶层若存在名为 Mu_Basecore 的链接，
# 同一个 MdePkg 文件会被缓存成 uefi-umi-b/Mu_Basecore/... 第二条路径，
# 与真实 root 按长度切片后必报 error 0010 File name case mismatch。
LINKBAK=$WS/Mu_Basecore.link-out
if [ -L "$UEFI/Mu_Basecore" ]; then
  rm -f "$LINKBAK"
  mv "$UEFI/Mu_Basecore" "$LINKBAK"
  echo "== 临时移出 $UEFI/Mu_Basecore -> $LINKBAK"
fi

# 逐个 check+apply：Display-Services-Trace 依赖 Dxe-Trace 先落地，统一预检查会误报
for p in $P; do
  f=$UEFI/Resources/MuPatches/$p.patch
  git -C "$EDK2" apply --check "$f" || { echo "PRE-CHECK FAIL $p"; exit 1; }
  git -C "$EDK2" apply "$f" || { echo "APPLY FAIL $p"; exit 1; }
  echo "== applied $p"
done
echo "== 补丁已应用，dirty=$(git -C "$EDK2" status --porcelain | wc -l)"
: > "$LOGD/firmware.log"
tail -f "$LOGD/firmware.log" &
TP=$!

cd "$UEFI" || exit 1
build -p Platforms/Xiaomi/umiPkg/umi.dsc -a AARCH64 -b DEBUG -t CLANGPDB -n "$JOBSN" \
  -D FD_BASE=0x9fc00000 -D FD_SIZE=0x300000 -D FD_BLOCKS=768 \
  -D ENABLE_SECUREBOOT=0 -D DEVICE_MODEL=0 -D MEMORY_PROTECTION=TRUE -D SHIP_MODE=FALSE \
  -D BUILDID_STRING=umi-menu-research >> "$LOGD/firmware.log" 2>&1
rc=$?
kill $TP 2>/dev/null
echo "== build rc=$rc"
echo "== 错误摘录"
awk 'length($0)<400' "$LOGD/firmware.log" | grep -n -m 25 -E "error:|ERROR|Error [0-9]|FAILED|not found|No such file|case mismatch" | sed 's/^/  /'
echo "== 末尾"
awk 'length($0)<400' "$LOGD/firmware.log" | tail -12 | sed 's/^/  | /'
FD=$UEFI/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
if [ -f "$FD" ]; then
  printf "== FD %s bytes (期望 3145728) sha256=%s\n" "$(stat -c %s "$FD")" "$(sha256sum "$FD" | cut -d' ' -f1)"
else
  echo "== FD 未产出"
fi
echo DONE
