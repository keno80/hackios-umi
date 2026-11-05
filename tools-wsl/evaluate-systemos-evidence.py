#!/usr/bin/env python3
"""U 步之五之二判读件：把官方 analyze_umi_systemos_qemu.py 的断言集逐条搬到本地实跑结果上。

断言集合与上游一致、不增减；拆开是为了没过时能直接看出是哪一道闸。
上游那份是「汇总件」不是「校验件」，但它无条件读 `_exit_records` 2382 字节——那枚 static
定义在 boot-progress 包里，只有 --gic-diagnostics --screen-diagnostics 档才链得进内核。
没开那两枚旗标的档（如 39-systemos-union）在这里标 BLOCKED，不当 PASS 也不当 FAIL。
用法：evaluate-systemos-evidence.py [run 名，默认 40-systemos-screen]
"""
import hashlib
import json
import struct
import subprocess
import sys
from pathlib import Path

WS = Path("/home/unixnu/code/umi-work-pin")
OS_WINDOW_SHA = "e5634d04a8ac35f024845f583394e0a35deb26a04cb0c00286a8674e25a9a4f2"
SYSTEMOS_WINDOW_SHA = "b4908cde41d23e6bc05e6af51a2c9eeb00cf0f863a6a18b1600c96a3fd70414f"
RUN = "40-systemos-screen"

results = []


def check(name, ok, detail=""):
    results.append((name, bool(ok), detail))
    return bool(ok)


def blocked(name, detail):
    results.append((name, None, detail))


def report():
    print(f"== {RUN} 逐条判读（断言集与上游 analyze 件一致）==")
    passed = failed = 0
    for name, ok, detail in results:
        tag = "PASS" if ok is True else "BLOCKED" if ok is None else "FAIL"
        print(f"  [{tag}] {name}" + (f"   -> {detail}" if detail else ""))
        passed += 1 if ok is True else 0
        failed += 1 if ok is False else 0
    scored = passed + failed
    print(f"-- 结论：{passed}/{scored} 条过，{failed} 条未过，"
          f"{sum(1 for _, o, _ in results if o is None)} 条因观测面缺件阻塞")
    return failed


