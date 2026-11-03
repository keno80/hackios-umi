#!/usr/bin/env python3
"""umi 构建/QEMU 实时监控面板（纯 ANSI，无外部依赖）。

数据来源全部只读：/proc、ps、git、df、日志文件，以及可选的状态文件
  /home/unixnu/code/umi-work-pin/out/tui-state   (key=value)
键：PHASE RUN LOG PID PROGRESS_LABEL PROGRESS_TOTAL PROGRESS_VALUE ETA_HINT
    TASK1..TASK5（格式 "状态|文字"，状态 run/wait/gate/done）
    NOTE1..NOTE3 ARTIFACT1..ARTIFACT3
"""
import atexit, glob, os, re, shutil, signal, subprocess, sys, time, unicodedata

W = "/home/unixnu/code/umi-work-pin"
STATE = os.environ.get("UMI_STATE", f"{W}/out/tui-state")
FD = "/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd"
FD_EXPECT = 3145728
KERNEL = f"{W}/out/umi-xnu/umi/kernel/source-kernel.macho"
EDK2 = "/home/unixnu/code/Mu_Basecore"
UEFI = "/home/unixnu/code/uefi-umi-b"
PATCHES = ["Gic-Spurious", "Mac-Bash3", "Dxe-Trace", "Display-Services-Trace"]
UNI_LOGS = "/home/unixnu/code/UniXNU-main/out/unixnu-logs"
DEV_LOGS = "/mnt/e/Code/HackIos/out"

C = dict(dim="\033[90m", fg="\033[37m", acc="\033[32m", warn="\033[33m",
         err="\033[31m", cyan="\033[36m", head="\033[46;30m", reset="\033[0m",
         bold="\033[1m")


def dw(s):
    return sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in s)


def clip(s, w):
    """宽度截断，跳过 ANSI 序列不计数、不切断。"""
    if dw(strip(s)) <= w:
        return s
    out, n, i = "", 0, 0
    while i < len(s):
        if s[i] == "\033":
            j = s.find("m", i)
            if j != -1:
                out += s[i:j + 1]
                i = j + 1
                continue
        cw = 2 if unicodedata.east_asian_width(s[i]) in "WF" else 1
        if n + cw > w - 1:
            break
        out += s[i]
        n += cw
        i += 1
    return out + "…" + C["reset"]


def pad(s, w):
    return s + " " * max(0, w - dw(s))


def run(cmd, timeout=3):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True,
                              timeout=timeout).stdout.strip()
    except Exception:
        return ""


LIVE_TASKS = ("build_umi_xnu.py", "run_umi_qemu.py", "qemu-system-aarch64",
              "uefi-fw-build", "bootimg", "build-xnu-payload.py", "build-ram-payload.sh")


def task_kind(cmd):
    """把一条 cmdline 归成 (阶段, run 名)，认不出就返回 None。"""
    if "build_umi_xnu.py" in cmd:
        m = re.search(r"--stage\s+(\S+)", cmd)
        return "kernel", (f"stage {m.group(1)}" if m else "build")
    if "run_umi_qemu.py" in cmd or "qemu-system-aarch64" in cmd:
        m = re.search(r"--out\s+(\S+)", cmd)
        return "qemu", (os.path.basename(m.group(1)) if m else "qemu")
    if "uefi-fw-build" in cmd:
        m = re.search(r"uefi-fw-build[\"']?\s+(\S+)", cmd)
        return "firmware", (m.group(1) if m else "uefi-fw")
    if "build-xnu-payload.py" in cmd or "build-ram-payload.sh" in cmd:
        return "pack", "payload 卷"
    if "bootimg" in cmd:
        return "pack", "bootimg"
    return None, None


def cmdline(pid):
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            return f.read().replace(b"\0", b" ").decode("utf-8", "replace").strip()
    except OSError:
        return ""


def proc_start(pid):
    """进程启动的绝对时刻：/proc/stat 的 btime 加上 starttime/HZ。"""
    try:
        with open("/proc/stat") as f:
            btime = next(int(l.split()[1]) for l in f if l.startswith("btime "))
        with open(f"/proc/{pid}/stat") as f:
            fields = f.read().rsplit(")", 1)[1].split()
        return btime + int(fields[19]) / os.sysconf("SC_CLK_TCK")
    except (OSError, ValueError, StopIteration, IndexError):
        return None


