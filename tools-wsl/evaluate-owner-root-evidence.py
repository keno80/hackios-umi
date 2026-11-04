#!/usr/bin/env python3
"""U 步之三判读件：把官方 check_umi_owner_root_qemu.py 的 audit/trust 断言逐条搬到本地实跑结果上。

断言集合与上游一致，不增减；只是把「整体 assert」拆成逐条 PASS/FAIL，
这样第一次没过时能直接看出是哪一条闸（以及缺哪个 memory 观测键）。
用法：evaluate-owner-root-evidence.py <run 名> [audit|trust]
"""
import hashlib
import json
import struct
import subprocess
import sys
from pathlib import Path

WS = Path("/home/unixnu/code/umi-work-pin")
sys.path.insert(0, str(WS / "tools"))
from umi_root_trace import FIELDS  # noqa: E402

# 上游 harness 里硬编码的那份 OS 窗身份（与本机实测逐字相同）
OS_WINDOW = {"offset": 1048576, "bytes": 6077580800,
             "sha256": "e5634d04a8ac35f024845f583394e0a35deb26a04cb0c00286a8674e25a9a4f2"}
ROOT_UUID = "04769D26-2CA0-4825-B443-E2E5F88300F2"
READS = {"_umi_owner_root_observation": "<18Q",
         "_native_aes_kat_status": "<I", "_native_aes_registered": "<I",
         "_native_aes_interface_status": "<I",
         "_native_virtio_verified_blocks": "<Q", "_native_virtio_integrity_failures": "<I",
         "_native_verified_block_root_uuid": "37s"}

results = []


def check(name, ok, detail=""):
    results.append((name, bool(ok), detail))
    return bool(ok)


