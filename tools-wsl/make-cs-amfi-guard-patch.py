#!/usr/bin/env python3
"""30z：给 bsd/kern/ubc_subr.c 的两处裸 amfi-> 调用补 NULL 守卫，产出可 git apply 的补丁。

产物：patches/umi-xnu/zz…zzz-umi-cs-amfi.patch
"""
import subprocess, sys, os, shutil, textwrap

W = "/home/unixnu/code/UniXNU-main/out/umi/tree/.cache/xnu-work"
REL = "bsd/kern/ubc_subr.c"
OUT = "/mnt/e/Code/HackIos/patches/umi-xnu/zzzzzzzzzzzzzzzzzzzzzzzzzzzzzz-umi-cs-amfi.patch"
PROBE = "/mnt/e/Code/HackIos/out/probes/t18-make-30z.txt"

def log(s):
    print(s, flush=True)
    open(PROBE, "a").write(s + "\n")

open(PROBE, "w").close()

src = open(os.path.join(W, REL), encoding="utf-8", errors="surrogateescape").read()

# --- 前置事实核对 ---
hdr = open(os.path.join(W, "bsd/sys/code_signing_internal.h"), encoding="utf-8", errors="surrogateescape").read()
log("== code_signing_internal.h 38-58 ==")
for i, line in enumerate(hdr.splitlines()[36:58], start=37):
    log("%d\t%s" % (i, line))
log("== 现有补丁是否碰过 ubc_subr.c ==")
for p in sorted(os.listdir("/mnt/e/Code/HackIos/patches/umi-xnu")):
    txt = open("/mnt/e/Code/HackIos/patches/umi-xnu/" + p, encoding="utf-8", errors="replace").read()
    if REL in txt:
        log("TOUCHES " + p)
log("(以上为空则 ubc_subr.c 未被任何补丁改过)")

# --- 两处改动 ---
OLD1 = """	if (blob->csb_entitlements != NULL) {
		amfi->OSEntitlements_invalidate(blob->csb_entitlements);
		osobject_release(blob->csb_entitlements);
"""
NEW1 = """	if (blob->csb_entitlements != NULL) {
		/* umi: no AMFI KPI is registered, so there is nothing to invalidate. */
		if (amfi != NULL) {
			amfi->OSEntitlements_invalidate(blob->csb_entitlements);
		}
		osobject_release(blob->csb_entitlements);
"""
OLD2 = """	assert(ret == KERN_NOT_SUPPORTED);

	ret = amfi->OSEntitlements.adjustContextWithoutMonitor(
"""
NEW2 = """	assert(ret == KERN_NOT_SUPPORTED);

	/* umi: no AMFI KPI is registered, so entitlement queries stay "no entitlement". */
	if (amfi == NULL) {
		return 0;
	}

	ret = amfi->OSEntitlements.adjustContextWithoutMonitor(
"""
for tag, old in (("invalidate", OLD1), ("adjustContextWithoutMonitor", OLD2)):
    n = src.count(old)
    log("anchor %s 命中 %d 处" % (tag, n))
    if n != 1:
        sys.exit("FAIL anchor %s 命中 %d，期望 1" % (tag, n))

new = src.replace(OLD1, NEW1).replace(OLD2, NEW2)

work = "/tmp/30z"
shutil.rmtree(work, ignore_errors=True)
for side in ("a", "b"):
    d = os.path.join(work, side, os.path.dirname(REL))
    os.makedirs(d)
open(os.path.join(work, "a", REL), "w", encoding="utf-8", errors="surrogateescape").write(src)
open(os.path.join(work, "b", REL), "w", encoding="utf-8", errors="surrogateescape").write(new)

rc = subprocess.run(["diff", "-u", "a/" + REL, "b/" + REL], cwd=work, capture_output=True, text=True)
body = rc.stdout.splitlines(True)
if len(body) < 3:
    sys.exit("FAIL diff 空")
patch = "".join(body[2:])
hdr2 = "--- a/%s\n+++ b/%s\n" % (REL, REL)
open(OUT, "w", newline="").write(hdr2 + patch)
log("== 补丁已写 %s ==" % OUT)
log(open(OUT).read())

# --- 校验：对当前工作树（29z 之后）能否 apply ---
r = subprocess.run(["git", "-C", W, "apply", "--check", OUT], capture_output=True, text=True)
log("git apply --check rc=%d %s" % (r.returncode, (r.stderr or "").strip()))
if r.returncode != 0:
    sys.exit("FAIL 补丁不能干净套上工作树")
log("PATCH-OK")
