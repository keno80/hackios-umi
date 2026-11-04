#!/bin/bash
# U 步之三取证：OS 窗是带 GPT 的整块虚拟盘（rel@0x200 = 'EFI PART'），
# 所以要按 GPT 找 APFS 分区起点，再在那个起点上开 libfsapfs 视图读卷 UUID。
# SystemOS 窗没 GPT（NXSB 直接在 rel@0x20），单独试。
exec > /mnt/e/Code/HackIos/out/probes/u100-gpt-and-volume-uuid.txt 2>&1
set -u
PIN=/home/unixnu/code/umi-work-pin
MEDIA=$PIN/out/umi-xnu/umi/userdata
IMG=$MEDIA/userdata-root.img

python3 - <<'PY' 2>&1
import json, struct, subprocess, uuid as UM
from pathlib import Path
MEDIA=Path("/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/userdata")
d=json.loads((MEDIA/"userdata-root.json").read_text())
img=Path(d["image"])
TARGET="04769D26-2CA0-4825-B443-E2E5F88300F2"
APFS_SB_OFF=0x420

def mixed(b):
    b=bytes(b)
    return "%02X%02X%02X%02X-%02X%02X-%02X%02X-%s-%s" % (b[3],b[2],b[1],b[0],b[5],b[4],b[7],b[6],
            b[8:10].hex().upper(),b[10:16].hex().upper())

def gpt(f, base):
    f.seek(base+0x200); head=f.read(96)
    if head[:8]!=b"EFI PART":
        print("   没有 GPT 头"); return []
    entry_lba, = struct.unpack_from("<Q", head, 0x48)
    count, = struct.unpack_from("<I", head, 0x50)
    esize, = struct.unpack_from("<I", head, 0x54)
    print(f"   GPT: entry_lba={entry_lba} count={count} esize={esize}")
    out=[]
    f.seek(base+entry_lba*512)
    table=f.read(count*esize)
    for i in range(count):
        e=table[i*esize:(i+1)*esize]
        if not e or e[:16]==b"\0"*16: continue
        typ=mixed(e[0:16]); own=mixed(e[16:32])
        first_lba,last_lba=struct.unpack_from("<QQ", e, 32)
        name=e[56:128].decode("utf-16-le").split("\0")[0]
        if first_lba==0 and last_lba==0: continue
        out.append(dict(name=name, type=typ, own=own, start=first_lba*512,
                        bytes=(last_lba-first_lba+1)*512))
        print(f"   [{i}] {name!r} type={typ} start={hex(first_lba*512)} bytes={out[-1]['bytes']}")
    return out

def try_open(rel, size, label):
    off=rel
    r=subprocess.run(["sudo","-n","losetup","-r","--offset",str(off),
                      "--sizelimit",str(size),"-f","--show",str(img)],
                     capture_output=True,text=True,timeout=120)
    lo=r.stdout.strip()
    if not lo.startswith("/dev/loop"):
        print(f"   {label}: losetup 失败 {r.stderr.strip()}"); return False
    code=f'''
import pyfsapfs,sys
c=pyfsapfs.container()
c.open({lo!r})
print("V", c.number_of_volumes)
for i in range(c.number_of_volumes):
    v=c.get_volume(i)
    print("N", v.name, "U", v.uuid.hex())
'''
    p=subprocess.run(["timeout","120","python3","-c",code],capture_output=True,text=True,timeout=180)
    if p.returncode!=0:
        first=(p.stderr.strip().splitlines() or [""])[-1]
        print(f"   {label}: 打不开 rc={p.returncode} {first[:180]}")
        subprocess.run(["sudo","-n","losetup","-d",lo],capture_output=True); return False
    print(f"   {label}: 开了")
    c=pyfsapfs.container(); c.open(lo)
    print(f"     容器 UUID={mixed(c.uuid)}")
    print(f"     container 方法={[m for m in dir(c) if not m.startswith('_')]}")
    v0=c.get_volume(0)
    print(f"     volume 方法={[m for m in dir(v0) if not m.startswith('_')]}")
    hit=False
    for i in range(c.number_of_volumes):
        v=c.get_volume(i)
        u=mixed(v.uuid)
        attrs=" ".join(f"{a}={getattr(v,a)}" for a in ("flags","is_read_only","number_of_snapshots","size") if hasattr(v,a))
        print(f"     [{i}] name={v.name!r} uuid={u} {attrs}")
        if u==TARGET: hit=True
    print(f"     目标 {TARGET} 命中={hit}")
    if hasattr(v0,"snapshot_set"):
        try:
            ss=v0.get_snapshot_set(); print("     快照数:",ss.number_of_snapshots)
        except Exception as e: print("     快照集:",e)
    c.close()
    subprocess.run(["sudo","-n","losetup","-d",lo],capture_output=True)
    return True

for w in d["windows"]:
    print(f'== {w["name"]} offset={hex(w["offset"])} size={w["size"]} ==')
    with img.open("rb") as f:
        parts=gpt(f, w["offset"])
    done=False
    for p in parts:
        start=w["offset"]+p["start"]
        size=min(p["bytes"], w["offset"]+w["size"]-start)
        print(f'  -- 试分区 {p["name"]!r} abs={hex(start)} --')
        done=try_open(start, size, f'分区起点(超级块在 +{hex(APFS_SB_OFF)})')
        if done: break
    if not done:
        # 没 GPT 或分区打不开：按 NXSB 命中位置反推容器起点
        with img.open("rb") as f:
            f.seek(w["offset"]); data=f.read(4<<20)
        i=data.find(b"NXSB")
        print(f'  NXSB 首个命中 rel={hex(i)}')
        for cand in (i-APFS_SB_OFF, i, max(0,i-0x400)):
            if cand<0: continue
            print(f'  -- 试容器起点 rel={hex(cand)} --')
            if try_open(w["offset"]+cand, w["size"]-cand, f"rel{hex(cand)}"): break
PY
sudo -n losetup -D 2>/dev/null
echo done
