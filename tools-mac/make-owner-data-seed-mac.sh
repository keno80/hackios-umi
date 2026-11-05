#!/bin/bash
# U 步之七之八：在 macOS 上造一份「原版 APFS 驱动认的」可写 Data 种子
# 为什么只能在这跑：checkpoint 描述符区只有 Apple 的 newfs_apfs 会写，mkapfs 造出来的容器被原版
# nx_mount 判 ENOENT（64 枚描述符全失败），详见 AGENTS.md「U 步之七」。
#
# 用法（Mac 的 Terminal 里）：
#   bash make-owner-data-seed-mac.sh [--out DIR] [--size 32m] [--volname OwnerData] [--from-var DIR]
#     --out      产出目录，默认 ./owner-data-fixture
#     --size     容器大小，默认 32m（上游 check 件钉的就是 33,554,432 B）
#     --volname  卷名，默认 OwnerData（卷 UUID 由 macOS 分配、脚本回读，不要手填）
#     --from-var 要拷进种子根的初始 var 树（Linux 侧从 OS 卷解出来的目录；不给就只交一个空卷）
# 产出：<out>/owner-data-<NN>.cdr（raw APFS 容器）+ <out>/seed.json（含 VolumeUUID）
# 只做格式化与拷贝，不碰任何真机分区。
set -u
LC_ALL=C

OUT=./owner-data-fixture
SIZE=32m
VOLNAME=OwnerData
FROM=""

while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT=$2; shift 2 ;;
    --size) SIZE=$2; shift 2 ;;
    --volname) VOLNAME=$2; shift 2 ;;
    --from-var) FROM=$2; shift 2 ;;
    *) echo "停手：不认识参数 $1"; exit 1 ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || { echo "停手：这条只能在 macOS 上跑（要 hdiutil/diskutil 的 newfs_apfs）"; exit 1; }
for t in hdiutil diskutil plutil stat shasum df ditto; do
  command -v "$t" >/dev/null 2>&1 || { echo "停手：缺 $t（可能要装 Xcode 命令行工具）"; exit 1; }
done
mkdir -p "$OUT"
IMAGE="$OUT/owner-data-${SIZE%m}.cdr"
[ -e "$IMAGE" ] && { echo "停手：不覆盖已有种子 $IMAGE（换 --out 或先自己挪走）"; exit 1; }

echo "== 1. Apple 自己格式化一个 APFS 容器（这一步 Linux 没有等价物）=="
hdiutil create -size "$SIZE" -layout NONE -fs APFS -volname "$VOLNAME" -type UDTO "$IMAGE" || {
  echo "停手：hdiutil create 失败"; exit 1; }

echo
echo "== 2. 挂载并读回卷 UUID =="
TARGET="$OUT/mount"
mkdir -p "$TARGET"
PL="$OUT/attach.plist"
if ! hdiutil attach -nobrowse -owners off -mountpoint "$TARGET" -plist "$IMAGE" > "$PL"; then
  echo "停手：hdiutil attach 失败"; exit 1;
fi
DEVICE=$(df -P "$TARGET" | awk 'NR==2 {print $1}')
[ -n "$DEVICE" ] || { hdiutil detach -force "$TARGET" 2>/dev/null; echo "停手：找不到挂载点对应的设备"; exit 1; }
IP="$OUT/volume.plist"
diskutil info -plist "$DEVICE" > "$IP" || { hdiutil detach -force "$DEVICE"; echo "停手：diskutil info 失败"; exit 1; }
UUID=$(plutil -extract VolumeUUID raw "$IP") || { hdiutil detach -force "$DEVICE"; echo "停手：读不到 VolumeUUID"; exit 1; }
echo "  device=$DEVICE  挂载点=$TARGET  VolumeUUID=$UUID"

if [ -n "$FROM" ]; then
  echo
  echo "== 3. 拷初始 var 树进种子根（ditto 保 symlink 与权限）=="
  [ -d "$FROM" ] || { hdiutil detach -force "$DEVICE"; echo "停手：--from-var 指的不是目录：$FROM"; exit 1; }
  echo "  源=$(cd "$FROM" && pwd)  源文件数=$(find "$FROM" -type f | wc -l | tr -d ' ')"
  if ! ditto --norsrc --noextattr "$FROM" "$TARGET"; then
    hdiutil detach -force "$DEVICE"; echo "停手：ditto 拷贝失败"; exit 1;
  fi
  # 上游 prepare-owner-data-fixture.py 显式跳过 staged_system_apps，这里拷完再摘掉
  find "$TARGET" -type d -name staged_system_apps -exec rm -rf {} + 2>/dev/null
  echo "  已摘掉 staged_system_apps；种子里现有文件数=$(find "$TARGET" -type f | wc -l | tr -d ' ')"
else
  echo
  echo "== 3. 没给 --from-var：交一份空卷（先把「挂载这一格能不能过」证明掉）=="
fi

echo
echo "== 4. 补运行时目录（对齐上游的那四项）=="
for d in keybags mobile/tmp tmp run; do mkdir -p "$TARGET/$d"; done
chmod 1777 "$TARGET/tmp"

echo
echo "== 5. 卸载（干净卸载才会把 checkpoint/事务区落盘，这步不能跳）=="
sync
hdiutil detach "$DEVICE" || { hdiutil detach -force "$DEVICE"; echo "注意：普通 detach 失败，已强制卸载，种子可能不干净"; }

echo
echo "== 6. 自检：按上游 check 件的两条硬判据 =="
BYTES=$(stat -f %z "$IMAGE")
MAGIC=$(dd if="$IMAGE" bs=1 skip=32 count=4 2>/dev/null)
SHA=$(shasum -a 256 "$IMAGE" | cut -d' ' -f1)
echo "  大小=$BYTES（上游钉 $((32*1024*1024))）  块 0 偏移 0x20 魔数=$MAGIC（要 NXSB）"
[ "$BYTES" = "$((32*1024*1024))" ] || { echo "停手：大小不对，Linux 侧 pack 后 kernel 契约也会不对"; exit 1; }
[ "$MAGIC" = "NXSB" ] || { echo "停手：这不是 raw APFS 容器（可能 -layout 没生效）"; exit 1; }
printf '{\n  "volume_uuid": "%s",\n  "bytes": %s,\n  "sha256": "%s",\n  "seed": "hdiutil -fs APFS formatted; %s",\n  "guest_mutable": true\n}\n' \
  "$UUID" "$BYTES" "$SHA" "$([ -n "$FROM" ] && echo "var tree copied" || echo "empty volume")" > "$OUT/seed.json"
cat "$OUT/seed.json"

echo
echo "== 7. 带回 Linux =="
echo "  把 $IMAGE 与 $OUT/seed.json 拷回本仓（建议放 out/umi/data-seed/mac/），"
echo "  Linux 侧用 packed_ramdisk.pack() 打成 .dbr，再把 seed.json 里的 volume_uuid 钉进身份 .json。"
echo "  注意：XNU_OWNER_DATA_VOLUME_UUID 是编译期进 tree/build/xnu/owner-data-volume.h 的，换 UUID 必须重编 Data 档内核。"
echo "  成功判据（QEMU 取证）：_native_owner_data_status 从 2 变 0、stage=4、readonly=0、device 是真块设备号。"
echo "make-owner-data-seed-mac OK"