def proc_log(pid):
    """驱动自己的 stdout 日志：nohup 重定向到哪，面板就该跟到哪。"""
    for fd in ("1", "2"):
        try:
            path = os.readlink(f"/proc/{pid}/fd/{fd}")
        except OSError:
            continue
        if path.startswith("/") and os.path.isfile(path):
            return path
    return None


def live_task():
    """状态文件没登记、但确实在跑的任务。

    面板只信状态文件的话，任何忘了写 tui-state 的启动脚本都会让它显示「无任务」，
    日志尾巴停在上一轮——看着像编译卡死，其实是面板自己死了。
    """
    now = time.time()
    if _prev["adopt"] and now - _prev["adopt"][0] < 2:
        return _prev["adopt"][1]
    best = None
    for entry in os.listdir("/proc"):
        if not entry.isdigit() or entry == str(os.getpid()):
            continue
        cmd = cmdline(int(entry))
        if not cmd or "monitor_umi" in cmd or "monitor_web" in cmd:
            continue
        if not any(name in cmd for name in LIVE_TASKS):
            continue
        kind, run = task_kind(cmd)
        if kind is None:
            continue
        log = proc_log(int(entry))
        if kind == "qemu" and run == "qemu" and log:
            # 选中往往是 qemu-system 本体，命令行里没有 --out；从日志路径反推 run 名
            m = re.search(r"umi-qemu/([^/]+)/", log.replace(os.sep, "/"))
            if m:
                run = m.group(1)
        try:
            fresh = os.path.getmtime(log) if log else 0
        except OSError:
            fresh = 0
        cand = {"pid": entry, "kind": kind, "run": run, "log": log,
                "start": proc_start(int(entry)), "fresh": fresh}
        if best is None or (cand["fresh"], cand["start"] or 0) > (best["fresh"], best["start"] or 0):
            best = cand
    _prev["adopt"] = (now, best)
    return best


_prev = {"cpu": None, "cores": None, "hist": [], "git": (0, None), "patches": (0, None),
         "adopt": (0, None)}


def read_state():
    st = {}
    try:
        with open(STATE, encoding="utf-8", errors="replace") as f:
            for line in f:
                if "=" in line:
                    k, v = line.rstrip("\n").split("=", 1)
                    st[k.strip()] = v
    except OSError:
        pass
    if not (st.get("PID") and os.path.isdir(f"/proc/{st['PID']}")):
        task = live_task()
        if task:
            st["PID"] = task["pid"]
            st["PHASE"] = task["kind"]
            st["RUN"] = task["run"]
            st["TOOL"] = "自动接管"
            if task["log"]:
                st["LOG"] = task["log"]
            if task["start"]:
                st["START_TS"] = str(int(task["start"]))
    return st


def proc_stat():
    try:
        with open("/proc/stat") as f:
            lines = f.read().splitlines()
    except OSError:
        return None, None
    total = cores = None
    for ln in lines:
        p = ln.split()
        if p[0] == "cpu":
            total = [int(x) for x in p[1:]]
        elif re.match(r"cpu\d+$", p[0]):
            if cores is None:
                cores = {}
            cores[p[0]] = [int(x) for x in p[1:]]
    return total, cores


def pct(cur, prev):
    if not cur or not prev or len(cur) != len(prev):
        return 0.0
    d = [a - b for a, b in zip(cur, prev)]
    idle = d[3] + (d[4] if len(d) > 4 else 0)
    tot = sum(d) or 1
    return max(0.0, min(100.0, 100.0 * (tot - idle) / tot))


def mem():
    info = {}
    try:
        with open("/proc/meminfo") as f:
            for ln in f:
                k, v = ln.split(":", 1)
                info[k] = int(v.split()[0])
    except OSError:
        return 0, 0
    total = info.get("MemTotal", 0) / 1048576
    avail = info.get("MemAvailable", 0) / 1048576
    return total - avail, total


def disk(path="/home"):
    out = run(f"df -m --output=source,used,size {path} 2>/dev/null | tail -1")
    p = out.split()
    return (int(p[1]), int(p[2])) if len(p) >= 3 else (0, 0)


