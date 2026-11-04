#!/bin/bash
# 安装监控 + 单帧自检 + 确认 WSLg 里可用的终端程序
set -e
tr -d "\r" < /mnt/e/Code/HackIos/tools-wsl/monitor_umi.py > /usr/local/bin/umi-mon.py
chmod 755 /usr/local/bin/umi-mon.py
cat > /usr/local/bin/uefi-mon <<'EOF'
#!/bin/sh
exec python3 /usr/local/bin/umi-mon.py "$@"
EOF
chmod 755 /usr/local/bin/uefi-mon
echo "== 单帧自检"
UMI_ONCE=1 python3 /usr/local/bin/umi-mon.py > /mnt/e/Code/HackIos/out/probes/mon-frame.txt 2>&1 || echo "SELFTEST RC=$?"
echo "== 可用 GUI 终端"
for t in xterm xfce4-terminal gnome-terminal konsole weston-terminal urxvt; do
  p=$(command -v $t 2>/dev/null) && echo "  $t -> $p"
done
echo "== WSLg 环境"
echo "  WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset} DISPLAY=${DISPLAY:-unset}"
ls /mnt/wslg 2>/dev/null | head -5
echo DONE
