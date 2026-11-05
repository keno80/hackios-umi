#!/usr/bin/env python3
"""判读一次 QEMU 取证里的 IOKit 注册表字符串发布面，用来归因 Data 种子按卷 UUID 查不到媒体。

观测通道是上游自己的：gdb-stop.py 在 IORegistryEntry::setProperty(char const*, char const*)
上挂 logpoint，每条事件记 {entry(=x0，那个注册表对象), caller(=x30，调用方址), key, value}。
上游判读同源：check-native-virtio-checkpoints.py:89-96 先按 value 找 UUID 事件，再按 entry 归组
读同一对象的 Status/BSD Name/Content，并用 caller 落在 apfs 的 __TEXT_EXEC 里证明是未改动的
原版 APFS 发的；check-original-apfs-root-checkpoints.py:51-54 用的是同一套。

本件不新增断言、不改判据，只把「我们那颗 Linux 造的 RAM 种子有没有被原版 APFS 发布成一条带
UUID 的 IOMedia」这条问题回答清楚，并把 native_ram_block_volume_seed() 里四个提前返回的分支
（0 条匹配 / 多于 1 条 / 属性不齐（BSD Name、major/minor）/ 提供者链够不到 NativeRamBlock）
按证据分档指认。

caller 归属用的是 **prelink JSON 的 extents**（module/segment/va/size 共 68 项）而不是 nm：
本档是 prelinked，原版驱动（apfs、IOStorageFamily、AMFI…）作为 donor 组件被搬进内核虚拟跨度里
低于源内核符号最低址的那段，nm 里一个都没有——48 档实测三个 caller 全落在
com.apple.filesystems.apfs / com.apple.iokit.IOStorageFamily 的 __TEXT_EXEC 里，而 nm 判不出。
nm 只作为兜底（源内核自己的符号址）。

用法：evaluate-data-registry-evidence.py <RUN目录> [内核.macho] [source-build.json]
"""
import bisect
import json
import subprocess
import sys
from pathlib import Path

WS = Path("/home/unixnu/code/umi-work-pin")
MEDIA_KEYS = ("UUID", "BSD Name", "Content", "Content Hint", "Status", "Sealed", "Media name",
              "Volume Name", "FullName", "TierType", "VolGroupUUID", "FormattedBy",
              "IOProviderClass", "Model", "Vendor", "device-type", "Media size")


def run_path(value):
    path = Path(value)
    return path if path.is_absolute() else WS / path


def extents(prelink_json):
    """prelink 的模块段表：按 va 排序，caller 落在哪个模块的哪个段一目了然。"""
    items = json.loads(prelink_json.read_text())["extents"]
    items.sort(key=lambda e: e["va"])
    return [e["va"] for e in items], items


def text_symbols(kernel):
    """nm -n 的符号按址排序，只在 extents 覆盖不到时兜底（源内核符号段）。"""
    out = subprocess.run(["xcrun", "nm", "-n", str(kernel)], capture_output=True, text=True).stdout
    addrs, names = [], []
    for line in out.splitlines():
        fields = line.split()
        if len(fields) != 3:
            continue
        address, kind, name = int(fields[0], 16), fields[1], fields[2]
        if kind in ("T", "t", "S", "s", "D", "d"):
            addrs.append(address)
            names.append(name)
    order = sorted(range(len(addrs)), key=lambda i: addrs[i])
    return [addrs[i] for i in order], demangle([names[i] for i in order])


def demangle(names):
    try:
        out = subprocess.run(["c++filt"], input="\n".join(names), capture_output=True, text=True).stdout
    except OSError:
        return names
    lines = out.splitlines()
    return lines if len(lines) == len(names) else names


def describe_caller(address, spans, items, addrs, names):
    index = bisect.bisect_right(spans, address) - 1
    if index >= 0 and address < items[index]["va"] + items[index]["size"]:
        item = items[index]
        return f"{address:#x} = {item['module']} 的 {item['segment']}" \
               f"（+0x{address - item['va']:x}，未改动的原版件）"
    if addrs:
        j = bisect.bisect_right(addrs, address) - 1
        if j >= 0:
            return f"{address:#x} = {names[j]}+0x{address - addrs[j]:x}"
    return f"{address:#x} （既不在 prelink 模块段表里，也没有前驱符号）"


