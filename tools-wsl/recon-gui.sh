#!/bin/bash
{
echo '== 可用 GUI 终端'
for t in xterm xfce4-terminal gnome-terminal konsole weston-terminal urxvt st; do
  p=$(command -v "$t" 2>/dev/null) && echo "  $t -> $p"
done
echo '  (无输出=都没装)'
echo '== WSLg 环境'
echo "  WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset} DISPLAY=${DISPLAY:-unset}"
ls -d /mnt/wslg 2>/dev/null && ls /mnt/wslg 2>/dev/null | head -6
echo '== 昨晚 qemu 是怎么起窗口的（gdb-stop.py 的 display 参数）'
G=/home/unixnu/code/UniXNU/scripts/qemu-entry/gdb-stop.py
grep -n "display\|sdl\|gtk\|vnc\|qemu-system" $G | head -20
echo '== 该文件是否存在'
ls -l $G
echo '== run-01 的 provenance 里 qemu 命令行'
python3 -c "import json;d=json.load(open('/home/unixnu/code/umi-work-pin/out/umi-qemu/run-01/provenance.json'));print(json.dumps(d.get('command') or d,indent=1,ensure_ascii=False)[:1200])"
echo DONE
} > /mnt/e/Code/HackIos/out/gui-check.txt 2>&1
