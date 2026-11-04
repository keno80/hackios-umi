#!/bin/bash
# 把根卷制备任务写进监控面板的状态卡（面板读 out/tui-state）
set -u
W=/home/unixnu/code/umi-work-pin
STATE=$W/out/tui-state
IMG_BYTES_TOTAL=8362168320   # 4918+3150 MiB 两个成员的下载量

pid=$(pgrep -f 'prepare_umi_root[.]py' | head -1)
cur=$(du -b $W/out/umi-xnu/ipsw/21H461/*.partial $W/out/umi-xnu/ipsw/21H461/*.dmg 2>/dev/null | awk '{s+=$1} END {print s+0}')
pct=$(( cur * 100 / IMG_BYTES_TOTAL ))
done_w=$(python3 -c "
import json,pathlib
p=pathlib.Path('$W/out/umi-xnu/umi/userdata/preparation.json')
print(len(json.loads(p.read_text())['windows']) if p.exists() else 0)
" 2>/dev/null || echo 0)

cat > "$STATE" <<EOF
PHASE=root-prep
RUN=userdata-root
TOOL=ipsw range + udif / SHNGROOT v1
LOG=$W/out/umi-xnu/userdata-prepare.log
START_TS=$(stat -c %Y $W/out/umi-xnu/userdata-prepare.log 2>/dev/null || date +%s)
NOTE1=下载+解盘 累计 ${pct}%（${cur} / ${IMG_BYTES_TOTAL} B），窗口已验 ${done_w}/2
NOTE2=源=iPad7,1 17.7.11 21H461 IPSW；只读 range，不整机下载
TASK1=done|#12 kt_fixed_zones=120 过 zone 断言
TASK2=done|#13 归因=缺根设备（阶段6）
TASK3=run|#14 造 userdata-root.img 并让 QEMU 挂根
TASK4=gate|#10 上真机（需你确认写操作）
EOF
[ -n "$pid" ] && echo "PID=$pid" >> "$STATE"
echo "== 状态卡已写 =="
cat "$STATE"
