#!/bin/bash
# 根卷制备进度：成员下载/解盘/写窗口的量化进度与 ETA（滚动速率）
exec > /mnt/e/Code/HackIos/out/root-progress.txt 2>&1
W=/home/unixnu/code/umi-work-pin
LOG=$W/out/umi-xnu/userdata-prepare.log
echo "== 时间 $(date -u +%FT%TZ)"
pgrep -af "prepare_umi_root[.]py" | head -3 || echo "进程不在"
echo "-- 日志 --"
tail -8 "$LOG" 2>/dev/null
echo "-- ipsw 缓存 --"
ls -l $W/out/umi-xnu/ipsw/21H461/ 2>/dev/null | awk '{print $5, $9}'
echo "-- 状态文件 --"
cat $W/out/umi-xnu/umi/userdata/preparation.json 2>/dev/null | python3 -c "
import json,sys
try: s=json.load(sys.stdin)
except Exception: print('还没有 preparation.json'); raise SystemExit
print('windows=',[(w['name'],w['size']) for w in s['windows']])
"
echo "-- partial 镜像 --"
ls -l $W/out/umi-xnu/umi/userdata/ 2>/dev/null | awk '{print $5, $9}'
echo "-- 磁盘 --"
df -h / | tail -1
echo "-- 速率（10s 采样）--"
A=$(du -sb $W/out/umi-xnu 2>/dev/null | cut -f1); sleep 10
B=$(du -sb $W/out/umi-xnu 2>/dev/null | cut -f1)
echo "10s 增量 = $(( (B-A)/1048576 )) MiB  ->  $(( (B-A)/10485760 )) MiB/s"
