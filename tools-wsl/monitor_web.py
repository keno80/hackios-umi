#!/usr/bin/env python3
"""umi 监控 Web 版：标准库 HTTP 服务，数据层直接复用 /usr/local/bin/umi-mon.py。

路由：
  GET  /                 单页面板
  GET  /api/state        JSON 快照（?err=1 只看 error，&lines=N 取尾部 N 行）
  POST /api/kill         终止状态文件里的当前 PID（需 X-Confirm: kill-<pid>）
只读采集 /proc、ps、git、df、日志；除 /api/kill 外不写任何系统状态，绝不碰手机。
"""
import importlib.util
import json
import os
import re
import socket
import time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MON_PATH = os.environ.get("UMI_MON", "/usr/local/bin/umi-mon.py")
PORT = int(os.environ.get("UMI_WEB_PORT", "8765"))
QEMU_OUT = os.environ.get("UMI_QEMU_OUT", "/home/unixnu/code/umi-work-pin/out/umi-qemu")
LIVE_SOCK = os.path.join(QEMU_OUT, "live", "qmp.sock")
LIVE_SHOT = os.path.join(QEMU_OUT, "live", "panel.png")

_spec = importlib.util.spec_from_file_location("umi_mon", MON_PATH)
M = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(M)

ANSI = re.compile(r"\033\][^\x07]*\x07|\033\[[0-9;=?!]*[A-Za-z]")
CTRL = re.compile(r"[\x00-\x08\x0b-\x1f\x7f]")
CORE_PAIRS = 6


def clean(s):
    """去掉终端转义与残留控制符：ANSI 面板看不见，HTML 里会露出 [0m。"""
    return CTRL.sub("", ANSI.sub("", s or ""))


def cores_pairs():
    total, cores = M.proc_stat()
    cpu = M.pct(total, M._prev["cpu"])
    M._prev["cpu"] = total
    pairs = []
    if cores:
        names = sorted(cores, key=lambda x: int(x[3:]))
        vals = [M.pct(cores[n], (M._prev["cores"] or {}).get(n)) for n in names]
        M._prev["cores"] = cores
        for i in range(0, len(vals) - 1, 2):
            pairs.append(round((vals[i] + vals[i + 1]) / 2, 1))
    return round(cpu, 1), pairs[:CORE_PAIRS]


_hist = deque(maxlen=120)


def qmp_dump(timeout=4.0):
    """让常驻 live QEMU 自己吐一帧：QMP screendump format=png（作者脚本同款调法）。"""
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect(LIVE_SOCK)
    stream = s.makefile("rw")

    def req(cmd, args, ident):
        stream.write(json.dumps({"execute": cmd, "arguments": args, "id": ident}) + "\n")
        stream.flush()
        while True:
            line = stream.readline()
            if not line:
                raise RuntimeError("QMP 连接断了")
            msg = json.loads(line)
            if msg.get("id") == ident:
                if "error" in msg:
                    raise RuntimeError(str(msg["error"]))
                return
    req("qmp_capabilities", {}, 1)
    req("screendump", {"filename": LIVE_SHOT, "format": "png"}, 2)
    s.close()


_shot = {"t": 0.0, "err": "", "fail_t": 0.0}


def live_running():
    """live 实例的 pid 文件还在进程表里才算活着；残留 socket 不算。"""
    try:
        pid = int(open(os.path.join(QEMU_OUT, "live", "qemu.pid")).read().strip())
    except (OSError, ValueError):
        return False
    return os.path.isdir(f"/proc/{pid}")


def live_frame():
    now = time.time()
    if not os.path.exists(LIVE_SOCK) or not live_running():
        _shot["err"] = ""
        return None
    if now - _shot["t"] < 2.0:
        return LIVE_SHOT if os.path.isfile(LIVE_SHOT) else None
    if _shot["err"] and now - _shot["fail_t"] < 15:
        return None
    _shot["t"] = now
    try:
        qmp_dump()
        _shot["err"] = ""
    except (OSError, ValueError) as e:
        _shot["err"], _shot["fail_t"] = str(e), now
        return None
    return LIVE_SHOT if os.path.isfile(LIVE_SHOT) else None


