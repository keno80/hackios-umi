#!/bin/bash
W=/home/unixnu/code/umi-work-pin
cat > "$W/out/tui-state" <<'EOF'
PHASE=wait
RUN=#16 ram 档镜像已就绪，等你上机
TOOL=fastboot boot（零写盘）
LOG=/home/unixnu/code/umi-work-pin/out/umi-fw/pack-ram.log
NOTE1=镜像 out/umi-uefi-menu-ram.img 9744384B sha f79944a9；FD+DTB+FAT 全部逐字节自检通过
NOTE2=诊断 App 已打上屏补丁（MemOut.h）+ 结尾 SUMMARY + 等按键 90s
TASK1=done|#10 菜单镜像上机（零写盘）
TASK2=done|#16 镜像打包与自检
TASK3=wait|#16 你跑 fastboot boot 并拍屏
TASK4=block|#15 需 Apple 参考件
PID=0
EOF
echo "面板已切到 wait"
ls -l "$W/out/umi/boot/umi-uefi-menu-ram.img" | sed 's#^#  #'
ls -l /mnt/e/Code/HackIos/out/umi-uefi-menu-ram.img | sed 's#^#  #'
