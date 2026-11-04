#!/bin/bash
# T 步的设计输入：mockfs 假根到底能不能承载「多个真 Apple 文件」。
# 已知：legacy 模式下整块 md0 就是那一个 Mach-O；非 legacy 是 N4KROOT 双段头（内存里记 22=EINVAL 那条）。
# 要回答三件事，决定「塞真件」这一发的做法：
#   1) mockfs 的容器格式（N4KROOT）里除了 init Mach-O 还有没有文件表/第二个文件；
#   2) 它给 exec 暴露的路径名是固定的还是从容器里取的；
#   3) md0 的大小上限由谁定（DarwinBoot 的 RamdiskAddress 窗口有多大），真 launchd 装不装得下。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s31-mockfs-container.txt 2>&1
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree

echo "== 1. mockfs 相关源文件在哪 =="
find "$T/.cache/xnu-work" -iname '*mockfs*' -printf '%10s %p\n' 2>/dev/null | head -20
find "$T/drivers/DarwinBoot" -iname '*mockfs*' -o -iname '*ramdisk*' 2>/dev/null | head -20

echo
echo "== 2. N4KROOT 容器格式定义（结构体/魔数/字段）=="
grep -rn 'N4KROOT' "$T/.cache/xnu-work" "$T/drivers" "$T/scripts" 2>/dev/null | grep -v Binary | head -20

echo
echo "== 3. mockfs 挂载实现里文件名从哪来（找 vnode/namei/lookup）=="
M=$(find "$T/.cache/xnu-work" -iname 'mockfs*.c' | head -1); echo "  文件: $M"
[ -n "$M" ] && grep -n 'lookup\|name\|strcmp\|memcpy.*name\|MACH\|header\|magic' "$M" | head -40

echo
echo "== 4. mockfs 里可执行文件的暴露方式（是不是把整块当单个 vnode）=="
[ -n "$M" ] && awk 'NR<=60 {printf "%d\t%s\n", NR, $0}' "$M"

echo
echo "== 5. 上游 build-mockfs-fixture.py 造的是什么（有没有多文件系统条目）=="
sed -n '1,80p' /home/unixnu/code/UniXNU-main/scripts/build-mockfs-fixture.py

echo
echo "== 6. 我们的 initrd 通路：build-xnu-payload.py 里 --mockfs-initrd 怎么塞 =="
grep -n 'mockfs\|initrd\|ramdisk\|N4KROOT' /mnt/e/Code/HackIos/tools-wsl/build-xnu-payload.py | head -30
