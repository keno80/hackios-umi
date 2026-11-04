#!/bin/bash
# U 步之三备料取证：OS/SystemOS 窗里 APFS 容器到底从哪儿开始、卷 UUID 是什么、只读位能不能真读出来。
# 这是 prepare_umi_root_policy.py 要的 *-volume-info.json 的唯一出处。
exec > /mnt/e/Code/HackIos/out/probes/u95-apfs-window-layout.txt 2>&1
set -u
PIN=/home/unixnu/code/umi-work-pin
MEDIA=$PIN/out/umi-xnu/umi/userdata
IMG=$MEDIA/userdata-root.img

echo "== A. userdata 窗与 provenance =="
cat $MEDIA/preparation.json 2>&1
echo "  -- userdata-root.json --"
cat $MEDIA/userdata-root.json 2>&1

echo
echo "== B. fsapfsinfo / apfsck 支持的偏移参数 =="
fsapfsinfo --help 2>&1 | head -30
echo "  -- apfsck --"
apfsck -h 2>&1 | head -25

echo
echo "== C. 在 OS 窗内扫 NXSB（前 256 MiB，只读） =="
python3 - <<'PY' 2>&1
import json
from pathlib import Path
MEDIA=Path("/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/userdata")
d=json.loads((MEDIA/"userdata-root.json").read_text())
img=Path(d["image"])
for w in d["windows"]:
    print(f'-- {w["name"]} offset={w["offset"]} size={w["size"]} --')
    hits=[]; pat=b"NXSB"
    with img.open("rb") as f:
        pos=w["offset"]; end=min(w["offset"]+ (256<<20), w["offset"]+w["size"])
        carry=0
        while pos<end:
            f.seek(pos); chunk=f.read(min(8<<20, end-pos))
            if not chunk: break
            i=chunk.find(pat)
            while i>=0:
                ab=pos+i
                hits.append(ab)
                i=chunk.find(pat,i+1)
            pos+=len(chunk)-len(pat)+1
    print("   绝对命中:",[hex(x) for x in hits[:8]],"窗内相对:",[hex(x-w["offset"]) for x in hits[:8]],f"共 {len(hits)}")
PY

echo
echo "== D. 容器起点候选处的头 512 字节（对照 APFS 超级块字段） =="
python3 - <<'PY' 2>&1
import json
from pathlib import Path
MEDIA=Path("/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/userdata")
d=json.loads((MEDIA/"userdata-root.json").read_text())
img=Path(d["image"]); w=[x for x in d["windows"] if x["name"]=="OS"][0]
with img.open("rb") as f:
    for base in (w["offset"], w["offset"]+1024, w["offset"]+0x4000, w["offset"]+0x10000):
        f.seek(base); b=f.read(64)
        print(f"  abs@{hex(base)} rel@{hex(base-w['offset'])}: {b.hex()}")
PY

echo
echo "== E. 找到 NXSB 后，逐个候选容器起点开 loop，直到 libfsapfs 认 =="
python3 - <<'PY' 2>&1
import json, subprocess, time, uuid as U
from pathlib import Path
MEDIA=Path("/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/userdata")
d=json.loads((MEDIA/"userdata-root.json").read_text())
img=Path(d["image"]); w=[x for x in d["windows"] if x["name"]=="OS"][0]
TARGET="04769D26-2CA0-4825-B443-E2E5F88300F2"

def find_sb(win):
    pat=b"NXSB"; out=[]
    with img.open("rb") as f:
        pos=win["offset"]; end=win["offset"]+win["size"]
        while pos<end and len(out)<4:
            f.seek(pos); chunk=f.read(min(64<<20, end-pos))
            if not chunk: break
            i=chunk.find(pat)
            while i>=0:
                out.append(pos+i); i=chunk.find(pat,i+1)
                if len(out)>=4: break
            pos+=len(chunk)-len(pat)+1
    return out
sb=find_sb(w)
print("  OS 窗内 NXSB 绝对偏移:",[hex(x) for x in sb],"窗内相对:",[hex(x-w["offset"]) for x in sb])
if not sb:
    print("  整窗没找到 NXSB"); raise SystemExit

def hu(b):
    b=bytes(b)
    return "%02X%02X%02X%02X-%02X%02X-%02X%02X-%s-%s" % (b[3],b[2],b[1],b[0],b[5],b[4],b[7],b[6],
            b[8:10].hex().upper(),b[10:16].hex().upper())

import pyfsapfs
for back in (1024, 4096, 0, 0x4000, 0x10000, 1<<20):
    rel=sb[0]-w["offset"]-back
    if rel<0: 
        print(f"  候选 -{hex(back)}: 相对偏移为负，跳过"); continue
    abs_off=w["offset"]+rel; lim=w["size"]-rel
    r=subprocess.run(["sudo","-n","losetup","-r","--offset",str(abs_off),
                      "--sizelimit",str(lim),"-f","--show",str(img)],capture_output=True,text=True)
    lo=r.stdout.strip()
    if not lo.startswith("/dev/loop"):
        print(f"  候选 rel={hex(rel)} losetup 失败: {r.stdout}{r.stderr}".strip()); continue
    try:
        c=pyfsapfs.container()
        try:
            c.open(lo)
        except Exception as e:
            print(f"  候选 rel={hex(rel)} (容器起点=SB-{hex(back)}): 打不开 -> {type(e).__name__}")
            continue
        print(f"  候选 rel={hex(rel)} (容器起点=SB-{hex(back)}): 成功 容器UUID={hu(c.uuid)} 卷数={c.number_of_volumes}")
        print("    volume 方法:",[m for m in dir(c.get_volume(0)) if not m.startswith('_')])
        for i in range(c.number_of_volumes):
            v=c.get_volume(i)
            extra=" ".join(f"{a}={getattr(v,a)}" for a in ("flags","is_read_only","number_of_snapshots") if hasattr(v,a))
            print(f"    [{i}] name={v.name!r} uuid={hu(v.uuid)} {extra}")
        print("    目标 UUID 命中:" , TARGET, "→", any(hu(c.get_volume(i).uuid)==TARGET for i in range(c.number_of_volumes)))
        c.close()
        subprocess.run(["sudo","-n","losetup","-d",lo])
        print(f"  -- 采用 rel={hex(rel)} abs={abs_off} --")
        Path("/tmp/apfs-container-rel").write_text(f"{rel} {abs_off} {lim}\n")
        break
    finally:
        pass
PY
LO3=$(awk '{print $2}' /tmp/apfs-container-rel 2>/dev/null)
if [ -n "${LO3:-}" ]; then
  L3=$(sudo -n losetup -r --offset "$LO3" --sizelimit $(awk '{print $3}' /tmp/apfs-container-rel) -f --show "$IMG")
  echo "  fsapfsinfo -p 0 on $L3"
  fsapfsinfo -p 0 "$L3" 2>&1 | head -60
  sudo -n losetup -d "$L3" 2>/dev/null
fi

echo
echo "== F. run_umi_qemu.py 里 root UUID 的出处 =="
grep -n "04769D26\|root_match_volume_uuid\|root-match-volume-uuid\|systemos" $PIN/tools/run_umi_qemu.py 2>&1 | head -30
echo "  -- 本仓脚本里谁传过这个 UUID --"
grep -rn "04769D26" /mnt/e/Code/HackIos/tools-wsl/*.sh /mnt/e/Code/HackIos/tools-wsl/*.py 2>/dev/null | head -10
echo "  -- 上游文档/记录里这个 UUID 从哪来 --"
grep -rn "04769D26" /home/unixnu/code/UniXNU-main 2>/dev/null | head -10
echo done
