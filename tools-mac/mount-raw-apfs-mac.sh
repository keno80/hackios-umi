#!/bin/bash
# Mac 侧直挂 Linux 拷来的裸 APFS 容器（偏移 0 就是 NXSB、没有 UDIF trailer 的那种）
# 为什么用得上：libfsapfs 对 method 9(lzfse) 报 unsupported compression method，Linux 侧解不动的窗
# 在这里由 macOS 原生 APFS 驱动解。关键就是 -imagekey diskimage-class=CRawDiskImage——
# 少了它 hdiutil 报「无法识别映像」（它默认只吃带 UDIF trailer 的镜像），不需要 sudo，也不需要 dd 包装。
#
# 用法：
#   bash mount-raw-apfs-mac.sh attach <裸容器文件>      # 只读挂载，打印挂载点
#   bash mount-raw-apfs-mac.sh detach <裸容器文件>      # 按名字摘掉本次挂上的 disk image
#   bash mount-raw-apfs-mac.sh list                     # 现在挂着哪些
#
# 全程 -readonly，不写镜像一个字节。
set -u
LC_ALL=C

ACTION=${1:-attach}
IMG=${2:-}
PREF=

case "$ACTION" in
  list)
    hdiutil info | grep -E "^/dev/disk|imagepath" || true
    exit 0 ;;
  attach|detach) [ -n "$IMG" ] || { echo "用法：mount-raw-apfs-mac.sh $ACTION <裸容器文件>"; exit 1; } ;;
  *) echo "停手：不认识动作 $ACTION（attach|detach|list）"; exit 1 ;;
esac

[ "$(uname -s)" = "Darwin" ] || { echo "停手：这条只能在 macOS 上跑"; exit 1; }

if [ "$ACTION" = detach ]; then
  # 只摘由这个文件挂出来的盘，别误伤真盘：hdiutil info 按空行分块，取含该镜像路径的那块里的 /dev/disk
  KEYS=$(hdiutil info | awk -v RS='' -v img="$IMG" 'index($0,img){n=split($0,L,"\n"); for(i=1;i<=n;i++) if (L[i] ~ /^\/dev\/disk/) {split(L[i],F," "); print F[1]}}' | sort -u)
  [ -n "$KEYS" ] || { echo "停手：没找到由 $IMG 挂出来的盘（先用 list 看现场）"; exit 1; }
  for D in $KEYS; do
    # 摘最外层那块盘就够了，synthesized 的容器/卷盘会跟着消失
    [ -e "$D" ] || continue
    echo "  摘 $D"
    hdiutil detach -force "$D" 2>&1 | tail -1
  done
  echo "mount-raw-apfs-mac detach OK"
  exit 0
fi

[ -f "$IMG" ] || { echo "停手：找不到镜像 $IMG"; exit 1; }
MAGIC=$(dd if="$IMG" bs=1 skip=32 count=4 2>/dev/null)
[ "$MAGIC" = "NXSB" ] || { echo "停手：$IMG 偏移 0 的 0x20 不是 NXSB（大小=$(stat -f %z "$IMG")），这不是裸 APFS 容器"; exit 1; }
echo "  镜像=$IMG  大小=$(stat -f %z "$IMG")  块 0+0x20=$MAGIC"

OUT=$(hdiutil attach -readonly -noverify -imagekey diskimage-class=CRawDiskImage "$IMG" 2>&1)
RC=$?
echo "$OUT"
[ $RC -eq 0 ] || { echo "停手：挂载失败（rc=$RC）"; exit 1; }
echo
echo "== 挂出来的卷 =="
echo "$OUT" | awk '/^\/dev\/disk[0-9]+s/ {print "  " $0}'
echo
echo "== 卷根目录 =="
echo "$OUT" | sed -n 's#.*[[:space:]]\(/Volumes/.*\)$#\1#p' | sort -u | while IFS= read -r V; do
  [ -d "$V" ] || continue
  echo "  挂载点=$V"
  ls "$V" | head -20 | sed 's/^/    /'
done
echo
echo "只读挂载中。完事跑：bash mount-raw-apfs-mac.sh detach \"$IMG\""
echo "mount-raw-apfs-mac attach OK"
