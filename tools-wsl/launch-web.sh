#!/bin/bash
# 安装并后台启动 umi Web 监控（端口 8765），自检一次 /api/state
set -u
S=/mnt/e/Code/HackIos/tools-wsl
OUT=/mnt/e/Code/HackIos/out/probes/web-launch.txt
{
  tr -d '\r' < "$S/monitor_umi.py" > /usr/local/bin/umi-mon.py
  tr -d '\r' < "$S/monitor_web.py" > /usr/local/bin/umi-web.py
  python3 -c 'import ast; ast.parse(open("/usr/local/bin/umi-web.py").read()); print("SYNTAX_OK")' || exit 1
  pkill -f 'umi-we[b].py'
  sleep 0.6
  setsid nohup python3 /usr/local/bin/umi-web.py > /var/log/umi-web.log 2>&1 < /dev/null &
  sleep 1.5
  echo "== 监听"
  ss -tlnp | grep 8765 || echo "没起来，见 /var/log/umi-web.log"
  echo "== 日志头"
  head -3 /var/log/umi-web.log
  echo "== state 自检"
  curl -s 'http://127.0.0.1:8765/api/state?lines=6' | python3 -c 'import json,sys; d=json.load(sys.stdin); print("keys:", len(d)); print({k: d[k] for k in ("phase","run","cpu","mem_used","ncpu")}); print("idle:", d["idle"]); print("lanes:", len(d["lanes"]), "log:", len(d["log"]["lines"]), "patches:", d["patches"], "arts:", [(a["name"],a["size"]) for a in d["artifacts"]]); print("alive:", d["alive"], "pid:", d["pid"], "elapsed:", d["elapsed"]); print("cmd:", (d["cmd"] or "(无任务)")[:200]); print("log_path:", d["log_path"])'
  echo "== html 自检"
  curl -s http://127.0.0.1:8765/ > /tmp/web-page.html; wc -c < /tmp/web-page.html
  for id in cmd cmdmeta cmdpath bp be bl br bk clock log; do
    grep -q "id=\"$id\"" /tmp/web-page.html && echo "元素 $id 在" || echo "元素 $id 不在"
  done
  echo "== 已删项自检（应为 0）"
  echo "select bi: $(grep -c 'id="bi"' /tmp/web-page.html)  footer: $(grep -c '<footer>' /tmp/web-page.html)  只读文案: $(grep -c '面板只读' /tmp/web-page.html)"
} > "$OUT" 2>&1
echo WROTE "$OUT"
