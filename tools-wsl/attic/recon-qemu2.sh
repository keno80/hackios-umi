#!/bin/bash
# 只读：把 QEMU 运行器关键片段导出到 E: 供阅读
W=/home/unixnu/code/umi-work-pin
{
echo '== run_umi_qemu.py 全文行数'
wc -l $W/tools/run_umi_qemu.py
echo '== display / qemu 命令行构造'
grep -n "display\|sdl\|qemu-system\|-m \|serial\|monitor\|-device\|gdb" $W/tools/run_umi_qemu.py | head -40
echo '== out 目录写了什么'
grep -n "out /\|out/\|write_text\|json.dump\|open(" $W/tools/run_umi_qemu.py | head -30
echo '== --stop / --finish / timeout 的语义'
grep -n "a.stop\|a.finish\|a.timeout\|also_stop\|skip_target_hits\|def main\|def run" $W/tools/run_umi_qemu.py | head -30
echo '== audit_umi_qemu.py 里这道闸的上下文（85-115 行）'
awk 'NR>=85 && NR<=115 {printf "%4d %s\n", NR, $0}' $W/tools/audit_umi_qemu.py
echo '== 昨晚 run-01 的产物'
ls -l $W/out/umi-qemu/run-01 2>/dev/null | head -20
echo DONE
} > /mnt/e/Code/HackIos/out/probes/qemu-runner.txt 2>&1
