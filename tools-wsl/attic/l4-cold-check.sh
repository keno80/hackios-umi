set -u
exec >>/mnt/e/Code/HackIos/out/probes/l4-cold-check.txt 2>&1
echo "== 1. 拆包自检原文 =="
tail -15 /home/unixnu/code/umi-work-pin/out/umi/boot/pack-check.txt
echo
echo "== 2. 判定行 =="
grep -n "^RESULT" /home/unixnu/code/umi-work-pin/out/umi/boot/pack-check.txt
echo
echo "== 3. 卷内菜单标题（stage2 的 toml）=="
grep -n "title\|args\|path\|initrd" /home/unixnu/code/umi-work-pin/out/umi/xnu/stage2/EFI/UniXNU/unixnu.toml
echo
echo "== 4. 交付镜像指纹与标题命中 =="
IMG=/mnt/e/Code/HackIos/out/images/umi-uefi-menu-cold.img
ls -l "$IMG" | sed 's#^# #'
sha256sum "$IMG" | sed 's#^# #'
for s in 'L-COLD Mi 10 8G' 'rd=md0' 'UMI XNU' 'INIT exec ok' 'EL0 UNIX'; do
  printf '%-20s hit=%s\n' "$s" "$(strings -a -n 8 "$IMG" | grep -c -F "$s")"
done
echo
echo "== 5. 内核 sha 是否就是合并档 =="
sha256sum /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/entry-trace-kernel.macho
echo "期望 5df568a5ca871fbccd643df86c5a6728c85b80ee1830e53a49656ea4c2e37547"
echo "== done $(date -u +%FT%TZ)"