def current_frame(run):
    """(路径, 来源)：live 实时帧 > 本次 run 的停点帧 > 最近一次停点帧。"""
    live = live_frame()
    if live:
        return live, {"source": "live", "run": "live"}
    if run and re.fullmatch(r"[\w.\-]+", run):
        p = os.path.join(QEMU_OUT, run, "screen.png")
        if os.path.isfile(p):
            return p, {"source": "stop", "run": run}
    best, name = None, ""
    try:
        for n in os.listdir(QEMU_OUT):
            q = os.path.join(QEMU_OUT, n, "screen.png")
            if os.path.isfile(q) and (best is None or os.path.getmtime(q) > best):
                best, name = os.path.getmtime(q), n
    except OSError:
        return None, {"source": None}
    if not best:
        return None, {"source": None}
    return os.path.join(QEMU_OUT, name, "screen.png"), {"source": "stop", "run": name, "old": True}


def screen_info(run):
    path, meta = current_frame(run)
    if _shot["err"]:
        meta["err"] = _shot["err"]
    if not path:
        meta["v"] = None
        return meta
    st = os.stat(path)
    meta.update({"v": int(st.st_mtime), "bytes": st.st_size})
    return meta


def progress(st):
    label = st.get("PROGRESS_LABEL", "")
    try:
        tot = float(st["PROGRESS_TOTAL"])
        val = float(st["PROGRESS_VALUE"])
    except (KeyError, ValueError):
        return {"label": label, "frac": None, "value": None, "total": None, "eta": None}
    _hist.append((time.time(), val))
    eta = None
    if len(_hist) >= 8:
        dt = _hist[-1][0] - _hist[0][0]
        dv = _hist[-1][1] - _hist[0][1]
        if dv > 0 and dt > 0:
            eta = round((tot - val) / (dv / dt))
    return {"label": label, "frac": max(0.0, min(1.0, val / tot)) if tot else 0.0,
            "value": st.get("PROGRESS_VALUE"), "total": st.get("PROGRESS_TOTAL"), "eta": eta}


def snapshot(lines, err_only):
    st = M.read_state()
    pid = st.get("PID", "")
    alive = bool(pid) and os.path.isdir(f"/proc/{pid}")
    elapsed = None
    if st.get("START_TS"):
        try:
            elapsed = max(0, int(time.time() - float(st["START_TS"])))
        except ValueError:
            pass
    try:
        la = open("/proc/loadavg").read().split()[:3]
    except OSError:
        la = ["-", "-", "-"]
    mu, mt = M.mem()
    du, dd = M.disk()
    cpu, pairs = cores_pairs()
    logs = [clean(ln) for ln in M.log_tail(st, lines, err_only)]
    lanes = [dict(name=clean(n), cpu=round(c, 1), secs=s) for n, c, s in M.lanes(st)]
    lanes = [l for l in lanes if "umi-web" not in l["name"] and "umi-mon" not in l["name"]]
    while len(lanes) < 4:
        lanes.append({"name": "idle", "cpu": 0.0, "secs": 0})
    edk2c, dirty, uefic, uefid = M.repo_state()
    return {
        "now": time.strftime("%H:%M:%S"),
        "phase": st.get("PHASE", "idle"),
        "run": st.get("RUN", "-"),
        "tool": st.get("TOOL", ""),
        "log_path": M.log_target(st),
        "pid": pid,
        "alive": alive,
        "elapsed": elapsed,
        "idle": M.idle_info(st, alive),
        "loadavg": la,
        "cpu": cpu,
        "cores": pairs,
        "ncpu": os.cpu_count() or 1,
        "mem_used": round(mu, 2), "mem_total": round(mt, 2),
        "disk_used": round(du / 1024, 1), "disk_total": round(dd / 1024, 1),
        "lanes": lanes,
        "progress": progress(st),
        "log": {"lines": logs, "err_only": err_only},
        "repos": {"uefi": {"sha": uefic, "dirty": uefid}, "edk2": {"sha": edk2c, "dirty": dirty}},
        "patches": [{"name": p, "on": s == "on"} for p, s in M.patch_state()],
        "artifacts": [{"name": n, "size": sz, "expect": ex,
                       "frac": (sz / ex if ex else (1.0 if sz else 0.0))}
                      for n, sz, ex in [(a[0], a[1], a[2]) for a in M.artifacts()]],
        "cmd": M.cmdline(pid) if alive else "",
        "screen": screen_info(st.get("RUN", "")),
    }