def bar(frac, w, cls="acc"):
    frac = max(0.0, min(1.0, frac))
    n = int(round(frac * w))
    col = {"acc": C["acc"], "warn": C["warn"], "err": C["err"]}[cls]
    return f"[{col}" + "#" * n + C["dim"] + "-" * (w - n) + C["reset"] + "]"


def lanes(st):
    """活跃子进程当作 lane：build 的 clang / qemu 的 vCPU 线程。"""
    out = run("ps -eo etimes=,pcpu=,args= --sort=-pcpu 2>/dev/null | head -60")
    rows, seen = [], set()
    for ln in out.splitlines():
        p = ln.strip().split(None, 2)
        if len(p) < 3:
            continue
        et, cpu, cmd = p
        if "ps -eo" in cmd or "umi-mon" in cmd or "monitor_umi" in cmd or "bash" == cmd.split()[0]:
            continue
        m = re.search(r"(\S+\.(?:c|S|m|cc|cpp))\b", cmd)
        if m:
            name = m.group(1).split("/")[-1]
        elif "qemu-system" in cmd:
            name = "qemu-system-aarch64"
        elif "build.py" in cmd or cmd.startswith("build "):
            name = "build.py (调度)"
        elif "python" in cmd:
            name = "python " + cmd.split()[-1][-24:]
        else:
            name = cmd.split()[0].split("/")[-1] + " " + clip(cmd, 20)
        if name in seen:
            continue
        seen.add(name)
        try:
            secs = int(et)
        except ValueError:
            secs = 0
        rows.append((name, float(cpu.replace(",", ".")), secs))
        if len(rows) >= 4:
            break
    while len(rows) < 4:
        rows.append(("idle", 0.0, 0))
    return rows


def newest_dev_log():
    """没有 WSL 任务在跑时，面板也要指着「最后一件发生的事」的日志。

    上机引导（fastboot boot）的日志在 Windows 侧，构建/QEMU 的在 unixnu-logs；
    两边都进来比 mtime，否则空转时面板会停在几小时前的旧日志上，看着像死了。
    """
    best, best_m = "", 0.0
    for pat in (f"{UNI_LOGS}/*.log", f"{DEV_LOGS}/*.log"):
        for p in glob.glob(pat):
            try:
                m = os.path.getmtime(p)
            except OSError:
                continue
            if m > best_m:
                best, best_m = p, m
    return best


def log_target(st):
    """状态文件的 LOG 若是「步进展器」，跟着它最后一行指到的真实步日志走。

    build_umi_xnu.py 这类驱动只往自己的日志里打「step: /abs/path.log」，编译细节全在步日志里；
    不跟随的话面板会整段干等，看起来像卡死。
    """
    path = st.get("LOG", "")
    chosen = path
    if path and os.path.exists(path):
        try:
            with open(path, "rb") as f:
                f.seek(max(0, os.path.getsize(path) - 8192))
                tail = f.read().decode("utf-8", "replace").splitlines()
        except OSError:
            tail = []
        for ln in reversed(tail[-40:]):
            m = re.fullmatch(r"[A-Za-z0-9_.-]+: (/\S+\.log)", ln.strip())
            if m and os.path.exists(m.group(1)):
                chosen = m.group(1)
                break
    alt = newest_dev_log()
    if alt:
        try:
            if not os.path.exists(chosen) or os.path.getmtime(alt) > os.path.getmtime(chosen):
                return alt
        except OSError:
            pass
    return chosen


def log_tail(st, n, err_only=False):
    path = log_target(st)
    if not path or not os.path.exists(path):
        return ["(无日志路径：状态文件未写 LOG)"]
    try:
        with open(path, "rb") as f:
            f.seek(max(0, os.path.getsize(path) - 262144))
            raw = f.read().decode("utf-8", "replace").splitlines()
    except OSError as e:
        return [f"(读日志失败 {e})"]
    raw = [ln for ln in raw if len(ln) < 300]
    if err_only:
        f = [ln for ln in raw if re.search(r"error|ERROR|fail|FAIL|assert|Assert|panic|Abort", ln)]
        return (f[-n:] or ["(暂无 error 行)"])
    return raw[-n:]


def idle_secs(st):
    """日志与状态文件距今多久没被写过。"""
    stamps = []
    for path in (log_target(st), STATE):
        try:
            stamps.append(os.path.getmtime(path))
        except OSError:
            pass
    return max(0.0, time.time() - max(stamps)) if stamps else None


