#!/bin/bash
# 答「PE_lockdown_iokit 之后屏幕还会不会动」：三张截屏比对 + 这行之后还有没有上屏标记
set -u
OUT=/mnt/e/Code/HackIos/out/probes/d-pe-lockdown2.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
Q=/home/unixnu/code/umi-work-pin/out/umi-qemu
W=/home/unixnu/code/umi-work-pin

say "== 1. run-15/16/17 截屏是否逐字节相同 =="
sha256sum "$Q"/run-15-amfi-guard/screen.png "$Q"/run-16-amfi-go/screen.png "$Q"/run-17-el0-read/screen.png 2>&1 >> "$OUT"
say "-- 每张的 mtime（起算 boot 到截屏的墙钟）--"
stat -c '%n  screen=%y' "$Q"/run-15-amfi-guard/screen.png "$Q"/run-16-amfi-go/screen.png "$Q"/run-17-el0-read/screen.png 2>&1 >> "$OUT"
stat -c '%n  provenance=%y' "$Q"/run-17-el0-read/provenance.json 2>&1 >> "$OUT"

say
say "== 2. run-17 结束现场（屏幕之外唯一的进度证据）=="
python3 - <<'PY' >> "$OUT" 2>&1
import json
d = json.load(open("/home/unixnu/code/umi-work-pin/out/umi-qemu/run-17-el0-read/gdb-stop.json"))
keys = [k for k in ("pc", "sp", "lr", "current_el", "bounded_timeout_interrupted",
                    "timeout_seconds", "elapsed_seconds", "x16", "ESR_EL1", "read_memory",
                    "user_memory", "observations") if k in d]
for k in keys:
    print(k, "=", json.dumps(d[k])[:400])
print("全部键:", sorted(d))
PY

say
say "== 3. PE_lockdown_iokit 之后源码里还有哪些上屏钩子 =="
grep -rn "PE_lockdown_iokit" "$W"/devices/umi/patches/umi-xnu/*.patch | head -8 >> "$OUT"
say "-- 上屏补丁挂的 bootstrap 钩子清单（画屏器被谁调）--"
grep -n "umi_paint\|UMI_MARK\|kernel_bootstrap_log" "$W"/devices/umi/patches/umi-xnu/*screen*.patch 2>/dev/null | head -25 >> "$OUT"
say "-- 树里 kernel_bootstrap_log 的实际调用序列（bsd_init 段）--"
grep -rn "kernel_bootstrap_log(" "$W"/out/umi-xnu/umi/tree/.cache/xnu-work/bsd/kern/bsd_init.c 2>/dev/null | head -20 >> "$OUT"
say "-- startup 阶段表顺序 --"
grep -n "PE_lockdown_iokit\|bsd_init\|kernel_bootstrap_thread\|io_map_purge\|post_hibernation" \
  "$W"/out/umi-xnu/umi/tree/.cache/xnu-work/osfmk/kern/startup.c 2>/dev/null | head -20 >> "$OUT"
say done
