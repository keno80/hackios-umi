#!/usr/bin/env python3
"""在 Linux 上实测 APFS 卷身份，产 out/umi-xnu/umi/userdata/{OS,SystemOS}-volume-info.json。

官方 prepare_umi_root_policy.py 读这两个文件拿「根卷的 UUID」，上游那两份是 Mac
`diskutil info -plist` 的产物（本仓此前根本没有）。这里不改上游脚本的判断，只用 Linux
侧的真读把同样的事实填进去：

  GPT 分区起点     OS 窗 rel@0x200 有 'EFI PART'，分区表里唯一一块 7C3457EF-…-AA11-00306543ECAC
                   （Apple APFS 容器），起点 rel 0x4400；SystemOS 窗没 GPT，容器直接压在 rel 0。
                   （以上为 out/probes/u100、u102 的实测）
  FilesystemType   libfsapfs 在该起点开出容器才算 apfs——它读的是磁盘上的 NXSB 超级块。
  VolumeUUID       pyfsapfs volume.identifier。OS 卷实测 04769d26-2ca0-4825-b443-e2e5f88300f2，
                   与 tools/run_umi_qemu.py 的 --root-match-volume-uuid 逐字相同。
  Writable=False   主机侧只读挂接：losetup -r。上游 build-owner-os-policy.py 里对应的也是
                   主机的 read-only attachment（host_media_writable=False），不是卷上的位。
                   userdata-root.json 自己记的 read_only_attachment=true 是同一条事实的第三处印证。

VolumeSizeBytes 这一档在 libfsapfs 这版绑定里取不到（getattr(v,'size') 直接 raise
pyfsapfs_volume_get_size: failed to retrieve size，u104 实测），如实留 None。官方 preparer
只读 FilesystemType/VolumeUUID/Writable 三个键，不影响策略件。

产物的每一条字段都带 measurement 出处，免得日后被读成 Mac 上的证据。
"""
import argparse
import json
import struct
import subprocess
import sys
import uuid as UM
from pathlib import Path

APFS_GPT_TYPES = {"7c3457ef-0000-11aa-aa11-00306543ecac",       # Apple APFS 容器
                  "5c3457ef-0000-11aa-aa11-00306543ecac",
                  "7d63d5a0-9649-11e2-a123-99eb99999999"}
NXSB = b"NXSB"


def guid(raw):
    """GPT/APFS 盘上 UUID 是 mixed-endian（4LE,2LE,2LE,8BE）。"""
    b = bytes(raw)
    return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%s-%s" % (
        b[3], b[2], b[1], b[0], b[5], b[4], b[7], b[6],
        b[8:10].hex(), b[10:16].hex())


def gpt_parts(stream, base):
    """返回 (分区列表, 是否有 GPT 头)。分区起点按相对 base 的字节偏移给。"""
    stream.seek(base + 0x200)
    if stream.read(8) != b"EFI PART":
        return [], False
    stream.seek(base + 0x200)
    head = stream.read(96)
    entry_lba, = struct.unpack_from("<Q", head, 0x48)
    count, = struct.unpack_from("<I", head, 0x50)
    esize, = struct.unpack_from("<I", head, 0x54)
    stream.seek(base + entry_lba * 512)
    table = stream.read(count * esize)
    parts = []
    for i in range(count):
        e = table[i * esize:(i + 1) * esize]
        if len(e) < 128 or e[:16] == b"\0" * 16:
            continue
        first_lba, last_lba = struct.unpack_from("<QQ", e, 32)
        if not first_lba and not last_lba:
            continue
        parts.append(dict(index=i, type=guid(e[0:16]), own=guid(e[16:32]),
                          start=first_lba * 512, bytes=(last_lba - first_lba + 1) * 512,
                          name=e[56:128].decode("utf-16-le").split("\0")[0]))
    return parts, True


def candidate_offsets(stream, window):
    """容器起点候选：GPT 的 APFS 分区 → 窗首 → NXSB 反推。"""
    base, size = window["offset"], window["size"]
    parts, has_gpt = gpt_parts(stream, base)
    cands, why = [], {}
    for p in parts:
        if p["type"].lower() in APFS_GPT_TYPES:
            cands.append(p["start"])
            why[p["start"]] = {"kind": "gpt-partition", "partition": p, "has_gpt": has_gpt}
    cands.append(0)
    why.setdefault(0, {"kind": "window-start", "partition": None, "has_gpt": has_gpt})
    stream.seek(base)
    head = stream.read(min(4 << 20, size))
    hit = head.find(NXSB)
    if hit >= 0:
        for back in (0x20, 0x420, 0x400):
            cands.append(hit - back)
            why.setdefault(hit - back, {"kind": "nxsb-scan", "nxsb_rel": hit,
                                        "partition": None, "has_gpt": has_gpt})
    ordered, seen = [], set()
    for c in cands:
        if c >= 0 and c not in seen:
            seen.add(c)
            ordered.append(c)
    return ordered, why, parts