def idle_info(st, alive):
    """面板冻结时唯一能分清「没任务」和「任务在跑但不出字」的判据。"""
    path = log_target(st)
    secs = idle_secs(st)
    if secs is None:
        return {"secs": None, "text": "静止 ?（无日志/状态文件）", "level": "warn", "path": path}
    mins = int(secs // 60)
    span = f"{mins}分{int(secs % 60):02d}秒" if mins < 60 else f"{mins // 60}小时{mins % 60:02d}分"
    if alive:
        if secs > 120:
            return {"secs": secs, "text": f"任务在跑，日志静默 {span}", "level": "warn",
                    "path": path}
        return {"secs": secs, "text": f"活跃（{span}内有写入）", "level": "on", "path": path}
    return {"secs": secs, "text": f"静止 {span} · 无任务（最后 run {st.get('RUN', '-')}）",
            "level": "dim", "path": path}


def patch_state():
    ts = time.time()
    if _prev["patches"] and ts - _prev["patches"][0] < 12:
        return _prev["patches"][1]
    res = []
    for p in PATCHES:
        f = f"{UEFI}/Resources/MuPatches/{p}.patch"
        chk = run(f"git -C {EDK2} apply --reverse --check {f} 2>/dev/null; echo $?", timeout=6)
        res.append((p, "on" if chk == "0" else "off"))
    _prev["patches"] = (ts, res)
    return res


def repo_state():
    ts = time.time()
    if _prev["git"] and ts - _prev["git"][0] < 12:
        return _prev["git"][1]
    dirty = run(f"git -C {EDK2} status --porcelain 2>/dev/null | wc -l", timeout=6)
    edk2c = run(f"git -C {EDK2} rev-parse --short HEAD 2>/dev/null")
    uefic = run(f"git -C {UEFI} rev-parse --short HEAD 2>/dev/null")
    uefid = run(f"git -C {UEFI} status --porcelain 2>/dev/null | wc -l", timeout=6)
    v = (edk2c, dirty, uefic, uefid)
    _prev["git"] = (ts, v)
    return v


def artifacts():
    rows = []
    size = os.path.getsize(FD) if os.path.exists(FD) else 0
    frac = size / FD_EXPECT if FD_EXPECT else 0
    rows.append(("SILICIUM_UEFI.fd", size, FD_EXPECT, frac))
    ksz = os.path.getsize(KERNEL) if os.path.exists(KERNEL) else 0
    rows.append(("source-kernel.macho", ksz, 18409640, 1.0 if ksz else 0.0))
    img = f"{W}/out/umi/boot/umi-uefi-menu.img"
    isz = os.path.getsize(img) if os.path.exists(img) else 0
    rows.append(("umi-uefi-menu.img", isz, 0, 1.0 if isz else 0.0))
    return rows


def fmt(n):
    return f"{n:,}"


def render(st, w, budget, err_only, full_log, rows):
    left_w = max(46, int(w * 0.61))
    right_w = w - left_w - 3
    lines = []

    def head(title, note, width):
        t = clip(f" {title} ", max(2, width - 2))
        n = clip(f"{note} ", max(0, width - dw(t) - 2))
        return f"{C['head']}{pad(t, dw(t))}{C['reset']}{C['dim']}{pad(n, width - dw(t) - 1)}{C['reset']}"

    phase = st.get("PHASE", "idle")
    run_lbl = {"build": "build firmware", "kernel": "build kernel", "firmware": "build firmware",
               "qemu": "QEMU 内核", "pack": "打包镜像", "idle": "空闲"}.get(phase, phase)
    alive = st.get("PID") and os.path.isdir(f"/proc/{st['PID']}")
    up = st.get("START_TS")
    elapsed = ""
    if up:
        try:
            s = int(time.time() - float(up))
            elapsed = f"{s//3600:02d}:{s%3600//60:02d}:{s%60:02d}"
        except ValueError:
            pass
    la = open("/proc/loadavg").read().split()[:3] if os.path.exists("/proc/loadavg") else ["-", "-", "-"]
    total, cores = proc_stat()
    cpu = pct(total, _prev["cpu"])
    _prev["cpu"] = total
    pair = []
    if cores:
        names = sorted(cores, key=lambda x: int(x[3:]))
        vals = [pct(cores[n], (_prev["cores"] or {}).get(n)) for n in names]
        _prev["cores"] = cores
        for i in range(0, len(vals) - 1, 2):
            pair.append((vals[i] + vals[i + 1]) / 2)
        pair = pair[:3]
    mu, mt = mem()
    du, dd = disk()
    load1 = float(la[0]) if la[0] != "-" else 0
    ncpu = os.cpu_count() or 6

    # ---- 顶部两条状态栏
    b1 = (f"{C['bold']}{C['acc']}UniXNU · umi{C['reset']}  阶段 "
          f"{C['acc'] if alive else C['warn']}{run_lbl}{C['reset']}  run {st.get('RUN','-')}  "
          f"{st.get('TOOL','')}  elapsed {elapsed or '-'}  3s")
    b2 = (f"WSL2 {la[0]} {la[1]} {la[2]}  CPU {cpu:.0f}%  MEM {mu:.1f}/{mt:.1f}G  "
          f"/home {du/1024:.1f}/{dd/1024:.1f}G  {time.strftime('%H:%M:%S')}  {w}x{rows}")
    lines.append(clip(b1, w))
    lines.append(f"{C['dim']}{clip(b2, w)}{C['reset']}")

    # ---- 左：通道 / 右：资源
    lr = lanes(st)
    l_rows = [head("编译/工作通道", "top4 by CPU", left_w)]
    prog_lbl = st.get("PROGRESS_LABEL", "")
    prog_tot = st.get("PROGRESS_TOTAL", "")
    prog_val = st.get("PROGRESS_VALUE", "")
    for i, (name, cu, secs) in enumerate(lr, 1):
        l_rows.append(f" {C['dim']}w{i}{C['reset']} {bar(cu/100.0, 10, 'warn' if cu > 95 else 'acc')} "
                      f"{cu:5.1f}% {clip(name, left_w - 26)} {secs}s")
    frac = None
    try:
        frac = float(prog_val) / float(prog_tot) if prog_val and prog_tot else None
    except ValueError:
        frac = None
    hist = _prev["hist"]
    if frac is not None:
        hist.append((time.time(), float(prog_val)))
        hist[:] = [x for x in hist if time.time() - x[0] < 300][-60:]
        eta = ""
        if len(hist) >= 8:
            dt = hist[-1][0] - hist[0][0]
            dv = hist[-1][1] - hist[0][1]
            if dv > 0 and dt > 0:
                rem = (float(prog_tot) - float(prog_val)) / (dv / dt)
                eta = (f"ETA {int(rem)//60}:{int(rem)%60:02d}  "
                       f"速率 {dv/dt*60:.1f}/min 样本{len(hist)}")
            else:
                eta = "速率 0（累计中）"
        l_rows.append(f" {prog_lbl or '进度'} {bar(frac, left_w - 30, 'acc')} "
                      f"{prog_val}/{prog_tot}  {eta}")
    else:
        l_rows.append(f" {C['dim']}进度：状态文件未给 PROGRESS_*{C['reset']}"[:left_w])
    idle = idle_info(st, bool(alive))
    l_rows.append(head("日志尾部" + ("  [仅 error]" if err_only else ""), idle["text"], left_w))
    n_log = max(4, budget - 7) if full_log else max(4, budget - 8)
    logs = log_tail(st, n_log, err_only)
    calm = idle["level"] == "dim"
    for i, ln in enumerate(logs):
        col = C["dim"] if calm else C["fg"]
        if not calm and re.search(r"error|ERROR|fail|FAIL|assert|Assert|panic", ln):
            col = C["err"]
        elif not calm and re.search(r"warn|WARN", ln):
            col = C["warn"]
        elif not calm and ln.startswith("=="):
            col = C["acc"]
        l_rows.append(f"{col}{clip(ln, left_w - 1)}{C['reset']}")
    if len(logs) < n_log:
        l_rows.append(f"{C['dim']}── 以上为全部 {len(logs)} 行，等下一条输出 ──{C['reset']}")

    r_rows = [head("WSL 资源", f"{ncpu} 核", right_w)]
    r_rows.append(f" CPU  {bar(cpu/100.0, right_w - 16)} {cpu:4.0f}%")
    r_rows.append(f" MEM  {bar(mu/mt if mt else 0, right_w - 16)} {mu:.1f}G")
    r_rows.append(f" DISK {bar(du/dd if dd else 0, right_w - 16)} {du/1024:.1f}G")
    r_rows.append(f" LOAD {bar(load1/ncpu, right_w - 16)} {load1:.2f}")
    for i, v in enumerate(pair):
        r_rows.append(f" c{i*2}-{i*2+1} {bar(v/100.0, right_w - 12)} {v:3.0f}%")
    r_rows.append(head("树 / 补丁", "只读探测", right_w))
    edk2c, dirty, uefic, uefid = repo_state()
    r_rows.append(f" uefi-umi {uefic} dirty {uefid}")
    r_rows.append(f" Mu_base  {edk2c} dirty {dirty}")
    for p, s in patch_state():
        r_rows.append(f" {C['acc']+'✓' if s=='on' else C['dim']+'·'} {C['reset']}{p}")
    r_rows.append(head("产物", "FD 期望 3,145,728B", right_w))
    for name, size, expect, fr in artifacts():
        col = "acc" if fr >= 1 else ("warn" if fr > 0 else "err")
        mark = "✓" if fr >= 1 else ("…" if fr > 0 else "—")
        r_rows.append(f" {C[col] if col in C else C['fg']}{mark}{C['reset']} {name} {fmt(size)}B")
    for i in range(1, 4):
        if st.get(f"ARTIFACT{i}"):
            r_rows.append(f" {C['dim']}{clip(st[f'ARTIFACT{i}'], right_w - 2)}{C['reset']}")
    return l_rows, r_rows, lines


def tasks(st):
    rows = []
    for i in range(1, 6):
        v = st.get(f"TASK{i}")
        if not v:
            continue
        s, _, txt = v.partition("|")
        glyph = {"run": "◉", "gate": "◐", "wait": "○", "done": "✓"}.get(s, "·")
        col = {"run": C["acc"], "gate": C["warn"], "done": C["cyan"]}.get(s, C["dim"])
        rows.append((glyph, col, txt))
    return rows


class Sz:
    def __init__(self, columns, lines):
        self.columns = columns
        self.lines = lines


def term_size():
    # 直接 ioctl，绕开 COLUMNS/LINES 环境变量：窗口拉大后必须立刻拿到新高度
    try:
        import fcntl
        import struct
        import termios
        packed = fcntl.ioctl(1, termios.TIOCGWINSZ, struct.pack("4H", 0, 0, 0, 0))
        rows, cols = struct.unpack("4H", packed)[:2]
        if rows and cols:
            return Sz(cols, rows)
    except OSError:
        pass
    f = shutil.get_terminal_size((110, 40))
    return Sz(f.columns, f.lines)


def probe_size():
    """把光标打到 999;999 再问位置，拿真实视口尺寸。

    wsl.exe 直跑命令时不一定把窗口 resize 转发进 pty，ioctl 会一直停在启动时的
    高度，帧就比视口短；CSI 6n 的应答由终端实时给出，不依赖 winsize。
    """
    if not sys.stdout.isatty():
        return None
    try:
        import select
        import termios
        import tty
        fd = sys.stdin.fileno()
        if not sys.stdin.isatty():
            return None
        old = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            sys.stdout.write("\033[999;999H\033[6n")
            sys.stdout.flush()
            buf = ""
            deadline = time.time() + 0.3
            while time.time() < deadline:
                r, _, _ = select.select([sys.stdin], [], [], 0.03)
                if not r:
                    continue
                buf += sys.stdin.read(1)
                if buf.endswith("R") and "\033[" in buf:
                    break
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
        m = re.search(r"\033\[(\d+);(\d+)R", buf)
        if m:
            rows, cols = int(m.group(1)), int(m.group(2))
            if 5 <= rows <= 500 and 20 <= cols <= 500:
                return Sz(cols, rows)
    except Exception:
        return None
    return None


def diag(size, probed, alt):
    try:
        i = term_size()
        with open("/tmp/umi-mon-diag", "w") as fh:
            fh.write(f"pid={os.getpid()} alt={int(alt)} ioctl={i.columns}x{i.lines} "
                     f"probe={'ok' if probed else 'none'} used={size.columns}x{size.lines} "
                     f"{time.strftime('%H:%M:%S')}\n")
    except OSError:
        pass


def main():
    interval = float(os.environ.get("UMI_INTERVAL", "3"))
    once = os.environ.get("UMI_ONCE") == "1"
    err_only = full_log = paused = False
    alt = False
    if not once and sys.stdout.isatty():
        # 备用屏幕缓冲：没有回滚区，视口不会被底部对齐，拉大窗口不会露出空白
        sys.stdout.write("\033[?1049h\033[?25l")
        sys.stdout.flush()
        atexit.register(lambda: sys.stdout.write("\033[?25h\033[?1049l") or sys.stdout.flush())
        signal.signal(signal.SIGWINCH, lambda *a: None)
        for s in (signal.SIGTERM, signal.SIGHUP):
            signal.signal(s, lambda *a: sys.exit(0))
        alt = True
    while True:
        probed = None if once else probe_size()
        size = probed or term_size()
        diag(size, probed, alt)
        if _prev.get("sz") != (size.columns, size.lines):
            # 尺寸变了：整屏重铺，避免旧帧残影
            _prev["sz"] = (size.columns, size.lines)
            sys.stdout.write("\033[2J\033[H")
        st = read_state()
        left_w = max(46, int(size.columns * 0.61))
        ts = tasks(st)
        foot = []
        for j in range(0, len(ts), 2):
            foot.append(colored_tasks(ts[j:j + 2], left_w))
        if not foot:
            foot = [""]
        # 整帧恰好 size.lines-1 行：顶部 2 + 正文 + 分隔 1 + foot + note + 键位 1
        budget = max(6, size.lines - 1 - 2 - 1 - len(foot) - 2)
        l_rows, r_rows, top = render(st, size.columns, budget, err_only, full_log, size.lines)
        l_rows = (l_rows + [""] * budget)[:budget]
        r_rows = (r_rows + [""] * budget)[:budget]
        body = []
        for i in range(budget):
            a = l_rows[i]
            b = r_rows[i]
            gap = max(0, left_w - dw(strip(a)))
            body.append(a + " " * gap + C["dim"] + "│" + C["reset"] + clip(b, size.columns - left_w - 1))
        note = st.get("NOTE1", "")
        keys = ("[r]刷新 [p]暂停 [e]只看error [l]全量log [k]终止 [q]退出"
                + ("   " + C["warn"] + "⚠ 面板只读，不写手机" + C["reset"]))
        frame = "\n".join(top + body
                          + [C["dim"] + "─" * size.columns + C["reset"]]
                          + foot
                          + [f"{C['dim']}{clip(note, size.columns)}{C['reset']}" if note else "",
                             keys])
        # 帧高恰好 lines-1 行且不打尾换行：换行会让整帧上滚，把右侧面板顶出屏幕
        sys.stdout.write("\033[H" + frame + "\033[J")
        sys.stdout.flush()
        if once:
            return
        cmd = read_key(interval if not paused else 3600)
        if cmd == "q":
            return
        if cmd == "r":
            continue
        if cmd == "p":
            paused = not paused
        if cmd == "e":
            err_only = not err_only
        if cmd == "l":
            full_log = not full_log
        if cmd == "k" and st.get("PID"):
            sys.stdout.write(f"\n{C['warn']}输入 y 终止 PID {st['PID']}{C['reset']} ")
            sys.stdout.flush()
            ans = sys.stdin.readline().strip()
            if ans == "y":
                try:
                    os.kill(int(st["PID"]), 15)
                except Exception as e:
                    print(f"kill 失败 {e}")


def strip(s):
    return re.sub(r"\033\[[0-9;]*m", "", s)


def colored_tasks(chunk, width):
    out = []
    for g, col, t in chunk:
        out.append(f"{col}{g}{C['reset']} {clip(t, int(width / max(1, len(chunk))) - 4)}")
    return pad("  ".join(out), width)


def read_key(timeout):
    """无外部依赖的非阻塞取键；管道/无 tty 时退化为纯轮询。"""
    try:
        import select, termios, tty
        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        tty.setraw(fd)
        r, _, _ = select.select([sys.stdin], [], [], timeout)
        ch = sys.stdin.read(1) if r else ""
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
        return ch
    except Exception:
        time.sleep(timeout)
        return ""


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
    finally:
        print("\033[0m")