PAGE = """<!doctype html>
<html lang="zh"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>UniXNU umi 监控</title>
<style>
:root{--bg:#0b0f14;--fg:#d7e2ea;--dim:#6b7c8c;--acc:#35e08a;--warn:#f2b13c;--err:#ff5f56;
--cyan:#39c6d0;--line:#1d2833;--card:#101820;--head:#0e2a31}
*{box-sizing:border-box}
html,body{height:100%;overflow:hidden}
body{margin:0;background:var(--bg);color:var(--fg);font:13px/1.45 "Cascadia Mono",Consolas,"Noto Sans Mono CJK SC",monospace;
font-variant-numeric:tabular-nums;display:flex;flex-direction:column}
header{padding:8px 14px;border-bottom:1px solid var(--line);display:flex;flex-wrap:wrap;gap:14px;align-items:baseline}
header b{color:var(--acc);font-size:15px;letter-spacing:.5px}
.chip{padding:1px 8px;border:1px solid var(--line);border-radius:3px;color:var(--dim)}
.chip.on{color:var(--acc);border-color:#1c4b33}.chip.off{color:var(--warn);border-color:#4b3a1c}
.grid{flex:1;min-height:0;display:grid;grid-template-columns:minmax(0,1.65fr) minmax(340px,1fr);gap:10px;padding:10px 14px}
.col{display:flex;flex-direction:column;gap:10px;min-height:0;min-width:0}
@media (max-width:900px){.grid{grid-template-columns:1fr}}
.card{background:var(--card);border:1px solid var(--line);border-radius:4px;overflow:hidden;
display:flex;flex-direction:column;min-height:0}
.card.grow{flex:1}
.card.screen{flex:1 1 160px;min-height:120px}
.card>h3{margin:0;padding:4px 10px;background:var(--head);color:#dff3f7;font-size:12px;font-weight:700;
display:flex;justify-content:space-between}
.card>h3 span{color:#4d7d88;font-weight:400}
.card>div{padding:6px 10px}
.row{display:flex;align-items:center;gap:8px;white-space:nowrap;overflow:hidden}
.row .nm{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis}
.meter{height:9px;background:#16202a;border-radius:2px;flex:0 0 120px;overflow:hidden}
.meter i{display:block;height:100%;background:var(--acc);transition:width .4s}
.meter i.w{background:var(--warn)}.meter i.e{background:var(--err)}
.pct{width:56px;text-align:right;color:var(--dim)}
pre{margin:0;padding:6px 10px;flex:1;min-height:0;overflow:auto;background:#0a1218;
font:12px/1.5 inherit;white-space:pre-wrap;word-break:break-all;color:#b9c8d4}
pre .e{color:var(--err)}pre .w{color:var(--warn)}pre .a{color:var(--acc)}
pre.calm{opacity:.45}
.co{display:grid;grid-template-columns:repeat(6,1fr);gap:5px;margin-top:6px}
.co div{background:#16202a;border-radius:2px;height:20px;position:relative;overflow:hidden}
.co div i{position:absolute;bottom:0;left:0;right:0;background:#2a7f5f}
.co div b{position:absolute;width:100%;text-align:center;font-size:10px;color:#8fa3b3;font-weight:400}
.ok{color:var(--acc)}.no{color:var(--dim)}.ba{color:var(--err)}
.card.cmd{flex:0 0 auto}
.card.cmd pre{flex:none;max-height:144px}
.card.cmd .path{color:var(--dim);padding:2px 10px 6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.note{color:var(--dim);margin-top:6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.keys{display:flex;gap:8px;flex-wrap:wrap;align-items:center}
button{background:#152029;color:var(--fg);border:1px solid var(--line);border-radius:3px;
padding:3px 10px;font:inherit;cursor:pointer}
button:hover{border-color:var(--cyan)}button.act{color:var(--acc);border-color:#1c4b33}
button.danger{color:var(--err);border-color:#4b1c1c}
header>.chip{margin-left:auto}
.stale{color:var(--err)}
.shot{flex:1;min-height:120px;display:flex;flex-direction:column;gap:4px;background:#05090d;padding:6px;overflow:hidden}
.shot img{flex:1;min-height:0;width:100%;object-fit:contain;image-rendering:pixelated;cursor:zoom-in;background:#000}
#zoom{position:fixed;inset:0;background:rgba(4,8,12,.94);display:none;align-items:center;justify-content:center;z-index:9;cursor:zoom-out}
#zoom.on{display:flex}
#zoom img{max-width:96vw;max-height:92vh;image-rendering:pixelated}
</style></head><body>
<header>
  <b>UniXNU · umi</b>
  <div class="keys">
    <button id="bp">暂停</button><button id="be">只看 error</button><button id="bl">全量 log</button>
    <button id="br">立即刷新</button><button id="bk" class="danger">终止当前任务</button>
  </div>
  <span class="chip" id="clock">—</span>
</header>
<div class="grid">
  <div class="col">
    <div class="card"><h3>编译/工作通道 <span>top4 by CPU</span></h3><div id="lanes"></div>
      <div id="prog"></div></div>
    <div class="card cmd"><h3>当前命令 <span id="cmdmeta"></span></h3>
      <pre id="cmd">等待数据…</pre><div class="path" id="cmdpath"></div></div>
    <div class="card grow"><h3>日志尾部 <span id="loglbl"></span></h3><pre id="log">等待数据…</pre></div>
  </div>
  <div class="col">
    <div class="card"><h3>WSL 资源 <span id="ncpu"></span></h3><div id="res2"></div>
      <div class="co" id="cores"></div></div>
    <div class="card"><h3>树 / 补丁 <span>只读探测</span></h3><div id="repos"></div></div>
    <div class="card"><h3>产物 <span>FD 期望 3,145,728B</span></h3><div id="arts"></div></div>
    <div class="card screen grow"><h3>QEMU 画面 <span id="srclbl">无画面</span></h3>
      <div class="shot"><img id="shot" alt="QEMU 画面" style="display:none">
        <div id="shotmsg" class="note" style="white-space:normal"></div></div></div>
  </div>
</div>
<div id="zoom"><img id="zoomimg" alt="QEMU 画面（放大）"></div>
<script>
let err=false, full=false, paused=false, iv=1000, timer=null, fails=0;
const $=id=>document.getElementById(id);
const esc=s=>(s||"").replace(/[&<>]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;"}[c]));
const fmt=n=>(n||0).toLocaleString("en-US");
const hms=s=>`${String(s/3600|0).padStart(2,"0")}:${String(s%3600/60|0).padStart(2,"0")}:${String(s%60).padStart(2,"0")}`;
const cls=v=>v>95?"e":v>70?"w":"";
function meter(frac,label,kind){const k=kind||(frac>.95?"e":frac>.7?"w":"");
 return `<div class="row"><span class="nm">${esc(label)}</span><span class="meter"><i class="${k}" style="width:${Math.min(100,frac*100).toFixed(0)}%"></i></span><span class="pct">${esc(label.split("|")[1]||"")}</span></div>`;}
function row(nm,val,frac,kind){return `<div class="row"><span class="nm">${esc(nm)}</span>`+
 `<span class="meter"><i class="${kind||""}" style="width:${Math.min(100,(frac||0)*100).toFixed(0)}%"></i></span>`+
 `<span class="pct">${esc(val)}</span></div>`;}
async function tick(){
  if(paused) return;
  let d;
  try{d=await (await fetch(`/api/state?err=${err?1:0}&lines=${full?400:60}`)).json(); fails=0;}
  catch(e){fails++; $("log").textContent="取数失败："+e+"（WSL 或已休眠，重试中）"; return;}
  $("clock").textContent=d.now+(fails?`  ×${fails}`:"");
  $("clock").className="chip"+(fails?" stale":"");
  $("ncpu").textContent=d.ncpu+" 核";
  $("lanes").innerHTML=d.lanes.map((l,i)=>
    `<div class="row"><span class="nm" style="flex:0 0 22px;color:var(--dim)">w${i+1}</span>`+
    `<span class="nm">${esc(l.name)}</span>`+
    `<span class="meter"><i class="${cls(l.cpu)}" style="width:${Math.min(100,l.cpu).toFixed(0)}%"></i></span>`+
    `<span class="pct">${l.cpu.toFixed(1)}%</span><span class="pct" style="width:52px">${l.secs}s</span></div>`
  ).join("");
  const p=d.progress;
  $("prog").innerHTML=p.frac==null?`<div class="row"><span class="nm" style="color:var(--dim)">进度：状态文件未给 PROGRESS_*</span></div>`:
    row(p.label||"进度",`${p.value}/${p.total}`,p.frac)+
    (p.eta!=null?`<div class="row"><span class="nm" style="color:var(--dim)">ETA ${hms(p.eta)}</span></div>`:"");
  $("res2").innerHTML=
    row("CPU",`${d.cpu}%`,d.cpu/100,cls(d.cpu))+
    row("MEM",`${d.mem_used}G`,d.mem_used/(d.mem_total||1))+
    row("DISK /home",`${d.disk_used}G`,d.disk_used/(d.disk_total||1))+
    row("LOAD",`${d.loadavg[0]}`,Math.min(1,d.loadavg[0]/d.ncpu));
  $("cores").innerHTML=d.cores.map((v,i)=>`<div><b>${i*2}-${i*2+1}</b>`+
    `<i style="height:${Math.min(100,v).toFixed(0)}%"></i></div>`).join("");
  $("repos").innerHTML=
    `<div class="row"><span class="nm">uefi-umi ${esc(d.repos.uefi.sha)}</span><span class="pct">dirty ${d.repos.uefi.dirty}</span></div>`+
    `<div class="row"><span class="nm">Mu_base ${esc(d.repos.edk2.sha)}</span><span class="pct">dirty ${d.repos.edk2.dirty}</span></div>`+
    d.patches.map(x=>`<div class="row"><span class="nm ${x.on?"ok":"no"}">`+
      `${x.on?"✓":"·"} ${esc(x.name)}</span></div>`).join("");
  $("arts").innerHTML=d.artifacts.map(a=>{const k=a.frac>=1?"ok":a.frac>0?"no":"ba";
    return `<div class="row"><span class="nm ${k}">${a.frac>=1?"✓":a.frac>0?"…":"—"} ${esc(a.name)}</span>`+
    `<span class="meter"><i class="${a.frac>=1?"":a.frac>0?"w":"e"}" style="width:${Math.min(100,a.frac*100).toFixed(0)}%"></i></span>`+
    `<span class="pct" style="width:104px">${fmt(a.size)}B</span></div>`}).join("");
  const idl=d.idle||{};
  $("cmd").textContent=d.cmd||(d.alive?"（该进程读不到命令行）":"当前无任务");
  $("cmdmeta").textContent=d.alive?`PID ${d.pid} · 已跑 ${hms(d.elapsed||0)}`:(idl.text||"无任务");
  $("cmdpath").textContent=d.log_path||"";
  const lb=(d.log_path||"").split("/").pop()||"无日志";
  $("loglbl").textContent=(err?"仅 error · ":"")+`${d.log.lines.length} 行 · ${lb}`;
  const pre=$("log"); const atBottom=pre.scrollTop+pre.clientHeight>=pre.scrollHeight-30;
  pre.className=idl.level==="dim"?"calm":"";
  pre.title=idl.text||"";
  pre.innerHTML=d.log.lines.map(l=>{const c=/error|ERROR|fail|FAIL|assert|Assert|panic|Abort/.test(l)?"e":
    /warn|WARN/.test(l)?"w":/^==/.test(l)?"a":"";return c?`<span class="${c}">${esc(l)}</span>`:esc(l)}).join("\\n");
  if(atBottom) pre.scrollTop=pre.scrollHeight;
  const s=d.screen||{};
  $("srclbl").textContent = s.source==="live"?"live 抓帧":
    s.source==="stop"?`停点 · ${s.run||""}${s.old?"（上一次）":""}`:"无画面";
  if(s.v){
    const u=`/api/screen?v=${s.v}`;
    if($("shot").dataset.u!==u){$("shot").src=u;$("shot").dataset.u=u;}
    $("shot").style.display="";
    $("shotmsg").textContent = s.err?("live 抓帧失败，退回停点帧："+s.err):"";
  } else {
    $("shot").style.display="none";
    $("shotmsg").textContent = s.err?("live 抓帧失败："+s.err)
      :"暂无画面：run_umi_qemu --capture-screen 停点会落 screen.png；起 live 实例则每 2s 抓一帧";
  }
  $("bk").textContent=`终止当前任务 ${d.alive?("PID "+d.pid):"(无)"}`;
  $("bk").disabled=!d.alive;
}
function restart(){clearInterval(timer); timer=setInterval(tick, iv);}
$("bp").onclick=e=>{paused=!paused; e.target.className=paused?"act":""; e.target.textContent=paused?"继续":"暂停";};
$("be").onclick=e=>{err=!err; e.target.className=err?"act":""; tick();};
$("bl").onclick=e=>{full=!full; e.target.className=full?"act":""; tick();};
$("br").onclick=()=>tick();
$("bk").onclick=async()=>{const pid=prompt(`确认终止 PID？输入 pid 数字：`,"");
  if(!pid) return;
  const r=await fetch("/api/kill",{method:"POST",headers:{"X-Confirm":"kill-"+pid}});
  $("cmdpath").textContent="终止请求："+JSON.stringify(await r.json()); tick();};
$("shot").onclick=()=>{$("zoomimg").src=$("shot").src;$("zoom").classList.add("on");};
$("zoom").onclick=()=>$("zoom").classList.remove("on");
tick(); restart();
</script></body></html>
"""