def main():
    global RUN
    RUN = sys.argv[1] if len(sys.argv) > 1 else RUN
    run = WS / "out/umi-qemu" / RUN
    try:
        data = json.loads((run / "gdb-stop.json").read_text())
        prov = json.loads((run / "provenance.json").read_text())
    except OSError as error:
        print(f"!! 没有可用快照：{error}")
        return 1
    kernel = Path(prov["source_kernel"])
    digest = hashlib.file_digest(kernel.open("rb"), "sha256").hexdigest()

    check("内核 sha 三处一致",
          digest == prov["kernel_sha256"] == data["kernel_sha256"], digest[:16])
    check("未碰真机且未改客户内存",
          not prov["physical_phone_access"] and not prov["guest_memory_patched"],
          f"phone={prov['physical_phone_access']} patched={prov['guest_memory_patched']}")
    check("未声明 VMM 属性且 accel==tcg",
          not prov["vmm_property_declared"] and data["qemu_accelerator"] == "tcg",
          f"vmm={prov['vmm_property_declared']} accel={data['qemu_accelerator']}")

    windows = [prov["root_input"], prov["systemos_input"]]
    check("两窗都 read_only", all(w and w["read_only"] for w in windows),
          str([w and w["read_only"] for w in windows]))
    if windows[1] is None:
        check("SystemOS 窗 provenance 存在", False, "systemos_input=None（跑的时候没带 --systemos-volume）")
        return report()
    check("OS 窗 sha 命中官方钉值", windows[0]["sha256"] == OS_WINDOW_SHA, windows[0]["sha256"][:16])
    check("SystemOS 窗 sha 命中官方钉值", windows[1]["sha256"] == SYSTEMOS_WINDOW_SHA,
          windows[1]["sha256"][:16])
    check("两窗文件区间不重叠",
          windows[0]["offset"] + windows[0]["bytes"] <= windows[1]["offset"],
          f"OS {windows[0]['offset']}+{windows[0]['bytes']} vs SystemOS {windows[1]['offset']}")
    for field, window in zip(("virtio_block_input", "virtio_extra_block_input"), windows):
        observed = data.get(field) or {}
        check(f"{field} 只读且真挂上设备",
              observed.get("read_only") and observed.get("device_attached"),
              f"read_only={observed.get('read_only')} attached={observed.get('device_attached')}")
        check(f"{field} 偏移与长度与窗一致",
              observed.get("offset") == window["offset"] and observed.get("bytes") == window["bytes"],
              f"obs=({observed.get('offset')},{observed.get('bytes')}) "
              f"win=({window['offset']},{window['bytes']})")

    symbols = {}
    for line in subprocess.check_output(["xcrun", "nm", "-n", str(kernel)], text=True).splitlines():
        f = line.split()
        if len(f) == 3:
            symbols[f[2]] = int(f[0], 16)
    memory = data.get("memory") or {}

    def read(name, n):
        key = f"{symbols[name]:#x}:{n:x}"
        if key not in memory:
            raise KeyError(f"缺观测键 {key}")
        return bytes.fromhex(memory[key])

    def scalar(name, n=4):
        return int.from_bytes(read(name, n), "little")

    try:
        root = struct.unpack("<18Q", read("_umi_owner_root_observation", 144))
        check("owner-root 前六字段==(2,1,80,1,1,1)", root[:6] == (2, 1, 80, 1, 1, 1), str(root[:6]))
        check("挂载/选择/验证设备三者相同", root[6] == root[7] == root[8],
              str([hex(v) for v in root[6:9]]))
        status, authorized, union = (scalar("_native_owner_cache_status"),
                                     scalar("_native_owner_cache_authorized"),
                                     scalar("_native_owner_cache_native_union"))
        check("SystemOS 挂载状态==(0,1,1)（0=挂上，1=已授权，1=原生 union）",
              (status, authorized, union) == (0, 1, 1), f"({status},{authorized},{union})")
        observation = struct.unpack("<20Q", read("_umi_exec_trace_observation", 160))
        check("执行观测面首字==1（记录有效）", observation[0] == 1, str(observation[:8]))
    except KeyError as error:
        check("观测块齐全", False, str(error))
        return report()

    # 上游对这块不做内容断言，只是无条件读 2382 字节再拆三段描述——读不到它的档，官方件跑不完。
    exit_rows = None
    if "_exit_records" in symbols:
        try:
            exits = read("_exit_records", 2382)
        except KeyError as error:
            check("进程退出记录面（_exit_records 2382 B）", False, str(error))
            exits = None
        if exits is not None:
            counts = dict(zip(("total", "failed", "crashes"), struct.unpack_from("<3I", exits)))
            check("进程退出记录面（_exit_records 2382 B 可读）", len(exits) == 2382, str(counts))

            def rows(start, count, size):
                return [exits[start + i * size:start + (i + 1) * size].split(b"\0", 1)[0]
                        .decode(errors="replace") for i in range(count)]

            exit_rows = {"process_exit_counts": counts,
                         "recent_process_exits": rows(12, 4, 120),
                         "failed_process_exits": rows(492, 3, 120),
                         "process_crash_descriptions": rows(852, 3, 400)}
    else:
        blocked("进程退出记录面（_exit_records 2382 B）",
                "符号不在内核里：属 boot-progress 包，需 --gic-diagnostics --screen-diagnostics 重编一档")

    derived = {}
    try:
        derived["launchd_main_observed"] = scalar("_initproc_spawned") == 1
        seen = scalar("_umi_exec_trace_seen", 8)
        derived["panic_recorded"] = bool(seen & (1 << 5))
        derived["critical_exit_recorded"] = bool(seen & (1 << 8))
        derived["dyld_flags"] = scalar("_native_owner_cache_dyld_flags")
        derived["native4k_signature_cache"] = {
            name: scalar("_cs_native4k_" + name, 8) for name in ("full_blocks", "page_checks", "ready_blobs")}
    except KeyError as error:
        derived["derived_incomplete"] = str(error)

    print("-- 上游汇总件会写的派生值 --")
    for k, v in derived.items():
        print(f"  {k} = {v}")
    if exit_rows:
        print("-- 上游从 _exit_records 拆出的三段（不是断言，只是它写进 analysis.json 的内容）--")
        for k, v in exit_rows.items():
            print(f"  {k} = {v}")
    print("-- 停点与屏上闸 --")
    for key in ("stop_symbol", "pc", "x0", "bounded_timeout_interrupted", "thread_count"):
        if key in data:
            print(f"  {key} = {data[key]}")
    if observation[1] == 8:
        print("  critical_exit: pid=%s wait_status=%s ns=%s code=%s desc_bytes=%s" % (
            observation[2], observation[3], observation[4], observation[5],
            observation[7] & 0xFFFFFFFF))
    if observation[1] == 9:
        print("  critical_process_identity: initproc_spawned=%s is_initproc=%s name=%s" % (
            observation[2], bool(observation[3]),
            struct.pack("<4Q", *observation[4:8]).split(b"\0", 1)[0].decode(errors="replace")))
    reason = data.get("argument_memory", {}).get("x0")
    if reason:
        print(f"  x0 参数字符串 = {reason}")
    return report()


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
