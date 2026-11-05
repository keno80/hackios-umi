#!/bin/bash
# U 步之七之八之七：Mac 侧第二轮——用 Linux 解出来的 /private/var 骨架造「有内容」的 Data 种子
# 跑法（从 Windows 经 ssh 驱动，或直接登录 Mac）：
#   bash /Volumes/Share/seed-from-share-mac.sh
# 产物直接落在共享文件夹里，Linux 侧用 tools-wsl/pack-umi-data-seed-mac.sh 取。
# 为什么种子根放的是 var 的**内容**而不是 var 本身：内核把这块卷 mount 在 /private/var 上，
#   所以卷根就是 /private/var。实测 ditto src dst(dst 存在) 是「把 src 的内容拷进 dst」，
#   所以 --from-var 直接指解包出来的 private/var 就对了（u372 实测过 ditto 语义）。
set -u
SHARE=/Volumes/Share
WORK=$SHARE/var-seed-work
SIZE=${SIZE:-64m}
VOLNAME=${VOLNAME:-OwnerData}

echo "== 0. 取件 =="
TAR=$SHARE/var-tree.tar.gz
[ -f "$TAR" ] || { echo "停手：共享文件夹里没有 $TAR"; exit 1; }
echo "  $(ls -l "$TAR")"
echo "  sha256 = $(shasum -a 256 "$TAR" | cut -d' ' -f1)"

echo
echo "== 1. 解包（bsdtar 保 mode 与 symlink）=="
rm -rf "$WORK"
mkdir -p "$WORK"
tar -xzf "$TAR" -C "$WORK" || { echo "停手：解包失败"; exit 1; }
VAR=$WORK/private/var
[ -d "$VAR" ] || { echo "停手：解出来没有 private/var"; exit 1; }
echo "  目录数=$(find "$VAR" -type d | wc -l | tr -d ' ')  文件数=$(find "$VAR" -type f | wc -l | tr -d ' ')  链数=$(find "$VAR" -type l | wc -l | tr -d ' ')"
echo "  在场性核对："
for d in mobile db tmp run Keychains preferences installd folders log protected; do
  [ -d "$VAR/$d" ] && echo "    有  $d" || echo "    无  $d"
done

echo
echo "== 2. 造种子 =="
OUT=$SHARE/seed-out
rm -rf "$OUT"; mkdir -p "$OUT"
bash "$SHARE/make-owner-data-seed-mac.sh" --out "$OUT" --size "$SIZE" --volname "$VOLNAME" --from-var "$VAR"
RC=$?
echo "  make-owner-data-seed-mac rc=$RC"
[ "$RC" = 0 ] || exit "$RC"

echo
echo "== 3. 回读种子里的 var 骨架是否真落上（在分离之前已经落盘，这里从镜像侧再验一次）=="
ls -l "$OUT"
echo
echo "下一步（Linux 侧）："
echo "  tools-wsl/pack-umi-data-seed-mac.sh <共享文件夹里的 owner-data-*.cdr>"
echo "  然后拿新 volume_uuid 重编 Data 档内核，判据 _native_owner_data_status=0 且 stage=4"
echo "seed-from-share-mac OK"
