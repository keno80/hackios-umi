#!/usr/bin/env python3
"""Build and independently verify the official owner-integrity policies for umi（Linux 版备料）.

这是上游 tools/prepare_umi_root_policy.py 的逐行拷贝，只动两处本机假设，验证逻辑一条没删：

1. host 自检不再叫 kits/VerifiedRoot/tests/check.py（那件写死 macOS：`xcrun clang -dynamiclib`
   + `/opt/homebrew/opt/openssl@3`）。改调本仓的 verified-root-host-check-linux.py：
   宿主件用系统 cc -shared -fPIC 真编（真 OpenSSL 3.0.13 做 RSA3072-SHA256 验签），
   断言集合与上游一致，产物布局与上游一致（keys/、verified-root.dylib、checks.json、signed/）。
2. `*-volume-info.json` 上游来自 Mac `diskutil info -plist`。本仓由 make-volume-infos-linux.py
   用 libfsapfs 在 losetup 只读视图上实测出来，字段名对齐（FilesystemType/VolumeUUID/Writable）。
   这两条 assert 原样留着，正好当作对本机实测件的独立复核。

额外只做一件事：把「哪些是 Linux 实测、哪些是上游原样」记进 verification.json / policies.json，
免得日后被读成 Mac 上的证据。装机与挂载状态照旧是 False——这一步只出策略件，不碰手机。
"""
import ctypes
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import uuid

ROOT=Path(__file__).resolve().parents[1]
UP=ROOT/"sources/UniXNU/kits/VerifiedRoot"
OUT=ROOT/"out/umi/root-policy"
MEDIA=ROOT/"out/umi-xnu/umi/userdata"
HOST_CHECK=Path(__file__).resolve().parent/"verified-root-host-check-linux.py"
VOLUME_INFOS=Path(__file__).resolve().parent/"make-volume-infos-linux.py"
LINUX_SUBSTITUTIONS=[
    "host 共享件由 xcrun clang -dynamiclib（Mach-O）改为系统 cc -shared -fPIC（ELF），文件名沿用 verified-root.dylib",
    "openssl 前缀由 /opt/homebrew/opt/openssl@3 改为系统 /usr + /usr/lib/x86_64-linux-gnu",
    "*-volume-info.json 由 Mac diskutil info -plist 改为 libfsapfs 在 losetup 只读视图上实测",
]

class Window:
    def __init__(self,path,offset,length):
        self.stream=path.open("rb")
        self.stream.seek(offset)
        self.left=length
    def read(self,count):
        data=self.stream.read(min(count,self.left))
        self.left-=len(data)
        return data
    def close(self): self.stream.close()

class View(ctypes.Structure):
    _fields_=[("hashes",ctypes.c_void_p),("image_bytes",ctypes.c_uint64),
              ("block_count",ctypes.c_uint64),("generation",ctypes.c_uint64),
              ("volume_uuid",ctypes.c_uint8*16),("image_sha256",ctypes.c_uint8*32)]

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    host=OUT/"host"
    with (OUT/"host-tests.log").open("w") as log:
        subprocess.run([sys.executable,str(HOST_CHECK),"--output",str(host),"--kit",str(UP),
                        "--openssl-prefix","/usr"], check=True,stdout=log,stderr=subprocess.STDOUT)
    spec=importlib.util.spec_from_file_location("manifest",UP/"tools/manifest.py")
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    native=ctypes.CDLL(str(host/"verified-root.dylib"))
    native.vr_host_open.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p,
                                ctypes.c_uint64,ctypes.POINTER(View)]
    native.vr_host_block.argtypes=[ctypes.POINTER(View),ctypes.c_uint64,
                                 ctypes.c_void_p,ctypes.c_size_t]
    media=json.loads((MEDIA/"userdata-root.json").read_text())
    reports=[]
    for w in media["windows"]:
        infos=json.loads((MEDIA/(w["name"]+"-volume-info.json")).read_text())
        volumes=[d for d in infos if d.get("FilesystemType")=="apfs" and d.get("VolumeUUID")]
        assert len(volumes)==1 and volumes[0]["Writable"] is False
        identity=uuid.UUID(volumes[0]["VolumeUUID"])
        out=OUT/w["name"];out.mkdir(exist_ok=True)
        stream=Window(Path(media["image"]),w["offset"],w["size"])
        print(f"{w['name']}: 生成 manifest（读 {w['size']/2**30:.2f} GiB，上游 manifest.py 内部无进度）",flush=True)
        try:
            record=module.make(stream,w["size"],host/"keys/owner.pem",
                host/"keys/owner-public.pem",identity,1,out)
        finally:stream.close()
        assert record["image_sha256"]==w["sha256"]
        encoded=ctypes.create_string_buffer((out/"manifest.bin").read_bytes())
        key=ctypes.create_string_buffer((out/"trusted-key.bin").read_bytes())
        view=View()
        assert native.vr_host_open(encoded,len(encoded)-1,key,1,ctypes.byref(view))==0
        assert bytes(view.volume_uuid)==identity.bytes and view.image_bytes==w["size"]
        stream=Window(Path(media["image"]),w["offset"],w["size"])
        complete=hashlib.sha256()
        print(f"{w['name']}: 逐块真验签开始（{view.block_count} 块 × 4 KiB）",flush=True)
        try:
            for index in range(view.block_count):
                block=stream.read(4096)
                assert native.vr_host_block(ctypes.byref(view),index,block,len(block))==0,index
                complete.update(block)
                if index % 65536 == 0:
                    print(f"  {w['name']} {index}/{view.block_count} 块 "
                          f"({100*index/view.block_count:.1f}%)", flush=True)
            assert not stream.read(1)
        finally:stream.close()
        assert complete.hexdigest()==w["sha256"] and complete.digest()==bytes(view.image_sha256)
        facts=json.loads((MEDIA/(w["name"]+"-volume-info.json")).read_text())
        provenance=[d for d in facts if d.get("FilesystemType")=="apfs" and d.get("VolumeUUID")][0]
        result={**record,"name":w["name"],"blocks_verified":view.block_count,
                "real_c_signature_and_block_verification":True,
                "root_image_offset":w["offset"],
                "manifest_sha256":hashlib.sha256((out/"manifest.bin").read_bytes()).hexdigest(),
                "volume_identity_measured_on_linux":provenance,
                "host_check":HOST_CHECK.name,
                "hardware_tested":False,"root_mounted":False}
        (out/"verification.json").write_text(json.dumps(result,indent=2)+"\n")
        reports.append(result)
        print(f"{w['name']}: RSA envelope and {view.block_count} real 4 KiB blocks verified",flush=True)
    assert (OUT/"OS/trusted-key.bin").read_bytes()==(OUT/"SystemOS/trusted-key.bin").read_bytes()
    result={"status":"host_verified_owner_integrity_policies","windows":reports,
        "source_sha256":{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (UP/"tools/manifest.py",UP/"src/verified_root.c",UP/"tests/openssl_provider.c",Path(__file__))},
        "linux_substitutions":LINUX_SUBSTITUTIONS,
        "linux_substitution_sha256":{p.name:hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (HOST_CHECK,VOLUME_INFOS) if p.exists()},
        "manifest_bytes":sum((OUT/w["name"]/"manifest.bin").stat().st_size for w in media["windows"]),
        "apple_signature_claim":False,"hardware_tested":False,"root_mounted":False}
    (OUT/"policies.json").write_text(json.dumps(result,indent=2)+"\n")

if __name__=="__main__": main()
