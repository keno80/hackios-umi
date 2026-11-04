#!/bin/bash
# U 步之三取证（紧凑版）：APFS 容器超级块在窗内的真实位置，以及卷 UUID。
# 上一版（u95）在 C 段做了无谓的全窗 find，空转 4 分钟，已杀。这版只读候选偏移，每步 timeout 卡死。
exec > /mnt/e/Code/HackIos/out/probes/u98-apfs-sb-and-uuid.txt 2>&1
set -u
PIN=/home/unixnu/code/umi-work-pin
MEDIA=$PIN/out/umi-xnu/umi/userdata
IMG=$MEDIA/userdata-root.img

echo "== A. 窗首若干候选偏移上的 8 字节（找 NXSB / VSX / 保留区） =="
python3 - <<'PY' 2>&1
import json
from pathlib import Path
MEDIA=Path("/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/userdata")
d=json.loads((MEDIA/"userdata-root.json").read_text())
img=Path(d["image"])
cands=[0,0x200,0x400,0x800,0x1000,0x4000,0x10000,0x120,0x200000]
with img.open("rb") as f:
    for w in d["windows"]:
        print(f'-- {w["name"]} offset={hex(w["offset"])} size={w["size"]} --')
        for c in cands:
            f.seek(w["offset"]+c); b=f.read(16)
            mark=""
            if b[:4]==b"NXSB": mark="  <== NXSB 容器超级块"
            elif b[:4]==b"koly": mark="  <== koly UDIF 尾"
            print(f'   rel@{hex(c):>8} abs@{hex(w["offset"]+c)}: {b.hex()} {b[:8]!r}{mark}')
PY

echo
echo "== B. 前 4 MiB 内扫 NXSB（有界，最多 4 个命中） =="
python3 - <<'PY' 2>&1
import json
from pathlib import Path
MEDIA=Path("/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/userdata")
d=json.loads((MEDIA/"userdata-root.json").read_text())
img=Path(d["image"])
pat=b"NXSB"
with img.open("rb") as f:
    for w in d["windows"]:
        span=min(4<<20, w["size"])
        f.seek(w["offset"]); data=f.read(span)
        hits=[]; i=data.find(pat)
        while i>=0 and len(hits)<8:
            hits.append(i); i=data.find(pat,i+1)
        print(f'  {w["name"]}: 前 {span>>20} MiB 命中 rel={[hex(x) for x in hits]}')
        print(f'    总命中数（该 4 MiB 内）={data.count(pat)}')
PY

echo
echo "== C. fsapfsinfo -o 直接在整像上试候选容器偏移 =="
python3 - <<'PY' > /tmp/win.env 2>&1
import json
from pathlib import Path
MEDIA=Path("/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/userdata")
d=json.loads((MEDIA/"userdata-root.json").read_text())
for w in d["windows"]:
    print(f'{w["name"]}_OFF={w["offset"]}')
PY
cat /tmp/win.env
. /tmp/win.env
for base in $OS_OFF; do
  for back in 0 1024 4096 0x10000; do
    off=$((base + back))
    echo "  -- fsapfsinfo -o $off --"
    timeout 90 fsapfsinfo -o $off "$IMG" 2>&1 | head -12
  done
done

echo
echo "== D. losetup 只读视图 + pyfsapfs（逐个候选，单次 60s 超时） =="
python3 - <<'PY' 2>&1
import json, subprocess
from pathlib import Path
MEDIA=Path("/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/userdata")
d=json.loads((MEDIA/"userdata-root.json").read_text())
img=Path(d["image"]); w=[x for x in d["windows"] if x["name"]=="OS"][0]
TARGET="04769D26-2CA0-4825-B443-E2E5F88300F2"
import pyfsapfs
def hu(b):
    b=bytes(b)
    return "%02X%02X%02X%02X-%02X%02X-%02X%02X-%s-%s" % (b[3],b[2],b[1],b[0],b[5],b[4],b[7],b[6],
            b[8:10].hex().upper(),b[10:16].hex().upper())
for back in (1024, 0, 4096, 0x10000):
    off=w["offset"]+back
    r=subprocess.run(["sudo","-n","losetup","-r","--offset",str(off),
                      "--sizelimit",str(w["size"]-back),"-f","--show",str(img)],
                     capture_output=True,text=True,timeout=60)
    lo=r.stdout.strip()
    if not lo.startswith("/dev/loop"):
        print(f"  rel+{hex(back)}: losetup 失败 {r.stderr.strip()}"); continue
    try:
        c=pyfsapfs.container()
        rc=subprocess.run(["timeout","60","python3","-c",f'''
import pyfsapfs,sys
c=pyfsapfs.container(); c.open({lo!r})
print("  OK 卷数",c.number_of_volumes)
'''],capture_output=True,text=True,timeout=90)
        print(f"  rel+{hex(back)} ({lo}): rc={rc.returncode} {rc.stdout.strip()} {rc.stderr.strip()[:200]}")
        if rc.returncode==0:
            c=pyfsapfs.container(); c.open(lo)
            print("   容器 UUID:",hu(c.uuid))
            print("   volume 方法:",[m for m in dir(c.get_volume(0)) if not m.startswith("_")])
            for i in range(c.number_of_volumes):
                v=c.get_volume(i)
                print(f"   [{i}] name={v.name!r} uuid={hu(v.uuid)} 目标命中={hu(v.uuid)==TARGET}")
            Path("/tmp/good-rel").write_text(str(back)+"\n")
            break
    except Exception as e:
        print(f"  rel+{hex(back)}: 异常 {type(e).__name__} {e}")
    finally:
        subprocess.run(["sudo","-n","losetup","-d",lo],capture_output=True)
PY

echo
echo "== E. 目标 UUID 在整窗里的字节位置（大端 16 字节，扫前 8 MiB） =="
python3 - <<'PY' 2>&1
import json, uuid
from pathlib import Path
MEDIA=Path("/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/userdata")
d=json.loads((MEDIA/"userdata-root.json").read_text())
img=Path(d["image"])
t="04769D26-2CA0-4825-B443-E2E5F88300F2"
raw=uuid.UUID(t).bytes
for w in d["windows"]:
    with img.open("rb") as f:
        f.seek(w["offset"]); data=f.read(min(8<<20,w["size"]))
    hits=[]; i=data.find(raw)
    while i>=0 and len(hits)<5:
        hits.append(i); i=data.find(raw,i+1)
    print(f'  {w["name"]}: big-endian 命中 rel={[hex(x) for x in hits]} 该 8 MiB 内共 {data.count(raw)} 处')
PY
echo done
