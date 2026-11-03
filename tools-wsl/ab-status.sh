#!/bin/bash
# A/B 两条内核构建的状态、阶段与错误摘要
set -u
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs

report() {
  local label=$1 pidf=$2 logf=$3
  local pid log
  pid=$(cat "$L/$pidf" 2>/dev/null)
  log=$(cat "$L/$logf" 2>/dev/null)
  echo "===== $label ====="
  if [ -z "${pid:-}" ]; then echo "未起跑"; return; fi
  if kill -0 "$pid" 2>/dev/null; then echo "pid=$pid 运行中"; else echo "pid=$pid 已退出"; fi
  echo "日志=$log"
  [ -f "$log" ] || { echo "无日志文件"; return; }
  echo "大小=$(wc -c < "$log") 字节  行数=$(wc -l < "$log")"
  local step
  step=$(grep -oE '^(bootstrap|corecrypto-plain|corecrypto-namespace|pthread|ArmDTPlatform|ArmCpu|native-ufs|ufs-probe|pmgr|kernel|prepare|fetch|tree|package):' "$log" 2>/dev/null | tail -1)
  echo "最近步骤=${step:-?}"
  echo "make 进度=$(grep -oE '\[[0-9]+/[0-9]+\]' "$log" | tail -1)"
  echo "错误行=$(grep -cE 'error:|Error [0-9]|\*\*\* |FAILED:|ninja: build stopped' "$log" 2>/dev/null)"
  echo "-- 尾部 12 行 --"
  tail -12 "$log"
}

report "路B main(--skip-prelink)" kernel-main.pid kernel-main-latest.txt
echo
report "路A pin+Linux回移" kernel-pin.pid kernel-pin-latest.txt

echo
echo "===== kernel.macho ====="
find /home/unixnu/code/umi-work /home/unixnu/code/umi-work-pin /home/unixnu/code/UniXNU-main/out -name 'kernel.macho' -printf '%TY-%Tm-%Td %TH:%TM %10s  %p\n' 2>/dev/null | sort