def main():
    run = run_path(sys.argv[1])
    kernel = run_path(sys.argv[2]) if len(sys.argv) > 2 else None
    build = run_path(sys.argv[3]) if len(sys.argv) > 3 else None
    stop_file = run / "gdb-stop.json"
    if not stop_file.exists():
        print(f"停手：缺 {stop_file}")
        return 1

    report = json.loads(stop_file.read_text())
    events = report.get("registry_string_events")
    if events is None:
        print("  这份取证根本没有 registry_string_events 键——跑的时候没带 --log-registry-strings")
        return 1

    wanted = wanted_container = None
    if build and build.exists():
        seed = json.loads(build.read_text()).get("data_ramdisk", {})
        wanted = (seed.get("volume_uuid") or "").upper() or None
        wanted_container = (seed.get("container_uuid") or "").upper() or None

    spans = items = addrs = names = None
    if kernel and kernel.exists():
        prelink_json = kernel.with_suffix(".json")
        if prelink_json.exists():
            spans, items = extents(prelink_json)
        addrs, names = text_symbols(kernel)

    print("== 0. 通道状态 ==")
    print(f"  事件条数 = {len(events)}   上限掐断(exhausted) = {report.get('registry_string_log_exhausted')}")
    print(f"  停在 = {report.get('stop')}  pc = {report.get('pc')}  超时停 = {report.get('bounded_timeout_interrupted')}")
    print(f"  最后一条事件时刻 = {events[-1].get('elapsed_seconds') if events else '—'}s")
    if wanted:
        print(f"  要找的 Data 卷 UUID = {wanted}"
              + (f"   容器 UUID = {wanted_container}" if wanted_container else ""))
    if spans:
        print(f"  模块段表 = {len(items)} 项（来自 {kernel.with_suffix('.json').name}）")
    else:
        print("  没有 prelink 段表，caller 只能按 nm 前驱符号归属（原版驱动会全部落到源内核段之外）")

    grouped = {}
    for event in events:
        grouped.setdefault(event["entry"], {})[event["key"]] = event["value"]

    print(f"\n== 1. 发布过的对象（按 entry 归组，共 {len(grouped)} 个注册表对象；只列带媒体属性的）==")
    shown_count = 0
    for entry, properties in grouped.items():
        shown = {k: v for k, v in properties.items() if k in MEDIA_KEYS}
        if not shown:
            continue
        shown_count += 1
        print(f"  entry={entry}  共 {len(properties)} 个不同属性键")
        for key in MEDIA_KEYS:
            if key in shown:
                print(f"      {key} = {shown[key]}")
    if not shown_count:
        print("  （没有任何对象发布过这组媒体属性）")

    print(f"\n== 2. 所有 UUID 发布（这就是 native_ram_block_volume_seed 要匹配的那一项）==")
    uuid_events = [e for e in events if e["key"] == "UUID"]
    if not uuid_events:
        print("  一条 UUID 属性都没发布出来。")
    for event in uuid_events:
        mark = "  <== 命中目标卷" if wanted and event["value"].upper() == wanted else ""
        owner = (describe_caller(int(event["caller"], 16), spans, items, addrs, names)
                 if spans or addrs else event["caller"])
        print(f"  {event['value']}  entry={event['entry']}  t={event.get('elapsed_seconds')}s")
        print(f"      由 {owner} 发布{mark}")

    print(f"\n== 3. 所有 BSD Name 发布（媒体是否已注册成 /dev 节点，各自属性齐不齐）==")
    for event in [e for e in events if e["key"] == "BSD Name"]:
        props = grouped.get(event["entry"], {})
        picked = {k: props[k] for k in MEDIA_KEYS if k in props}
        print(f"  {event['value']:<10} entry={event['entry']}  t={event.get('elapsed_seconds')}s")
        print(f"      {picked}")

    print(f"\n== 4. 原版 APFS/IOStorageFamily 到底认领了哪几块媒体 ==")
    content_events = [e for e in events if e["key"] == "Content"]
    for event in content_events:
        props = grouped.get(event["entry"], {})
        owner = (describe_caller(int(event["caller"], 16), spans, items, addrs, names)
                 if spans or addrs else event["caller"])
        print(f"  Content={event['value'] or '(空串)'}  BSD Name={props.get('BSD Name', '—')}  "
              f"UUID={props.get('UUID', '—')}  t={event.get('elapsed_seconds')}s")
        print(f"      由 {owner} 发布")

    print(f"\n== 5. 归因分档 ==")
    hits = [e for e in uuid_events if wanted and e["value"].upper() == wanted]
    if not wanted:
        print("  没有目标 UUID 可比（没给 source-build.json）——只看发布面")
    elif report.get("registry_string_log_exhausted"):
        print("  预算仍被掐断：先把 run_umi_qemu.py 的事件上限抬上去"
              "（tools-wsl/make-run-umi-qemu-registry-budget.py）再判这条负证据。")
    elif len(hits) == 0:
        print("  目标卷一条都没发布 → 原版 APFS 没把我们那颗 RAM 容器解析成卷媒体；")
        print("     selectVolumeSeed 的 iterator 为空（matches=0），与 status=ENOENT/stage=0/seed_sha256 全零一致。")
        unclaimed = [e for e in content_events if not e["value"]]
        if unclaimed:
            unclaimed_names = {grouped.get(e["entry"], {}).get("BSD Name", "—") for e in unclaimed}
            print(f"     这些媒体只拿到了空的 Content（没被任何文件系统认领）：{sorted(unclaimed_names)}")
    elif len(hits) > 1:
        entries = {e["entry"] for e in hits}
        print(f"  目标 UUID 被发布 {len(hits)} 次、{len(entries)} 个不同对象 → selectVolumeSeed 里 "
              f"'++matches != 1' 那条直接判死，不是媒体不存在。")
    else:
        entry = hits[0]["entry"]
        props = grouped.get(entry, {})
        print(f"  目标 UUID 唯一命中，对象 {entry} 的发布面：{props}")
        if "BSD Name" not in props:
            print("     该对象没发布 BSD Name → 取不到 kIOBSDNameKey，继续下一条（或压根没注册成 /dev 节点）。")
        else:
            print("     UUID 与 BSD Name 都在同一对象上 → 剩下的分支只有 major/minor 越界、"
                  "或提供者链 64 层内 OSDynamicCast(NativeRamBlock) 失败。")

    print(f"\n== 6. 全属性键统计（看清预算花在哪了）==")
    counts = {}
    for event in events:
        counts[event["key"]] = counts.get(event["key"], 0) + 1
    for key, count in sorted(counts.items(), key=lambda kv: -kv[1]):
        print(f"  {count:>4}  {key}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