def read_attr(obj, name):
    """libyal 绑定里属性访问本身就 raise（u104：getattr(v,'size') 直接 OSError:
    pyfsapfs_volume_get_size: failed to retrieve size），所以取属性和调用都要兜。
    取不到就回 None——官方 preparer 只看 FilesystemType/VolumeUUID/Writable，卷大小是额外取证。
    """
    for getter in (f"get_{name}", name):
        try:
            fn = getattr(obj, getter, None)
            if fn is None:
                continue
            return fn() if callable(fn) else fn
        except Exception:
            continue
    return None


def losetup(image, offset, length):
    r = subprocess.run(["sudo", "-n", "losetup", "-r", "--offset", str(offset),
                        "--sizelimit", str(length), "-f", "--show", str(image)],
                       capture_output=True, text=True, timeout=180)
    node = r.stdout.strip()
    if not node.startswith("/dev/loop"):
        raise RuntimeError(f"losetup 失败：{r.stdout}{r.stderr}")
    return node


def losetup_release(node):
    subprocess.run(["sudo", "-n", "losetup", "-d", node], capture_output=True)


def measure(container, image, window, stream):
    """在这个窗里开出 APFS 容器，读出卷身份。"""
    cands, why, parts = candidate_offsets(stream, window)
    for rel in cands:
        if rel >= window["size"]:
            continue
        offset = window["offset"] + rel
        node = losetup(image, offset, window["size"] - rel)
        try:
            view = container()
            view.open(node)
        except Exception:
            losetup_release(node)
            continue
        try:
            volumes = []
            for i in range(view.number_of_volumes):
                v = view.get_volume(i)
                ident = str(read_attr(v, "identifier") or "").lower()
                volumes.append(dict(
                    FilesystemType="apfs",
                    VolumeUUID=ident.upper(),
                    Writable=False,
                    VolumeName=read_attr(v, "name"),
                    VolumeSizeBytes=read_attr(v, "size"),
                    VolumeLocked=read_attr(v, "is_locked"),
                    MeasuredUUIDCanonical=ident,
                ))
            return dict(
                container_identifier=str(read_attr(view, "identifier") or "").lower(),
                container_number_of_volumes=view.number_of_volumes,
                volumes=volumes,
                container_relative_offset=rel,
                absolute_offset=offset,
                located_by=why.get(rel, {"kind": "?"}),
                host_attachment="losetup -r (read-only)",
                partitions=parts,
            )
        finally:
            view.close()
            losetup_release(node)
    raise SystemExit(f"这个窗里开不出 APFS 容器：{window['name']}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--userdata-json", type=Path, required=True)
    ap.add_argument("--dry-run", action="store_true", help="只打印，不写文件")
    args = ap.parse_args()
    import pyfsapfs
    media = args.userdata_json.parent
    d = json.loads(args.userdata_json.read_text())
    image = Path(d["image"])
    for window in d["windows"]:
        with image.open("rb") as stream:
            got = measure(pyfsapfs.container, image, window, stream)
        volumes = got["volumes"]
        assert len(volumes) == 1, (window["name"], volumes)
        entry = dict(volumes[0])
        entry.update(
            MediaSizeBytes=window["size"],
            MediaSHA256=window["sha256"],
            PartitionCapacity=d.get("partition_capacity"),
            ReadOnlyAttachment=True,
            MeasuredBy="make-volume-infos-linux.py + libfsapfs (Linux)",
            ContainerIdentifier=got["container_identifier"],
            ContainerNumberOfVolumes=got["container_number_of_volumes"],
            ContainerRelativeOffset=got["container_relative_offset"],
            AbsoluteOffset=got["absolute_offset"],
            LocatedBy=got["located_by"],
            HostAttachment=got["host_attachment"],
            GptPartitions=got["partitions"],
            UpstreamFieldSource="Mac diskutil info -plist",
        )
        # 官方 preparer 要的是「一个列表，里面逐条看 FilesystemType/VolumeUUID/Writable」
        payload = [entry]
        target = media / (window["name"] + "-volume-info.json")
        if args.dry_run:
            print(json.dumps(payload, indent=2, ensure_ascii=False))
        else:
            target.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
        UM.UUID(entry["VolumeUUID"])
        print(f'{window["name"]}: {entry["VolumeName"]} '
              f'uuid={entry["VolumeUUID"]} 容器@rel{hex(entry["ContainerRelativeOffset"])} '
              f'-> {target.name}', flush=True)


if __name__ == "__main__":
    main()