def main():
    run_name = sys.argv[1]
    case = sys.argv[2] if len(sys.argv) > 2 else "audit"
    run = WS / "out/umi-qemu" / run_name
    kernel = WS / f"out/umi-xnu/umi/kernel/qemu-owner-root-{case}.macho"
    try:
        data = json.loads((run / "gdb-stop.json").read_text())
    except OSError as error:
        print(f"!! 没有可用快照：{error}")
        tail = (run / "runner.log")
        print(tail.read_text()[-3000:] if tail.exists() else "(也没有 runner.log)")
        return 1
    prov = json.loads((run / "provenance.json").read_text())
    source = json.loads(kernel.with_suffix(".source-build.json").read_text())
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()  # noqa: E731

    digest = sha(kernel)
    check("内核 sha 三处一致", digest == data["kernel_sha256"] == prov["kernel_sha256"], digest[:16])
    check("tcg 且未声明 VMM 属性",
          data.get("qemu_accelerator") == "tcg" and not prov["vmm_property_declared"],
          f"accel={data.get('qemu_accelerator')} vmm={prov['vmm_property_declared']}")
    check("非超时中断且未改客户内存",
          not data.get("bounded_timeout_interrupted") and not prov["guest_memory_patched"],
          f"interrupted={data.get('bounded_timeout_interrupted')}")
    check("构建档=owner-root " + case + " 且 native_ufs",
          source["owner_root"] == case and source["native_ufs"],
          f"owner_root={source['owner_root']} native_ufs={source['native_ufs']}")
    check("owned 内存 320 MiB", prov["owned_memory_bytes"] == 320 << 20, prov["owned_memory_bytes"])
    ri = prov["root_input"] or {}
    block = data.get("virtio_block_input") or {}
    check("根窗只读", ri.get("read_only") is True and block.get("read_only") is True,
          f"guest={block.get('read_only')}")
    check("根窗 offset/bytes/sha",
          ri.get("offset") == OS_WINDOW["offset"] and ri.get("bytes") == OS_WINDOW["bytes"]
          and ri.get("sha256") == OS_WINDOW["sha256"],
          f"off={ri.get('offset')} bytes={ri.get('bytes')} sha={str(ri.get('sha256'))[:16]}")

    symbols = {}
    for line in subprocess.check_output(["xcrun", "nm", "-n", str(kernel)], text=True).splitlines():
        f = line.split()
        if len(f) == 3:
            symbols[f[2]] = int(f[0], 16)
    memory = data.get("memory") or {}
    values = {}
    for name, fmt in READS.items():
        key = f"{symbols[name]:#x}:{struct.calcsize(fmt):x}"
        if key not in memory:
            check("观测键 " + name, False, f"缺 {key}；已有 {sorted(memory)[:4]}…")
            return report(run, case, data, prov)
        values[name] = struct.unpack(fmt, bytes.fromhex(memory[key]))
    state = dict(zip(FIELDS, values["_umi_owner_root_observation"]))

    check("phase==" + ("1(audit)" if case == "audit" else "2(trust)"),
          state["phase"] == (1 if case == "audit" else 2), f"phase={state['phase']}")
    check("trust_enabled==accepted==" + str(int(case == "trust")),
          state["trust_enabled"] == state["accepted"] == int(case == "trust"),
          f"trust_enabled={state['trust_enabled']} accepted={state['accepted']}")
    check("apple_autherr==80 且 owner_decision==readonly==1",
          state["apple_autherr"] == 80 and state["owner_decision"] == state["readonly"] == 1,
          f"autherr={state['apple_autherr']} decision={state['owner_decision']} readonly={state['readonly']}")
    check("挂载设备==选择设备==验证设备且非 0",
          state["mount_device"] == state["selected_device"] == state["verified_device"] != 0,
          f"mount={state['mount_device']:#x} selected={state['selected_device']:#x} verified={state['verified_device']:#x}")
    check("media_matches==uuid_match==wrong_uuid_refused==1",
          state["media_matches"] == state["uuid_match"] == state["wrong_uuid_refused"] == 1,
          f"media={state['media_matches']} uuid={state['uuid_match']} refused={state['wrong_uuid_refused']}")
    check("provider_depth==9", state["provider_depth"] == 9, f"depth={state['provider_depth']}")
    check("ufs 三项==0",
          state["ufs_published"] == state["ufs_verified_blocks"] == state["ufs_integrity_failures"] == 0,
          f"{state['ufs_published']}/{state['ufs_verified_blocks']}/{state['ufs_integrity_failures']}")
    for field in ("_native_aes_kat_status", "_native_aes_registered", "_native_aes_interface_status"):
        check(field + "==1", values[field] == (1,), str(values[field]))
    verified = values["_native_virtio_verified_blocks"][0]
    check("virtio 已验块 >=329", verified >= 329, verified)
    check("virtio 完整性失败==0", values["_native_virtio_integrity_failures"] == (0,),
          str(values["_native_virtio_integrity_failures"]))
    uuid = values["_native_verified_block_root_uuid"][0].rstrip(b"\0").decode()
    check("验证块根卷 UUID", uuid == ROOT_UUID, uuid)

    if case == "audit":
        check("停在 _panic", int(data["pc"], 16) == symbols["_panic"],
              f"pc={data['pc']} _panic={hex(symbols['_panic'])}")
        x0 = data.get("argument_memory", {}).get("x0", "")
        check("panic 文案=rootvp not authenticated",
              x0.startswith("rootvp not authenticated after mounting"), repr(x0[:80]))
    else:
        check("真实函数返回栈匹配", data.get("function_return_stack_matched"), "")
        args = [int(v, 16) for v in data.get("function_entry_arguments", [])[:2]]
        check("入口实参==[80,1]", args == [80, 1], str(args))
    regs = {k: int(v, 16) for k, v in (data.get("system_registers") or {}).items()}
    tcr = regs.get("TCR_EL1")
    check("TCR_EL1 译码配置（>>14&3==0 且 >>30&3==2）",
          tcr is not None and tcr >> 14 & 3 == 0 and tcr >> 30 & 3 == 2,
          f"TCR_EL1={hex(tcr) if tcr else None}")
    return report(run, case, data, prov)


def report(run, case, data, prov):
    print(f"== {run.name} / {case} 档逐条判读 ==")
    failed = 0
    for name, ok, detail in results:
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}" + (f"   -> {detail}" if detail != "" else ""))
        failed += 0 if ok else 1
    print(f"-- 结论：{len(results) - failed}/{len(results)} 条过，{failed} 条未过")
    print(f"-- pc={data.get('pc')} x0={data.get('argument_memory', {}).get('x0', '')!r}")
    print("-- 观测 18 字段 --")
    memory = data.get("memory") or {}
    symbols = {}
    for line in subprocess.check_output(["xcrun", "nm", "-n",
            str(WS / f'out/umi-xnu/umi/kernel/qemu-owner-root-{case}.macho')], text=True).splitlines():
        f = line.split()
        if len(f) == 3:
            symbols[f[2]] = int(f[0], 16)
    key = f"{symbols['_umi_owner_root_observation']:#x}:90"
    if key in memory:
        for index, value in enumerate(struct.unpack("<18Q", bytes.fromhex(memory[key]))):
            print(f"  [{index:2d}] {FIELDS[index]:26s} = {value:#x} ({value})")
    else:
        print("  (无观测块)")
    return failed


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