class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, code, body, ctype):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path, _, query = self.path.partition("?")
        if path == "/":
            self._send(200, PAGE.encode(), "text/html; charset=utf-8")
            return
        if path == "/api/state":
            q = dict(kv.split("=", 1) for kv in query.split("&") if "=" in kv)
            try:
                lines = max(5, min(400, int(q.get("lines", "60"))))
            except ValueError:
                lines = 60
            try:
                body = json.dumps(snapshot(lines, q.get("err") == "1"), ensure_ascii=False).encode()
                self._send(200, body, "application/json; charset=utf-8")
            except Exception as e:  # 面板不能因为一次采集失败就断流
                self._send(500, json.dumps({"error": str(e)}).encode(), "application/json")
            return
        if path == "/api/screen":
            frame, _ = current_frame(M.read_state().get("RUN", ""))
            try:
                with open(frame, "rb") as handle:
                    self._send(200, handle.read(), "image/png")
            except (TypeError, OSError):
                self._send(404, b"no frame", "text/plain")
            return
        self._send(404, b"not found", "text/plain")

    def do_POST(self):
        if self.path != "/api/kill":
            self._send(404, b"not found", "text/plain")
            return
        want = self.headers.get("X-Confirm", "")
        pid = M.read_state().get("PID", "")
        if want != f"kill-{pid}" or not pid:
            self._send(400, json.dumps({"ok": False, "why": "确认串与当前 PID 不符"}).encode(),
                       "application/json; charset=utf-8")
            return
        try:
            os.kill(int(pid), 15)
            self._send(200, json.dumps({"ok": True, "pid": pid}).encode(),
                       "application/json; charset=utf-8")
        except Exception as e:
            self._send(500, json.dumps({"ok": False, "why": str(e)}).encode(),
                       "application/json; charset=utf-8")

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    print(f"umi web monitor on 0.0.0.0:{PORT}  (data={MON_PATH})", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()
