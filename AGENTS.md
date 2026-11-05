# AGENTS.md — 在小米 10 上跑原生 iPadOS（UniXNU / umi）

这份文件是入口地图。会话开始时先读它，别去 `tools-wsl/` 里翻序号脚本——大部分是历史一次性探针。

## 项目是什么

在自己的小米 10（umi / SM8250，8GB+256GB，BL 已解锁，手上没有实体 Mac）上，用
[UniXNU](https://unixnu.com) 把 XNU 内核跑到用户态，最终引导 iPadOS 用户件。
构建主机是 Windows + WSL2 Ubuntu-24.04；真机侧只做零写入的 `fastboot boot`。

推进方式是一条「归因链」：每过一次闸就留一个屏上/日志上的硬证据，再打下一档。
阶段用字母记（A…T 步），每步的取证落在 `out/probes/`，屏幕证据落在 `out/screens/`。

## 环境：两套树，只有一套算数

| 东西 | 路径 | 说明 |
|---|---|---|
| 本仓（Windows） | `E:\Code\HackIos` | WSL 里是 `/mnt/e/Code/HackIos` |
| **构建真正吃的设备树** | `/home/unixnu/code/UniXNU-umi` | **ext4 那份**。Windows 侧同名克隆对构建不可见，改错地方白跑几十分钟 |
| 工作区 | `/home/unixnu/code/umi-work-pin` | `devices/umi` 是 bind mount，指向上面那份（`ensure-dev-bind` 负责） |
| XNU 重放工作树 | `/home/unixnu/code/UniXNU-main/out/umi/tree/.cache/xnu-work` | 补丁按 z 前缀排序重放到这里；直接改这里的文件会被构建还原抹掉 |
| 内核产物 | `/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho` | 判新鲜度看它的 sha256 |
| 构建日志 | `/home/unixnu/code/UniXNU-main/out/unixnu-logs/kernel-walk-*.log` | pid 在同目录 `kernel-walk.pid` |
| 监控面板 | `http://127.0.0.1:8765/` | 从 `/proc` 自动接管在跑的任务，不需要手写状态文件 |

## 重启后：一条命令

宿主机重启会丢三样东西：WSL 本身、`devices/umi` 的 bind mount、`/usr/local/bin` 里的命令快照。

```powershell
wsl.exe -d Ubuntu-24.04 bash -lc "tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/reboot-restore.sh > /tmp/rr.sh; bash /tmp/rr.sh"
```

它做四件事：按白名单重装命令 → 重建 bind → 起 8765 面板 → 打印内核 sha 与在跑的任务。
白名单在 `tools-wsl/sync-helpers.sh` 里，是唯一出处：`unixnu-env` `ensure-dev-bind` `progress`
`dashboard` `rawlog` `run-umi-qemu` `ab-status`（对照实测引用表 `out/probes/entry-pathcmds.txt`）。
同一件还会给 `/opt/homebrew/opt/llvm/bin/llvm-objdump` 装个指向 `/usr/bin/llvm-objdump` 的 shim——
上游 `build-boot-progress.py` 按 Mac 的 Homebrew 位置直接点名它，没有这层 boot-progress 档起不来。
还给 `/usr/local/bin/llvm-objcopy` 装 Mach-O shim（真件在 `/usr/bin`）：Ubuntu LLVM 18.1.3 那份对 Mach-O
不实现 `--globalize-symbol`（只对 ELF 实现），而上游 `build-umi-platform-power.py:131` 与
`build_umi_data_display.py:114/:118` 都点名它——shim 只补 Mach-O 的 globalize 那一步
（`tools-wsl/macho-globalize.py` 直接改 nlist 的 `N_EXT`/`N_PEXT` 位），ELF 与其余调用原样直通真件。
`--prune` 会认它是白名单装件、不当陈旧快照清掉。
`/usr/local/bin/ensure-dev-bind` 如果是旧版会漏「非空目录」判定，把重启留下的空目录误判成需要停手，
构建 kick 会静默失败——所以白名单里那两个命令必须每次用仓库版覆盖。
加 `--prune` 才会清掉 `/usr/local/bin` 里顶层已无同名脚本的陈旧快照（现有 60+ 项历史残留）。

## 调用 WSL 的规矩

一律落脚本文件，别把 WSL 逻辑内联进 `wsl.exe bash -lc "..."`：引号会被吞，实测踩过。

```bash
MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 bash -lc \
  "tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/<脚本> > /tmp/<脚本>; bash /tmp/<脚本>"
```

脚本自己 `exec > /mnt/e/Code/HackIos/out/probes/<名字>.txt 2>&1`，然后用 Read 读结果。
等后台进程结束，用「证据文件出现/文件里有结束标记」判，别用 `pgrep`。
wsl.exe 直接回显是 UTF-16，看着像二进制，需要 `tr -d '\000'`。

## 入口清单

### 现场与恢复
- `tools-wsl/reboot-restore.sh` — 重启后第一条（见上）
- `tools-wsl/sync-helpers.sh` — 白名单命令安装（唯一出处，`--prune` 清陈旧）
- `tools-wsl/check-env.sh` — 工具链基础包是否落地 + 出网自检
- `tools-wsl/unixnu-env.sh` — 统一代理设置（NAT 网关即宿主，子网会变，动态解析）
- `tools-wsl/ensure-dev-bind.sh` — `devices/umi` bind mount，构建前置

### 内核构建
- `tools-wsl/run-kernel-walk.sh` — **主构建入口**：`build_umi_xnu.py --stage kernel --profile phone --mockfs-root -j 5`
- `tools-wsl/h-wait-kernel.sh` — 等构建结束并取日志尾
- `tools-wsl/preflight-kernel.sh` / `run-kernel-cold|mockfs|screen|trace|pin|main.sh` — 各档位的历史入口，新档从 `run-kernel-walk.sh` 改参数

### 补丁（改 XNU 的唯一通路）
1. 写/改 `tools-wsl/make-*-patch.sh` 或 `tools-wsl/make-*.py`，从 `.cache/xnu-work` 读原文、
   断言锚点命中、`diff -u` 产补丁，直接落 `patches/umi-xnu/zzzz…-umi-<语义>.patch`
2. `tools-wsl/h-install-band.sh` — 把仓库 `patches/` 覆盖安装到 ext4 那份 `UniXNU-umi/patches/umi-xnu/`
3. `tools-wsl/run-kernel-walk.sh` 重编，`tools-wsl/audit-umi-patches.sh` / `sync-umi-patches.sh` 核对重放
4. 二进制层取证：`llvm-nm` + `llvm-objdump` 反汇编看守卫是否真落地（参照 `make-amfi-guard-patch.py` 那一档）

z 前缀长度决定重放顺序，新补丁接在最长串后面。

### 用户态件与容器
- `tools-wsl/build-n4kroot-real.py` — 把真 Apple 的 `/sbin/launchd` + `/usr/lib/dyld` 装进 mockfs 的 `N4KROOT` 假根容器，产 `out/fixtures/root-real.macho`
- `tools-wsl/build-n4k-fixture.sh` / `build-mockfs-fixture.sh` / `repack-mockfs.sh` — 假件容器与历史归档
- 容器只有两槽（launch / test），名字映射见 `mockfs_vnops.c` 的 `mockfs_lookup`

### QEMU 自测
- `tools-wsl/run-umi-qemu.sh NAME --mockfs-initrd <IMG> --args "-v keepsyms=1 kt_fixed_zones=120" --capture-screen --timeout 240`
- 产物：`out/umi-qemu/NAME/screen.png` + `gdb-stop.json`；launch 日志出现 `run_umi_qemu exit=` 即结束
- 停 `_bsd_init` 的资格化快照一律走 `--timeout 600`：300 秒经常撞超时，超时会停在 IOKit 之前的任意点，元类读出来全 0（不是内核问题）
- `tools-wsl/launch-qemu-screen.sh` / `run-qemu-zones.sh` — 历史档位

### U 步：存储资格化（prelink → ABI 活体审计 → 块件/提供者）
- `tools-wsl/run-umi-prelink.sh NAME` — `build_umi_prelink.py --profile qemu --storage`，产 `kernel/NAME.macho` + 同名 `.json`/`.provenance.json`
- `tools-wsl/run-storage-abi-snapshot.sh [基名] [可复用 ESP 档]` — 停 `_bsd_init` 读两个元类 + 带 `SCTLR_EL1` 的系统寄存器，喂 `audit_umi_storage.py` 出 `out/umi/storage-abi/interface-audit.json`
- `tools-wsl/run-native-ufs.sh [qemu|phone]` — 编 `NativeUfs.o` + 绑原版存储类，产 `tree/build/native-ufs/{libNativeUfs.a,bindings.json,build-report.json}`
- `tools-wsl/run-storage-providers.sh static|live [基名] [复用 ESP 档] [含 AES 元类读址的快照档]` — 静态段定位原版 IOAESAccelerator 派发表；活体段读三个元类后产 `libNativeAES.a` / `libNativeVirtioBlock.a`
- `tools-wsl/make-gdb-stop-sctlr-observer.py` — 产「别名观测件」，把本机 QEMU 的 `SCTLR` 双写成 `SCTLR_EL1`（上游审计脚本按精确名取值，否则判不出 native 4K）
- 作者的工具把候选内核名字写死（`qemu-storage-apfs.macho` / `qemu-native-ufs-trace.macho` + 同名 `.json`），本仓那件叫 `apfs-prelink-kernel.macho`；脚本按 audit 的 `candidate_sha256` 核对后落名/建链接，对不上就停手——别用过期 audit 去绑内核地址

### U 步之三：owner-root / VerifiedRoot 真根策略（纯 Linux）
- `tools-wsl/make-volume-infos-linux.py` — 产 `OS`/`SystemOS` 两枚 `*-volume-info.json`（`prepare_umi_root_policy.py` 唯一的输入，卷 UUID 从 GPT 分区起点上的 libfsapfs 视图读）
- `tools-wsl/verified-root-host-check-linux.py` — Linux 侧 host 自检，顶掉上游 Mac 的 `VerifiedRoot/tests/check.py`
- `tools-wsl/prepare-root-policy-linux.py` — 9.1 GiB 两窗逐块真验签，产 `policies.json` + 73,287,008 B manifest
- `tools-wsl/run-root-policy.sh` — 上面三件的总入口 + `build_umi_root_bundle.py`，产 `tree/build/umi-root-policy/libVerifiedRootProbe.a`
- `tools-wsl/run-kernel-owner-root.sh audit|trust` — `build_umi_xnu.py --stage kernel --profile qemu --crypto-bootstrap prelinked --native-ufs --owner-root <档> -j 5`
- `tools-wsl/run-owner-root-qemu.sh audit|trust [run名]` — prelink + `run_umi_qemu.py --root-volume` 取证，产物落 `out/umi-qemu/<run名>/`
- `tools-wsl/evaluate-owner-root-evidence.py RUN [audit|trust]` — 把官方 `check_umi_owner_root_qemu.py` 的 23 条断言逐条拆成 PASS/FAIL（断言集合不增减，别拿去当"我放宽了"的借口）
- 两档的停法不一样：audit 停 `_panic`（拒挂根是它的证据），trust 停 `_native_owner_root_accepted_checkpoint` 且必须带 `--finish`
- 还差一件才够官方一站式 PASS：`out/umi/screen-qemu-baseline.json`（要官方 screen-diagnostics 资格化链，本机完全没有）。trustcache 原件那件缺口已在本仓闭合，见下面 U 步之四

### U 步之四：trustcache 原件取源与 38 档取证（纯 Linux）
- `tools-wsl/fetch-ipsw-buildmanifest-linux.py` — 用上游 `unixnu.ipsw.RangeFile` 走 HTTP Range 只取远端 IPSW 的
  `BuildManifest.plist`（749,588 B，sha 命中 `devices/umi/ipsw-inputs.json` 的 `manifest_sha256`），不落整包
- `tools-wsl/run-original-trust-linux.sh` — 上面那件 + **官方 `tools/prepare_umi_trustcache.py` 一字未改**，
  产 `out/umi/trustcache/original-static-system.bundle`（61,356 B，sha `7416ca4f…`，官方件里 assert 钉死）+ `inputs.json`
- `tools-wsl/run-trustcache-qemu.sh [run名] [停点符号]` — `run_umi_qemu.py --trust-cache … --root-volume …` 跑到
  launchd 的 AMFI 信任缓存查询；`EXTRA_TRACE=1 FINISH=0 … _panic` 是探路跑法（把候选全挂 logpoint 看 lr 归属）
- `tools-wsl/evaluate-trustcache-evidence.py RUN` — 把官方 `check_umi_trustcache_qemu.py` 的 13 条断言逐条拆成 PASS/FAIL
- `tools-wsl/check-trustcache-official.sh` — **直接跑上游官方 check 件**（导出工具链 PATH 后可用），产
  `out/umi/trustcache-qemu-baseline.json`；本机实测 PASS，14/14
- **停点原理**：官方只要求最终 `pc` 落在 AMFI 的 `__TEXT_EXEC` extent 内，而 `--finish` 的 `pc` 是**调用方返回址**；
  donor AMFI 段里 `nm` 符号数 0，所以别去找「AMFI 内部地址」，要挑**被 AMFI 调用的内核符号**（`trust_cache`/`cs*` 面）
- **观测件通路**：`trace_events` 每条带 `pc/x0/x1/lr/elapsed_seconds`（`gdb-stop.py` 里两处 append 都是这个形状），
  所以一次跑就能按 `lr` 落在哪个段来判「谁调用了谁」，不需要静态反汇编
- 两个本机工具坑：`xcrun nm` 只在导出 `XNU_TOOLCHAIN_BIN` + 工具链 PATH 后可用（`/usr/bin/xcrun` 是 Linux shim，
  默认 PATH 下退化成 GNU `nm`，对 Mach-O 报 `file format not recognized`）；本机没有能按 VMA 反汇编 prelinked 件的
  objdump（GNU 不认这格式，`llvm-objdump -d` 只吃它自己认识的符号址区间）

### U 步之五：SystemOS union 与 dyld shared cache（进系统的那道闸）
- `tools-wsl/run-kernel-systemos.sh` — `build_umi_xnu.py --stage kernel --profile qemu --crypto-bootstrap prelinked
  --native-ufs --owner-root trust --systemos`；`--systemos` 要求 owner-root=trust，并打开
  `XNU_OWNER_CACHE_MOUNT/OWNER_CACHE_STARTUP/OWNER_BOOT_MANIFEST/OWNER_UNION_SYSTEMOS/NATIVE_CS_HASH_CACHE`
- `tools-wsl/h-wait-systemos-chain.sh` — 全链一条命令：等 kernel 构建结束 → 判 SystemOS 观测符号在位 →
  `run-umi-prelink.sh qemu-systemos-union`（`build_umi_prelink.py` **没有** systemos 开关，只 `--profile/--storage`）→
  QEMU 取证 → 官方 analyze；日志在 `out/probes/systemos-chain.log`
- `tools-wsl/run-systemos-qemu.sh [run名]` — 三旗标取证：`--root-volume --systemos-volume --trust-cache`，
  再把官方 analyze 要读的观测符号一个不缺地 `--read-symbol` 挂上（`_native_owner_cache_*` / `_umi_exec_trace_*` /
  `_cs_native4k_*` / `_initproc_spawned`），`--trace _trust_cache_runtime_init --trace _load_init_program`
- `tools-wsl/evaluate-systemos-evidence.py RUN` — 本地按官方 analyze 的断言集逐条拆 PASS/FAIL/BLOCKED
  （断言不增减）。39 档 **15/15 PASS + 1 条 BLOCKED**；41-systemos-screen 档 **16/16 全过、0 条阻塞**
- 判读件是官方的 `tools/analyze_umi_systemos_qemu.py`（不是 check 件，它拒绝覆盖已有 analysis.json），
  它断言 `_native_owner_cache_status=0`/`authorized=1`/`native_union=1`、`_initproc_spawned=1`，
  并把结果分成 `launchd_main_and_services_observed_within_bounded_run` 等四档；
  `ios_ui_observed` 与 `phone_runtime_equivalence_proved` 在上游自己手里恒为 false。
  它第 59 行无条件 `read("_exit_records", 2382)`，要两件事才跑得全：内核链进 boot-progress（下面 screen 档）
  + 观测件把这条大读拆成分段包（下面分段读件）。两件都落地后本机实测 `status=startup_not_yet_resolved`
- `run_umi_qemu.py --systemos-volume` 必须与 `--root-volume` 同给（它自己 error 出来），并会 SHA 校验第二个窗，
  两块只读盘分别落到 `virtio_block_input` / `virtio_extra_block_input`
- `tools-wsl/run-kernel-systemos-screen.sh` — 在 `--systemos` 之上再加 `--gic-diagnostics --screen-diagnostics`
  （后者硬要求前者，`build_umi_xnu.py:70`；ArmCpu 会因此重编，`tree/build/armcpu/build-report.json` 里
  `"gic_diagnostics": "qemu"` 是它的活体证据）。这两面把 boot-progress 套件链进内核，`_exit_records`
  （`struct bp_exits` = total/failed/crashes + recent[4]×120 + failures[3]×120 + crash[3]×400 + reason[330]
  = 2382 B）才作为符号存在。除上面两条坑（provider 清单、objdump shim）外，它 kick 前会硬闸
  三件上游 systemos 补丁 + `zzzzzzzzzzzzz-umi-systemos-trace.patch` + `package/boot-progress/{BootProgress.c,BootProgressCore.h}`
- `tools-wsl/make-run-umi-qemu-chunked-read.py` — 给**真正被执行的那份** `$WS/tools/run_umi_qemu.py` 追加一条
  观测件替换：把 `--read-memory` 的单发 `m` 包改成上游自己在 saved-register 采集里就用的
  「页边界 + 每次 ≤512 字节」分段循环（`gdb-stop.py:1389-1396`），拼回同一个键。上游观测件本体一字不改
  （`run_umi_qemu.py` 本来就一直在给它打窗口补丁），判读件也不改；短读产出的字节与改动前逐字节相同，
  读不上的页记到新的 `memory_read_errors` 而不是把 `E22` 当数据存。幂等 + `compile()` 自检，
  `run-systemos-qemu.sh` 每次挂 `_exit_records` 前自己打（`--restore` 可撤）
- **原版卷实测（u151/u152/u154，纯 Linux 只读）**：OS 卷 `DawnUpdate21H461…OS` 里
  `/usr/lib/dyld`(937,056, `cf fa ed fe` filetype 7) 与 `/sbin/launchd`(561,856, filetype 2) 是实体文件，
  但 **`/usr/lib/libSystem.B.dylib` 不存在**（只有 `libSystem.B_asan.dylib`），
  `/System/Library/Caches/com.apple.dyld` 整个目录也不存在（`/System/Library/Caches` 只有 3 项）→
  屏上 `(no such file, no dyld cache)` 是字面正确，扩假根这条路本来就装不下
- **shared cache 在 SystemOS cryptex 窗里，且是明文**：该窗扫到 `dyld_v1` 65 次、`dyld_shared_cache` 253 次、
  `libSystem.B.dylib` 3,345 次、`com.apple.dyld` 70 次。libfsapfs 打不开这个卷的 B-tree
  （`invalid object type: 0x00000000`），但内核侧的原版 APFS 驱动不受这个限制——所以走 `--systemos-volume` 而不是主机解析
- pyfsapfs 的 `file_entry` 面**没有** `metadata`/`get_number_of_sub_entries`；正确用法是
  `vol.get_file_entry_by_path("/…")`（路径不存在返回 `None`，不是异常）+
  `entry.get_number_of_sub_file_entries()` / `get_sub_file_entry(i)` / `entry.size` / `entry.file_mode`
- **39-systemos-union 实测（2026-11-05，`out/screens/39-systemos-union.png`）**：cache 挂载与授权这半道闸过了——
  `(status, authorized, native_union) == (0,1,1)`、两窗 sha 命中官方钉值（OS `e5634d04…` / SystemOS `b4908cde…`）
  且区间不重叠、两块 virtio 盘只读且真挂上、`owner_root` 前六字段 `(2,1,80,1,1,1)`、`observation[0]==1`、
  `dyld_flags=8`、native 4K 哈希面 `full_blocks=30892 / page_checks=36 / ready_blobs=9`。
  屏上 `(no such file, no dyld cache)` **消失**，代之以 `EL0 IN/OUT svc=…` 流水（28/26/372/294/10/14/20/427…）；
  这批 EL0 是真件不是假根——本档 `mockfs_initrd=None`、内核里 mockfs 符号 0 个，
  行本身由 `osfmk/arm64/sleh.c:1957` 的内核侧 trap 观测件打印（对任何 EL0 进程都生效）
- **新的停点＝上游自己的终点**：`pc=0xfffffff00bffe6ac=_panic+0x0`，`x0` 指 `"AMFI: No PMGR?\n"`，
  调用栈是 `_thread_call_invoke+0x78` ← `_thread_call_thread+0x218` ← `_Call_continuation+0x44`（异步 thread call，
  `bounded_timeout_interrupted=False` 不是超时假象）；trace 两条 `_trust_cache_runtime_init`(7.841s) /
  `_load_init_program`(9.299s)，phase 位 `[1,3,4,6,10,11,16,17,32,33]`（16/17 与 32/33 = 两次 init_exec begin/return），
  但 `_initproc_spawned=0` → `launchd_main_observed=false`。**这正上游 check 件原话判死的形态**
  （`check-owner-dyld-startup-checkpoints.py:112` "full cache mapping, launchd main and hardware remain open"），
  所以下一步不是补作业，是要超出上游
- **40/41-systemos-screen 实测（2026-11-05，`out/screens/41-systemos-screen.png`）**：screen 档源内核
  `d383e25b…`（`nm` 52,225 行，`_exit_records` 在位）→ prelink `qemu-systemos-screen.macho` sha `26d2019a…`
  （17 件）→ 三窗只读盘 QEMU 停 `_panic`。**官方 `analyze_umi_systemos_qemu.py` 本机首次跑全**（exit=0，
  产 `out/umi-qemu/41-systemos-screen/analysis.json`），本地判读件 16/16。停点仍是
  `pc=0xfffffff00c00867c=_panic`、`x0="AMFI: No PMGR?\n"`；新拿到的 `_exit_records` 面**全零**
  （`total=failed=crashes=0`，recent/failed/crash 三段全空串）→ `launchd_main_observed=false` 不是
  「launchd 起来又死了」，是压根没进 main。屏上 boot-progress 的 `UMI .. <stage>` 序列
  （`PE_init_iokit`→`early_boot`→`mac_policy_initmach`→`vmguard_policy_init`→`dtrace_early_init`→
  `trust_cache_init`→`OSKextRemoveKextBootstrap`→`machine_lockdown`→`kernel_do_post - done`→`PE_lockdown_iokit`）
  把 panic 钉在 iokit lockdown 之后；`native4k` 面同时跳到 `full_blocks=36121 / page_checks=44 / ready_blobs=11`
  （39 档是 30892/36/9），说明签名哈希缓存在 panic 前还在真干活

### U 步之六：`--pmgr` 档——把 `AMFI: No PMGR?` 这道闸归因掉
- `tools-wsl/run-kernel-systemos-pmgr.sh` — `build_umi_xnu.py --stage kernel --profile qemu --crypto-bootstrap prelinked
  --native-ufs --owner-root trust --systemos --gic-diagnostics --screen-diagnostics --pmgr -j 5`。
  前置自检里必须验 `kits/umi/UmiPlatformPower.cpp` + `scripts/build-umi-platform-power.py` +
  `zzzz-umi-pmgr.patch` + boot-progress 套件 + 两枚 objcopy/objdump shim 全在位，再对 prelink 输入档
  跑一次 `tree/scripts/audit-umi-pmgr-contract.py`（**`devices/umi/scripts` 那份不能用**：它的
  `ROOT = parents[1]` 指到 `devices/umi`，`from native_prelink import …` 直接 `ModuleNotFoundError`；
  上游仪表自己点的就是 `tree/scripts` 那份，且它要求 `--output`）
- `tools-wsl/run-pmgr-qemu.sh <off|lifecycle|publish|refusal|root|amfi|deep> [run名]` — 一份内核跑官方
  六个 mode：`off` 不给旗标停 `_panic`；`lifecycle`=`umi-pmgr=1` 停 `_umi_pmgr_checkpoint`；
  `publish`=`umi-pmgr=2` 同停点；`refusal`=`umi-pmgr=3` 停 `_panic`；`root`=`umi-pmgr=2` 停
  `_IOFindBSDRoot`；`amfi`=`umi-pmgr=2` 停 `--stop-address 0xfffffff004aaeb54`（契约审计钉死的
  AMFI 读/OR/写址）。判读就是官方 `tools/check_umi_pmgr_observation.py --mode <同名>`，
  它把 stop 符号按 mode 写死，所以停点不能自挑
- **读址集与 SystemOS 档对齐**（官方 `analyze_umi_systemos_qemu.py` 无条件读的符号一个不缺：
  `_native_owner_cache_dyld_flags:4`、`_cs_native4k_{full_blocks,page_checks,ready_blobs}:8`、
  `_exit_records:0x94e`），所以同一份取证既能喂 pmgr 官方 check 又能喂 SystemOS 官方 analyze
- **实测（2026-11-05，内核 `qemu-systemos-pmgr.macho` sha `284fa323…`，17 件 prelink）**：
  官方 `check_umi_pmgr_observation.py` **六个 mode 全 PASS**（`out/screens/43-pmgr-*.png`）。硬证据：
  仪表 `_umi_pmgr_run` 的调用方 lr = `__ZN16IOPlatformExpert5startEP9IOService+0x1bc`（原版 XNU 平台专家
  真的在 start 末尾调到了它）；publish 面 `stage=5`、`parent_size==own_size==0x4b8a8`、
  `provider==bound_provider≠0`、`nub≠0`、`read_before==read_after==0xffffffff`、`attached=1`、
  `registered=2`、`own/nub` 实例计数各 `0→1`；lifecycle 面 `stage=4/attached=0/registered=0`；
  refusal 面 `stage=0x1aa`(=0x100+170)、`status=0xe00002c7`（kIOReturnUnsupported 真走到了 panic）；
  **amfi 面 `pc` 恰等于契约址、`x20==nub`、`x21==0xffffffff`**——原版 AMFI 真的 retain 了我们发布的 nub
- **`AMFI: No PMGR?` 这道闸被打掉**：`umi-pmgr=2` 的深跑（`42/43-pmgr-deep`）里 `_panic` 断言一次没命中
  （`skipped_target_hits=0`），`_load_init_program` 8.846s 命中，**`_initproc_spawned=1`**
  → 官方 analyze 的 `launchd_main_observed` 第一次为真；屏上换成
  `UMI PANIC tzinit[171 exited` + `EL0 breakpoint record unavailable -- no exit reason available -- (signal 0, exit status 30)`，
  `UMI marks=3197`。停点是 `_halt_all_cpus+0x34`，栈里 `_unix_syscall+0x2b0` ← `_exit+0x1c` ←
  `_exit_with_reason+0x1b0` ← `_proc_exit+0x0` → `_panic_trap_to_debugger+0x38c`——
- **新闸从「launchd 起不来」变成「被 launchd 派生的服务（pid 171 tzinit）退出，内核走了 Debugger 路径」**
- `tools-wsl/run-screen-baseline-qemu.sh [run名]` — U 步之六之四：官方最后一件 baseline
  `tools/check_umi_screen_qemu.py --run … --kernel qemu-systemos-pmgr.macho`（它第 37 行硬要求
  `source-build.json` 里 `screen_diagnostics && gic_diagnostics && pmgr` 三者同开，这就是 U 步之三
  一直产不出 `out/umi/screen-qemu-baseline.json` 的原因）。停点 `_umi_boot_progress_checkpoint_eight`
  不能自挑（官方第 34 行钉 pc），且第 31 行要求**不是超时停**
- **boot-progress 整套仪表由运行时 boot-arg `boot-progress=1|2` 闸住（u218/u219/u221 实测，本轮根因）**：
  链进内核的是生成件 `tree/build/boot-progress/BootProgress.providers.c:716` 的 `boot_progress_init()`，
  它第一行就是 `if (!PE_parse_boot_argn("boot-progress",&opt,..) || (opt!=1 && opt!=2)) return;`。
  没给这个 boot-arg 时：`_boot_progress_frequency`/`_umi_boot_progress_anchor`/`_umi_boot_progress_samples`/
  `_boot_progress_observation` **全零**、`checkpoint_eight` 永不触发，取证只能吃到 900s 超时，
  而官方 screen 件第 31 行 `assert not bounded_timeout_interrupted` 必然失败。上游自己的跑法把
  `boot-progress=2` 钉在 boot args 里（`tools/run_umi_data_display_qemu.py:28`），
  `tools/make_umi_payload.py:58/59` 更是直接判死「Qualified screen diagnostic requires continuous boot-progress=2」
- **`boot_progress.h` 的 `#else` 分支是障眼法**：它把 `boot_progress_stage(s)` 映射到 `umi_screen_text(s)`，
  所以屏上有 `UMI .. <stage>` 序列**不等于**仪表在跑。判据只有两个：编译记录里 `-DXNU_BOOT_PROGRESS=1`
  （实测 `sleh.o.json`/`machine_routines.o.json` 都带，见 u220）+ 运行时 `boot-progress=` boot-arg
- **实测（2026-11-05，`45-screen-baseline`，屏照 `out/screens/45-screen-baseline.png`）**：补上 `boot-progress=2`
  后**官方 `check_umi_screen_qemu.py` 本机首次 PASS**，产 `out/umi/screen-qemu-baseline.json`
  （`status=passed_real_timed_framebuffer_diagnostics`、`counter_frequency=62500000`、
  `elapsed_between_passes_3_and_8=5.0218`、`actual_qemu_scanout_captured=true`、
  `source_archive_index_sha256=03fd28fc…`；`phone_panel_verified`/`root_mounted`/`userspace_qualified`
  是这件自己的口径，恒 false，不是我们的闸）。停点 `pc=0xfffffff00bfff528=_umi_boot_progress_checkpoint_eight`
  且 `bounded_timeout_interrupted=false`（真停不是超时停）。仪表硬证据：`samples` 第一趟
  `(1,5,2,3)`、末趟 `(1,6,7,8)`（phase/pass/count 都对得上官方断言）、两趟同一 frame
  `0xfffffff05f400000` / `800x600` / `row 3200`、`[2,1,providers]=2,1,7`（7 = 1 native_ufs | 2 | 4，
  后两位由 `owner_root != off` 打开，官方件就是这么算的）；
  `anchor=(0x7c7a0000, 0xfffffff13e0f6000, 0x1d4c00)`（物理基址 / 内核虚拟基址 / 字节数，
  `0x1d4c00` = 800×600×4 正好对上）；
  屏面换成完整诊断页：`UMiXNU boot diagnostics - live XNU - native 4K - no automatic reboot` +
  `time=7s idle=0s IRQ=3002 monitor=8 lost=0 root=1 process=1 free=278` +
  `OFFLINE_VIRTIO requests=2246 verified=2246 failures=0` + `pid=1 launchd EL0 OUT svc=…` 流水 +
  `SpringBoard: absent from this process pass`
- **这一档顺手把 `_exit_records` 激活了**：同一份取证里 `total=2`、两行
  `p1 init status=0 sig=0 exit=0 ns=0 sub=0`，屏上 `Proc ss exits: total=2 no zero-status-or-reason=0`。
  上一轮「全零」是因为仪表根本没启动，不是没人退出——所以 `tzinit` 那条退出原因现在**有通路可拿了**：
  本档停在 monitor 第 8 圈（≈8 秒）而 tzinit 在十几秒后才退，把停点往后挪（或加深跑）就能读到 reason 面

### U 步之七：Data 种子（可写 `/private/var`）——Linux 侧判死，必须 Mac 造
- `tools-wsl/make-umi-data-seed-linux.sh [logical MiB]` — 纯 Linux 造种子：`mkapfs -L Data -U <容器 UUID> -u <卷 UUID>`
  → `packed_ramdisk.pack()` → 身份 `.json` 带 `volume_uuid`，三段自检正好对上 `build_umi_xnu.py:92-95` 的三条闸。**造出来的容器原版驱动不认**（见下）
- `tools-wsl/run-kernel-systemos-data.sh` — 在 `--pmgr` 档之上加 `--data-ramdisk <dbr> --data-seed-json <json>`；
  `XNU_OWNER_DATA_VOLUME_UUID` 是**编译期**钉进 `tree/build/xnu/owner-data-volume.h` 的，所以换种子必须重编内核
- `tools-wsl/run-data-qemu.sh` / `evaluate-data-registry-evidence.py` — 取证与判读，看 `_native_owner_data_status/stage/readonly/device` 四元组
- `tools-wsl/make-run-umi-qemu-registry-log.py` / `-registry-budget.py` / `make-run-umi-qemu-cstring-log.py`
  — 给 `run_umi_qemu.py` 的观测件加装「IORegistry 字符串面 + 读址预算」，用来回答「种子容器有没有被注册成卷」
- **stage 阶梯语义**（`native_owner_data_prepare()`，在 `bsd/kern/kern_exec.c`，来自 `zzzzzzzzzzzzzz-umi-persistent-data-userspace.patch`）：
  `0` 无介质 / `1` 按卷 UUID 找不到种子 / `2` 已 `mount("apfs","/private/var",flags=0)` 但被驱动拒 / `3` `vnode_lookup` / `4` 成功；
  `2` 直接在 `kern_exec.c:7514` `panic("offline scratch Data mount failed: %d", data_error)`
- **ENOENT 归因结案（Path B）**：出错生产者 = `0xfffffff00573aa8c mov w25,#0x2`，停在此处 `x8=0x40=64`
  = 从 `[x19,#0x68]` 读的 `nx_cksum_count`。所以是**「N 枚 checkpoint 描述符全部校验失败」**，不是「计数为 0」。
  同一条 per-container 读址 `0x5739e04` 在一次开机里命中三次，`x8` 分别 `36`（cryptex）/ `56`（真 Apple OS 容器）/ `64`（我们的种子）
- **真因**：`mkapfs`（apfsprogs）**压根不写 checkpoint 描述符区**。同一把尺子（全镜像扫 APFS 块魔数，`out/probes/u336.txt`）：
  我们 512 MiB 种子里 `NXSB` 只命中 **2** 处（块 0 + 块 2 备份），真 Apple 容器 `apfs.bin` 光「前 64 MiB + 后 64 MiB」就 **45** 处
  （`0x20,0x2020,0x4020,…`）。原版 `nx_mount` 要至少一枚过 xid+对象校验和的 checkpoint，全失败 → ENOENT
  → 容器对象被 `setStatus` 钉成 `Status='Offline'`，**种子卷 UUID 从不进 IORegistry**
- **Linux 三条替代路全断（本轮实测）**：①`apfs-dkms`（`linux-apfs-rw 0.3.2-0ubuntu6.2`，dkms 里已 `added`）编不出来——
  WSL2 的 `linux-headers-6.18.54.1-microsoft-standard-WSL2` 是**空壳**（无 `Makefile` 无 `.config`），
  `make -C /lib/modules/$(uname -r)/build M=… modules` 报 `No targets specified and no makefile found`，
  `dkms build` 报 `kernel package … is not supported`，产不出 `apfs.ko`（u351/u352/u353）；
  ②`apfsprogs` 只有 `mkapfs/apfsck/apfs-snap`，**没有任何往 APFS 写文件的工具**（`apfsck` 连 `-n` 都没有，只认 `-cuvw`）；
  ③本树内核的文件系统名串只有 `apfs/devfs/mockfs/msdos`（u349），`bsd/hfs` 不存在、`hfsprogs` 未装，
  而 `/private/var` 要 symlink + owner，FAT 顶不了
- **「干净卸载标志」支路判死**：那个 u8 是 `[x0,#0x131]`，唯一生产者 `0xfffffff0056bcd24 strb w8,[x0,#0x131]`，
  来源 `ldp w8,w9,[x1,#0x38]` → `0x130`=`(x1+0x38)!=0`、`0x131`=`(x1+0x3c)!=0`（记录步长 `add x0,x0,#0x150` = 336 B）。
  `nx_mount` 的 `0x573aa54 cbnz w8,0x573a870` 确实是「干净就容忍描述符不符」，**但容忍只解决挂载**——
  可写 Data 还需要真 checkpoint/事务空间，伪造一枚等于重写 `newfs_apfs` 的 checkpoint writer。
  而且 `x1` 的盘上出处要靠函数 `0x56bcc8c` 的调用方定，全段找不到 `bl 0x56bcc8c`（u354），
  只剩活体寄存器间接读这一条口，本机观测件没有它（u348）
- **上游的权威口径（别再自己猜）**：`scripts/check-native-ram-data-checkpoints.py` 要 `qemu_accelerator == 'hvf'`（= macOS），
  要的正是 `build/owner-data-fixture/owner-data-32.cdr`（`33,554,432 B` + `sha256` 钉值），且要求挂载**可写**
  （`status=0 stage=4 readonly=0 device=0x1000002`、`_native_ram_block_reads == 517` / `_writes == 1509`）。
  同一枚种子在 `check-scratch-data-checkpoints.py` 里被**断言成 ENOENT**，那是 md0 对照档、不是判死。
  产它的是 Mac 件 `prepare-owner-data-fixture.py`：`hdiutil create -size 32m -layout NONE -fs APFS -volname OwnerData -type UDTO`
  → 拷 `private/var`（去掉 `staged_system_apps`、保 symlink）→ 补 `keybags/mobile/tmp/tmp/run` + `chmod 1777 tmp`
  → `diskutil info -plist` 取 `VolumeUUID` 写 `seed.json`。**这枚 .cdr 从没进过 git、无下载地址、无 LFS**（u350）；
  `docs/building.md:120` 原话「the Data seed steps call `hdiutil` and `diskutil`. A fork can run them on a GitHub macOS runner without a local Mac.」
- **结论**：Data 种子上 Mac 造。Linux 侧只做 `packed_ramdisk.pack()` + `volume_uuid` 钉值 + 重编/prelink/取证，这条链本机已经跑通
- **Mac↔Linux 交接两件（本轮新增，自测过 `out/probes/u357.txt`/`u358.txt`）**：
  - `tools-mac/make-owner-data-seed-mac.sh [--out DIR] [--size 32m] [--volname Data] [--from-var DIR]` —
    在 Mac 上跑：`hdiutil create -layout NONE -fs APFS -type UDTO` → `ditto` 拷 `private/var`（去 `staged_system_apps`）
    → 补 `keybags/mobile/tmp/tmp/run` + `chmod 1777 tmp` → `diskutil info -plist` 取 `VolumeUUID`
    → detach 后硬闸「大小 + 块 0 的 `0x20` 是 `NXSB`」→ 随行产 `seed.json`（`volume_uuid`/`bytes`/`sha256`）。
    `--from-var` 不给就是**空卷**——先拿空卷过挂载这一格，别一上来就跑全三件上游 Mac 脚本
  - `tools-wsl/pack-umi-data-seed-mac.sh <owner-data-*.cdr> [--name 档名]` — 回 Linux 后：缺 `seed.json` 直接停手（实测 rc=1、不留半成品）
    → `packed_ramdisk.pack()` + 身份 `.json`（`volume_uuid` 从 `seed.json` 取、大写归一）→ 按 `build_umi_xnu.py:92-95/:150`
    的三条闸自检 → 打印「把 `.json` 里的 `volume_uuid` 交给 `run-kernel-systemos-data.sh` 重编内核」
  - 语法/行为自测：`.json` 与既有 `data-512.json` 键集逐键一致；两件均 LF（`*.sh text eol=lf` 已覆盖 `tools-mac/`）
- **Mac 侧现在是 agent 可直驱的**（2026-11-05 实测，别再回答「要用户手动在 Mac 上跑」）：
  那台 VM 是 **Hyper-V** 不是 VMware（`D:\HyperOSX\VMs\macOS-HyperV`，macOS 15.8.2 / Darwin 24.6.0 / x86_64，4 vCPU / 8 GiB，
  建/起件在 `D:\HyperOSX\create-macos-vm.ps1`、`start-macos-vm.ps1`）。
  SSH `keno@172.17.164.116`（Hyper-V 内网，**只有宿主机够得到，WSL 在 172.28.x 段够不到**），
  免密私钥 `out/scratch/mac_id_ed25519`（gitignore，密码一律不入库）；
  文件双向走共享文件夹：macOS `/Volumes/Share` ↔ 宿主 `D:\HyperOSX\Share` ↔ WSL `/mnt/d/HyperOSX/Share`。
  两个坑：非管理员会话里 `Get-VM` **返回空而不报错**、`Get-VMNetworkAdapter` 抛 `VirtualizationException`（别当成「VM 不存在」）；
  `.ps1` 必须纯 ASCII（PS 5.1 按 ANSI 读无 BOM 的 UTF-8，中文注释会吞掉后面的引号报 ParserError）
- **第一趟实测（2026-11-05，空卷）**：`make-owner-data-seed-mac.sh --size 32m --volname Data` 一次过——
  `hdiutil` 产的容器 `NXSB` 命中 **5** 处（同尺子：mkapfs 的 512 MiB 种子只有 **2** 处、真 Apple 容器前 64 MiB 45 处），
  **归因当场复核成立**：Apple 的格式化真的写 checkpoint 描述符区，`mkapfs` 不写。
  卷 UUID `179622A6-176F-49F6-9024-8FD2D9A9CE3D`，logical sha `07340cc1…`，33,554,432 B，
  `pack-umi-data-seed-mac.sh` 打成 `out/umi/data-seed/mac-32.dbr`（编码 278,608 B）并过 build 侧三条闸（`out/probes/u363.txt`）
- **OS 卷里 `/private/var` 的量级（第二趟要用的初始树，u366）**：4,056 个常规文件 / **443.5 MiB** / 6,611 目录 / 1 symlink，
  其中大头是上游显式排除的 `staged_system_apps`——所以「拷完初始树还塞得下 32 MiB」这句要靠去掉它才成立
- **✅ 48-data-mac-seed 实测（2026-11-05，空卷种子）——挂载这一格当场过闸，Linux 造种子正式判死**：
  `native_owner_data_status` **2 → 0**、`stage=4`、`readonly=0`、`device=0x1000002`、`native_ram_block_ready=1`、
  身份三合一 PASS（`owner_data_seed_sha256 == ram_block_seed_sha256 == source-build` 全 `07340cc1…`），
  官方口径 **`data_mounted_writable = True`（本机首次为真）**、`launchd_main_observed = True`。
  也就是说 **Apple 原版 APFS 驱动认 Linux（`packed_ramdisk`）打包的 Apple 格式化容器**——内容缺口不是挂载闸
- **同一档拿到的新面（`_exit_records` 活起来了）**：`process_exit_counts=[19,3,0]`，
  `failed_process_exits` = `p6 launchd status=1 sig=1` / `p9 MSUEarlyBootTask status=1 sig=1` /
  **`p17 tzinit status=200 sig=0 exit=2`**；`panic_recorded=True` 而 `critical_exit_recorded=False`
  → 上一轮的「内核 critical-exit 路径」已被 Data 挂载打掉，屏上换成 launchd 自己的口径：
  **`UMI PANIC userspace panic: boot task failure: tzinit - exited due to exit(2)`**（`out/screens/48-data-mac-seed.png`，红屏）。
  `native_ram_block_writes=0` → 还没有件真往 Data 里写
- **第二趟（有内容种子）通路已落地**：
  - `out/scratch/u371-extract-var3.sh` — Linux 侧用 pyfsapfs 从 OS 卷解 `/private/var` 骨架（排除 `staged_system_apps`）
    → `tar -czf` 进共享文件夹 `var-tree.tar.gz`。两条坑修好了：①libfsapfs 对本树压缩块报
    `unsupported compression method: 9`（本机 pyfsapfs 的 `read_buffer` 只收 1 个参数，不是换 API 能绕的）→ 读不动的落 0 字节占位；
    ②`db/timezone/localtime` 的 symlink 目标读空 → `os.symlink('')` 抛 `FileNotFoundError` 把整趟走查从那儿截断，
    `tmp`/`run`/`Keychains` 全丢 → 现在每条目单独兜住，空目标落 `.`。结果 207 条目 / 543 KB，关键路径除
    `keybags`、`installd/private/InstanceIDs`（OS 骨架里本来就没有，首启才建）全在场
  - `tools-mac/seed-from-share-mac.sh` — Mac 侧一键：解 `var-tree.tar.gz` → `make-owner-data-seed-mac.sh --from-var <解出来的 private/var>`
    → 产物落 `$SHARE/seed-out/`（`owner-data-64.cdr` + `seed.json`）。**实测 `ditto src dst`（dst 已存在）拷的是 src 的内容**，
    所以 `--from-var` 直接指 `private/var` 就对——种子根 = `/private/var`（内核就是 mount 在这儿）
  - `out/scratch/u373-chain.sh` — Linux 侧无人值守：取件 → `pack` → 重编 Data 档内核（新 UUID 必须重编）→ prelink
    `qemu-systemos-data-mac64` → 取证 `49-data-mac-var`
  - 坑：`setsid nohup … &` 经 `wsl.exe bash -lc` 起长任务会被回收（日志文件压根不出现），要用受管后台跑
- **✅ 49-data-mac-var 实测（2026-11-05，带 `/private/var` 骨架的 64 MiB 种子）——U 步之七整步结案，且跨进 iOS 用户态**：
  种子 UUID `FB5F1CA2-FF22-47C5-BCB0-841C2CFFDE9C`、logical sha `521c7860…`、编码 921,680 B；内核 `qemu-systemos-data-mac64.macho`
  sha `02b1cd44…`。四元组仍是 `status=0 stage=4 readonly=0 device=0x1000003`、身份三合一 PASS，
  **`native_ram_block_reads=194 / writes=201 / resident=2,306,048 B` → 官方口径 `actual_ram_writes_observed=True` 本机首次**
  （上一档是 55/0——**用户件真在往 Data 里写了**）。
  **`panic_recorded=False`、`critical_exit_recorded=False`**：900 秒里内核一次没 panic，超时停点 `pc=_ml_get_timebase+0x18`
  （空闲环读时基，正常空转不是卡死）。
  进程面从 `19/3/0` 跳到 **`EXIT 260 nonzero 111 crash 5`**，`recent_process_exits` 全是 `xpcproxy`（launchd 正常派生服务）；
  屏上是完整诊断页 `LIVE: DEADLINE EXCEEDED — OS and diagnostic recording continue`，`time=892s IRQ=805534 monitor=890 root=1 process=53`，
  **`SpringBoard p26` 与 `backboardd p147` 真在进程表里**（`runningboardd p157` 也在；`PreBoard`/`lsd` 仍 absent），
  `OFFLINE_VIRTIO requests=771375 verified4K=1527463 failures=0`，`RAMDISK spars=1 capacityMiB=64 residentKiB=2252`
- 🔴 **下一闸（49 档新露出来的，都不再是内核闸）**：
  ①`failed_process_exits` = `containermanagerd_system` / `configd` / `fseventsd`，三条同形 `status=9 sig=9 ns=1 sub=4`（SIGKILL）；
  ②崩溃环三发全是 `watchdogd sig5`（SIGTRAP），`PC/LR` 都是 EL0 址（`0x10074fb0c` 等，不是内核符号）；
  ③屏上 `DISPLAY: VNU framebuffer diagnostics: OS display service not connected` +
  `CLK … dt-converted=89231ms cnt=rgx-converted=892312ms`（Rogue GPU 时钟面）；
  ④`LIVE: DEADLINE EXCEEDED` 本身——诊断页的开机期限已过，系统还在跑但没有 UI 落地

### U 步之八：jetsam 击杀归因——客存判死，owned-memory 才是那道闸（已结案）
- **`ns=1 sub=4` 的权威语义**：`ns=1` = `OS_REASON_JETSAM`（`bsd/sys/reason.h:88`），
  `sub=4` = `JETSAM_REASON_MEMORY_VMPAGESHORTAGE`（`bsd/sys/kern_memorystatus.h:294`）；
  生产者 = `memorystatus_thread` 的 `MEMORYSTATUS_KILL_TOP_PROCESS`（`doc/vm/memorystatus_kills.md:17`）；
  触发判据本体 = `memorystatus_avail_pages_below_critical()` 里 `available <= critical` 这一条比较
  （`kern_memorystatus.c:3652`），门槛 `MEMSTAT_PERCENT_TOTAL_PAGES(4|5)` 按 **`max_mem`** 算
  （`kern_memorystatus_internal.h:227`）——**不是按 dram，也不是按 QEMU 的 -m**
- **内存几何有四处，只有第三处管 jetsam**：`ADT /chosen/dram-size` → `gDramSize`（`arm_init_sptm.c:888`）；
  QEMU `-m`；**`ADT /chosen/darwinboot-memory-size` = `args->memSize`** → `arm_init_sptm.c:1551`
  `gPhysSize = mem_size = ((gPhysBase + args->memSize) & ~PAGE_MASK) - gPhysBase` → `:1745 max_mem = mem_size`；
  屏上 `MEM totalMiB` 就是 `max_mem>>20`（`devices/umi/package/boot-progress/BootProgress.c:79/440-441`），
  所以屏上那行与活体 `_max_mem` 是同一把尺子
- `tools-wsl/make-run-umi-qemu-guest-ram.py` — 两个旋钮一次挂上真正被执行的那份 `run_umi_qemu.py`：
  `UMI_GUEST_RAM_MIB` 同动 QEMU `-m` 与 ADT `dram-size`（两件必须同动），
  `UMI_OWNED_MEMORY_MIB` 动 ADT `darwinboot-memory-size`（替掉 `--owned-memory-mib` 的窄 `choices` 闸）。
  两个都不设 = 上游几何（1 GiB / 256 MiB），所以同一个产物既是实验档也是对照档
- **补丁件的三条坑（这轮补上的）**：①`restore()` 必须认**旧版定义块**——旧块正好是新块的前五行，
  所以查找顺序不能反，否则旧版补丁永远撤不掉；②锚点已处于未打补丁形态时逐条跳过，不要整体判死；
  ③看到旧版补丁在场就**拒绝叠加**（`exit 1` 并提示先 `--restore`），而不是叠出第二份定义块
- **50/51 实测：客存这条假设被否掉**——`dram-size` 与 `-m` 抬到 2 GiB，`darwinboot-memory-size` 仍是
  320 MiB（两档 provenance 都是 `owned_memory_bytes=335,544,320`），jetsam 照旧；
  51 反而更糟：900 秒 `counts=[1292,990,1]`，环内 7 发全是 `ns=1 sub=4`（`xpcproxy` 被反复杀）
- **抬 owned 不需要重编内核**：`umi_adt.py:213-216` 的闸是 `0x10000000 <= owned <= min(0x200000000, dram_size)`
  且 2 MiB 对齐（越界就 `ValueError`），上游自己的 `probe-*.py` 里 `--owned-memory-size 0x20000000`（512 MiB）
  是常用值；provenance 记 `owned_memory_bytes` 但构建侧没有消费者
- **✅ 54/55 单变量 A/B 实测（2026-11-05，两档固定 `UMI_GUEST_RAM_MIB=2048` + `BYPASS=1` + 900s，
  内核 `qemu-systemos-data-mac64` sha `02b1cd44…`，同种子；屏照 `out/screens/54-owned320.png` /
  `55-owned512.png`）——闸被这一条打掉，归因结案**：

  | 面 | 54-owned320（对照） | 55-owned512（实验） |
  |---|---|---|
  | ADT `darwinboot-memory-size` | 335,544,320 | 536,870,912 |
  | 活体 `_max_mem`/`_mem_size`/`_gPhysSize` | 320 MiB | 512 MiB |
  | `_sane_size` | 184 MiB | 376 MiB |
  | 屏上 `MEM totalMiB` | 320 | **512** |
  | `vm_page_free_count` vs `_min` | **129 页 < 266 页**（字面缺页） | 626 页 > 507 页 |
  | `available` vs `critical` | 17 MiB vs 16 MiB（`level=5%`） | 69 MiB vs 51 MiB（`level=13%`） |
  | `_vm_page_wire_count` | 290 MiB / 320 MiB = **91%** | 351 MiB / 512 MiB = 69% |
  | `counts(总,非0,崩)` | `[667,376,0]` | `[191,36,30]` |
  | 环内 JETSAM | **7/7**（含 `SpringBoard p411`、`logd`、`rapportd`、`distnoted`） | **0** |
  | `native_ram_block(读,写)` | 145 / 257 | **1322 / 1173** |

  55 屏上 `SpringBoard p144`、`lsd p105`、`backboardd p57`、`runningboardd p25`、`launchd p1` 全活着
  （49 档 `lsd` 还 absent），`EXIT 191 nonzero35 crash30 drop1`
- **为什么 320 MiB 一定不够**：prelink 内核 + dyld shared cache + 三个 APFS 窗全是 **wired**，
  `wire=290 MiB` 吃掉池子的 91%，`free` 直接掉到 `free_min` 以下——`sub=4` 就是这条的字面输出
- ✅ **下一闸（`ns=2 sub=5` = SIGTRAP）已归因到指令，见下面 U 步之八之二**：三发全是 `EC=0x3c`(BRK) 且 `FAR=0`
  = **件自己打的 trap**，不是缺符号；SpringBoard 那发有方法名，liveactivitiesd 那发是 Swift 强制解包 nil
- `tools-wsl/evaluate-jetsam-ram-ab.py` — 判读件：四处几何并排 + `available<=critical` 与三条门槛
  （base/idle/pressure）+ 页仪表 + 环内记录按 exit reason 归类；`--kernel` 指判读用的档名。
  环形缓冲深度是硬限制（`recent[4]`/`failures[3]` 只留最近几发，总量看 `process_exit_counts`）

### U 步之八之二：55 档三发 SIGTRAP 的指令级归因（静态反解到此为止，别再来一趟）
- **崩溃环才是 trap 级证据**：`_exit_records` 的 `crash[3]×400`@852，每行形状
  `p<pid> <name> sig<N> PC<hex> LR<hex> E<esr> F<far> +<slide> bt<帧表>`；`reason[330]`@2052 **只由 SIGABRT 路径填，
  SIGTRAP 恒空**（54/55 两档实测都空——那是语义如此，不是取数失败）
- **三发全是 `ESR.EC=0x3c`(BRK) + `FAR=0`** ⇒ 件自己打的 trap。`brk #0` = SpringBoard p162
  （`PC==LR=0x19f3df2ec`）；`brk #1` = liveactivitiesd p156/p160（同形 `PC=0x1c18f64f8 / LR=0x1c18f64cc`，
  而 `0x1c18f64cc` 本体是 `cbz x20 -> 0x1c18f64f8`，函数形状 `bl → mov x20,x0 → cbz x20 → brk #1`
  = **Swift 强制解包 nil**）；滑移恒 `+0x1d0b8000`，去滑移才是 cache 静态址
- **trap 点有名字**：`0x19f3df2ec` = FrontBoardServices `__text+0x1c534`，落在
  `-[FBSDisplayMonitor _initWithBookendObserver:transformer:]`（imp `0x19f3dee70`，`PC-imp=0x47c`）；
  调用方帧 = **`-[FBDisplayManager invalidate]`**（FrontBoard `__text+0x50114`）→ 再下面是 libdispatch 两帧 + `dyld+0x37228`。
  所以 SpringBoard 的死法是 **runloop 里 invalidate 去构造显示监视器，撞上有意打的 trap**——与屏上
  `DISPLAY: … OS display service not connected` 是同一件事的两面
- 方法名的来路（下次要别的件直接照抄）：`__objc_methlist` 相对方法列表（头 `{0xC000000F,count}`，条目 12 B rel32）
  从段首顺序走 + 「≥80% 条目 types 落全局 `__objc_methtype` 串头」筛假列表；**name 基准 = 全 cache 共用锚址
  `B=0x181d6b32c`（libobjc.A.dylib `__OBJC_RO` 段首 +4）**，types/imp 基准 = 字段自身址；类名 = `__objc_const` 里
  那枚 methlist 指针的**前一个 u64**，`RO_META_CLASS=1<<6` 定 `+`/`-` 前缀
- 🔴 **静态路线判死，别再试这两条**（u463/u464）：①整枚 `userdata-root.img`（9,382,658,048 B）只有 51 枚页对齐
  `dyld_v1   arm64\0` 头、57 条映射，**vm 上界 `0x234494000`**，件表 3354 件里 Foundation/CoreFoundation/
  libswiftCore/UIKitCore/CFNetwork/libdispatch/SwiftUI **全在**——而 trap 前那些跳板岛的终点在
  `0x2800e9b64 / 0x2800edc88 / 0x2800f1cec / 0x28159f690 / 0x28f75c6bc / 0x2b51aa4dc`，比上界还高 1.2~2.0 GB，
  **不属于这份 cache**；②LC_SYMTAB 的 `stroff/strsize` 对所有件同值（`0x14b385e0` / 56,750,964），但「文件首+off」
  「vm 基+off」两种基准前 32 枚 nlist 全不可读，已知符号串在 3.3 GB 窗内 needle 0 命中 ⇒ 符号池基准未定
- 指令判据（这轮错过一次，掩码别再抄错）：`adrp` `(w&0x9F000000)==0x90000000` 且对 `((immhi<<2)|immlo)` 做 **21 位**
  符号扩展；`add imm12` `(w&0xFFC00000)==0x91000000`（bit22=sh12）；`ldr`（unsigned offset 64 位）
  `(w&0xFFC00000)==0xF9400000` 且**立即数 = imm12×8**；`br/blr/ret` `(w&0xFFFFFC1F) ∈ {0xD61F0000,0xD63F0000,0xD65F0000}`
  （写成 `0xFFFFFFE0` 永不匹配，Rn 在 bits[9:5]）；址→文件 = `头文件址 + mapping.fileOff + (v − mapping.address)`
- `tools-wsl/evaluate-jetsam-ram-ab.py` 已扩到崩溃环：`3.5` ESR 解码 + 去滑移 + bt 帧、`3.6` reason 段、
  `4.5` 闸的交接。54/55 实测 `rc=0`：54 崩溃环 0 发、55 三发全解出（`out/probes/u465.txt`）

### V 步：上游站点、收录与设备页（口径已核对到源码，别再靠 WebFetch 猜）

`unixnu.com` 的**源就在 `UniXNU-main/docs/`**（VitePress，双语：`docs/` = en、`docs/zh/` = zh）。
`/zh/porting/` = `docs/zh/porting/index.md`（六层栈），`/zh/porting/steps` = `docs/zh/porting/steps.md`（**八步**）。

- **上游八步**：1 收集设备输入 → 2 选择共享支持 → 3 创建设备仓库 → 4 解析并检查构建配置 →
  5 准备硬件描述和固件 → 6 按依赖顺序适配驱动（平台与内存→存储→显示→输入→GPU→Wi-Fi→DSP/音频/电源）→
  7 构建并启动 → 8 完成并发布仓库
- **完成等级只有五个**（`docs/zh/porting/records.md`）：`planned / implemented / host-verified / device-verified / not-applicable`。
  **我们绝大多数证据是 `host-verified`（QEMU+Linux），真机侧只到 UEFI 菜单与内核前段屏上证据**——
  别说成 device-verified
- **umi 在上游目录里已经有了**：`devices.toml` 的 `[[device]] name="umi"` → `reAAAq/UniXNU-umi`，
  `format = 1`、`legacy_page = "preserve"`、**`revision = 3eb7257…` 正是本地那棵树的头**。
  页 = `docs/devices/umi.md` + `docs/zh/devices/umi.md`（**手写页，工作流不会覆盖 preserve 页**），
  上页报的是**那台 12 GiB/256 GB** 到 iPadOS 17.7.11 Hello/Setup + ST FTS touch（attempt 80），
  页面自己写明「完整复现仍缺本地 ABI/provenance 记录、实测 DTB、验证过的固件导入、匹配的 Apple 组件和**打包好的 Data 种子**」
  ——**这几样我们基本都做出来的**，这是最有价值的可贡献点。另有 3 个社区 fork 条目（AGXMX666 / mouya-q / neowiseq，全是「仓库链接」页）
- **收录机制**（`scripts/sync-devices.py`，工作流 `sync-devices.yml` 每天 UTC 00:00/12:00 = 北京 08:00/20:00；
  手动立刻跑：`gh workflow run sync-devices.yml --repo UniXNU/UniXNU`）。检索三条（都带 `fork:true is:public`）：
  `org:UniXNU` / `topic:unixnu` / `unixnu in:name,description`
- **新条目进不来的两道硬闸（源码实测，`sync-devices.py:165-182` / `:258-266`）**：
  ①`board.toml` 必须**同时**有 `[board].name`（匹配 `[a-z0-9][a-z0-9-]*`）**和 `[components]` 表**，
  缺任一条 `board_data()` 返 `None` 直接跳过——**reAAAq 那份 `board.toml` 恰恰没有 `[components]`**（只有 11 个段，无 schema_version）；
  ②`signature = (board.toml 的 blob oid, porting.toml 的 oid)`，与已收录条目**逐字节相同会被去重跳过**
  → 所以「原样 fork 挂上去」不会出现在页面上，至少要动 `board.toml` 一处
- **格式 2 才生成页面正文**：`board.schema_version = 2` → `format = 2`；此时工作流按固定 commit 读
  `porting.toml` 校验，`record_state` 三态 `available / invalid / missing`。非格式 2 且非 preserve 的页 = **只有 `[owner/repo](链接)` 一行**
- **`porting.toml` 校验判据的唯一出处 = `scripts/porting-record.py`**（本地可跑：
  `python3 scripts/porting-record.py check --device ../UniXNU-<dev> [--base origin/main]`，过了打印 `umi: 13 structured areas checked`）：
  `schema_version = 1`；`[device]` 的 name/soc/os_profile 必须与 `board.toml` 逐字相等；
  **13 个 area 必需**（configuration/firmware/cpu/memory/storage/display/input/gpu/network/audio/power/packaging/diagnostics）；
  每 area 的 `inputs/configuration/procedure/findings/completion/limits/next_action` **七个字段都得是非空字符串数组**（空着就报 `requires concrete entries`）、
  `paths` 必须仓库相对（禁 `/` 与 `..`）；`board.components.include` **连同 `components.toml` 的依赖闭包**必须被某些 area 的
  `components` 全覆盖（漏一个报 `components without an area`——三个 alioth 社区 fork 就死在这）；
  `evidence` 的 `reference` 只能是 **HTTPS 或仓库内已提交文件的相对路径**（`check` 会验文件真存在），
  `host`/`device` 类还必须带 `command` + **完整 40 位 commit**；`host-verified`/`device-verified` 必须有对应 kind 的证据；
  `not-applicable` 的 `components` 必须为空。CI 门 = 复制 `examples/device/.github/workflows/porting-record.yml`
  （三行 `uses: UniXNU/UniXNU/.github/workflows/porting-record.yml@main`），它跑 `--base` 那条：**每个改动的非文档文件必须归某个 area，且该 area 的 findings 或 evidence 同 PR 内要变**
- **贡献口径**（`CONTRIBUTING.md`）：仓库职责——板级策略进 `UniXNU-<device>`、SoC 公共进 `UniXNU-<soc>-common`（SM8250 那份目前是 `FFT-infra/UniXNU-sm8250-common`）、
  可复用驱动进组件仓、**构建驱动/组件目录/OS profile/模板/文档站进 UniXNU 本体**；补丁按 ARM64/SoC/OS/device/component 五序 series；
  commit 前缀 `feat|fix|docs|build|chore(<area>)` 一 commit 一主题；**文档改动 en+zh 同 PR**，新页要挂进 `config.mts` 两个 sidebar，`npm run build` 断链即失败；
  License = BSD-2-Clause-Patent
- 🔴 **两条硬红线**：①**不得提交** Apple IPSW、kernelcache、磁盘镜像、trust cache、**Data 种子**、厂商固件
  ——输入写 `proprietary-files.txt`，文件留 `.cache/firmware`（我们那枚 `.cdr` 正好在此列，`out/` 已 gitignore）；
  ②**trust cache / 代码签名 / 启动策略类缺陷私下发维护者，不开公开 issue**——我们那批 AMFI/prelink/信任缓存结论属于此类
- **同 SoC 的格式 2 范例就在本地**：`docs/.vitepress/device-records/alioth.toml`（543 行，SM8250 + 同一枚 IPSW，
  13 area 全填，`storage/packaging/diagnostics` 到 `device-verified`）——写 umi 的记录拿它当模板，别自己发明字段

### 真机（小米 10）
- `tools-win/fastboot-boot.cmd` — Windows 一键：选本地镜像 → 重启到 fastboot → `fastboot boot`（零写入）→ 1 分钟无设备自动回菜单
- `tools-wsl/collect-phone.sh` / `analyse-phone-capture.py` — 采集与判读
- 镜像与工具位置见下面「硬约束」

### 监控与进度
- `tools-wsl/launch-web.sh` — 装并后台起 8765 面板，自检 `/api/state`
- `tools-wsl/progress.sh` / `dashboard.sh` / `rawlog.sh` — 命令行侧速率、ETA、最近日志

## 产物放哪

`out/` 整目录 gitignore，不入库：`out/probes/`（取证，960+ 份）、`out/screens/`（屏照）、
`out/fixtures/`（容器件）、`out/images/`（真机档镜像）、`out/scratch/`。
临时实验放 `out/scratch/`，别往 `tools-wsl/` 根上再堆一次性脚本。

## 进度到哪了（2026-11-05）

- ✅ Linux host 工具链、host 校验、内核基线（QEMU 验过）
- ✅ umi UEFI 菜单包 + 真机 `fastboot boot` 出菜单（`MuPatches` 必须 CRLF）
- ✅ crypto kit 注册，过 `generatePlatformUUID` 的 `g_crypto_funcs` 闸
- ✅ mockfs RAM 根挂根（真机闸是漏了 `--mockfs-root`，不是驱动问题）
- ✅ EL0 走查面：23 发 syscall + Mach trap 面 9 发 + vm/port 面 4 发，真机与 QEMU 逐字节同源，拿到真 send right
- ✅ 30z：`ubc_subr.c` 两处裸 `amfi->` 补 NULL 守卫（`_amfi` 在本构建恒 NULL），二进制层 GUARD-OK
- ✅ **T 步里程碑**：`run-41-real` 里内核侧签名链全过、真 launchd 被 exec、真 dyld 跑起来
- ✅ **U 步之一**：prelink 开 storage 根，原版 APFS 在 QEMU 里 `vfs_fsadd` 返回 0（注册成功）
- ✅ **U 步之二（资格化）**：storage ABI 活体审计出 `interface-audit.json`；`NativeUfs` 绑定过
  （190 槽 / 23 覆写 / 11 真原版导入）；`storage providers` 过（AES 181 槽 + 22 条原生绑定，
  VirtIO 与 UFS 共用同一套原版类别名）→ `libNativeUfs.a` / `libNativeAES.a` / `libNativeVirtioBlock.a`
- ✅ **U 步之三（owner-root 子链结案）**：Linux 侧产出 VerifiedRoot 策略 → `audit`/`trust` 两档内核
  → QEMU `--root-volume` 只读挂真 APFS 根，官方 23 条断言 **两档各 23/23 全过**。
  屏上硬证据：`vfs_mountroot enter` → `vfs_mountroot mounted; authentication pending` → `calling VFS_ROOT`；
  18 字段里 `apple_autherr=80`(EAUTH)、`owner_decision=readonly=1`、三设备号同 `0x1000003`、
  `provider_depth=9`、`virtio 已验块 329`、audit `phase=1 accepted=0` / trust `phase=2 accepted=1`
- ✅ **U 步之四（trustcache 原件 + 38 档结案）**：Linux 侧 Range 取 `BuildManifest.plist` → 官方
  `prepare_umi_trustcache.py` 一字未改产 `original-static-system.bundle`（sha `7416ca4f…`）→
  `qemu-trustcache-runtime.macho`（sha `b11d3148…`）+ `--trust-cache --root-volume` 停
  `_query_trust_cache --finish`，**官方 `check_umi_trustcache_qemu.py` 本机直接跑出 PASS**，
  产 `out/umi/trustcache-qemu-baseline.json`（`query_return=0`、`returned_to_original_amfi=true`、
  `root_owner_accepted=true`、`user_program_load_reached=true`、`el0_execution_proved=false`）。
  屏上硬证据：`SETCONF rootdev=0x1000003 rd=disk1s1` → `vfs_mountroot mounted` → `calling VFS_ROOT` →
  `root authentication decision recorded` → `bsd_init: done` → `load_init_program enter` →
  `INIT try /sbin/launchd` → REAP 六发全 ok → `drivers 1 loaded / 0 failed`
- ✅ **原版卷取证结案（u151/u152/u154）**：OS 卷里 `dyld`/`launchd` 是实体文件，但 `libSystem.B.dylib`
  与 `com.apple.dyld` 目录**都不存在**；shared cache 明文躺在 SystemOS cryptex 窗里（`dyld_v1` 65 次命中）。
  所以「进系统」的正解是上游的 `--systemos` 档，不是往假根里塞文件
- ✅ **U 步之五（SystemOS union / dyld shared cache）**：Linux 侧 `--systemos` 档内核 → `qemu-systemos-union.macho`
  （sha `5fbddad6…`，17 件 / virtual_span 140,681,216 / owned_memory 335,544,320）→ 三窗只读盘 QEMU 取证。
  **官方 analyze 件能评的断言 15/15 全过**（`_exit_records` 那条 BLOCKED，见下），屏上
  `(no such file, no dyld cache)` 消失，`(status,authorized,native_union)=(0,1,1)`、cache 授权与 native 4K 哈希面全绿
- ✅ **U 步之五之三（screen-diagnostics 档结案，2026-11-05）**：`--gic-diagnostics --screen-diagnostics` 把
  boot-progress 链进内核（`_exit_records` 在位）+ `make-run-umi-qemu-chunked-read.py` 把那条 2382 字节的
  `m` 包拆成分段读 → **官方一站式 `analysis.json` 本机首次跑全**，本地判读件 16/16、0 条阻塞。
  `status=startup_not_yet_resolved`，`ios_ui_observed`/`phone_runtime_equivalence_proved` 恒 false（与上游一致）
- ✅ **U 步之六（`--pmgr` 档结案，2026-11-05）**：`--systemos --gic-diagnostics --screen-diagnostics --pmgr`
  四旗标同开 → `qemu-systemos-pmgr.macho`（sha `284fa323…`）→ 官方 `check_umi_pmgr_observation.py`
  **六个 mode 全 PASS**（off/lifecycle/publish/refusal/root/amfi）。硬证据：仪表 lr =
  `IOPlatformExpert::start+0x1bc`；publish 面 `stage=5 / parent_size==own_size==0x4b8a8 / attached=1 / registered=2`；
  refusal 面 `stage=0x1aa`、`status=0xe00002c7`；**amfi 面 `pc` 恰等于契约址 `0xfffffff004aaeb54` 且
  `x20==nub`、`x21==0xffffffff`**（原版 AMFI 真 retain 了我们发布的 nub）。
  深跑 `umi-pmgr=2` 里 `_panic` 一次没命中（`skipped_target_hits=0`）、`_initproc_spawned=1`，
  **官方 `analyze_umi_systemos_qemu.py` 首次给出 `launchd_main_observed: true` +
  `status: launchd_main_and_services_observed_within_bounded_run`**（`panic_recorded`/`critical_exit_recorded` 同时为真，
  native4k 面从 `36121/44/11` 跳到 `201083/5878/53`）
- ✅ **U 步之六之四（官方 screen 资格化结案，2026-11-05）**：补上 boot-arg `boot-progress=2` 之后
  `45-screen-baseline` **官方 `check_umi_screen_qemu.py` 本机首次 PASS**，产
  `out/umi/screen-qemu-baseline.json`（`status=passed_real_timed_framebuffer_diagnostics`）——
  U 步之三留到最后的一条官方 baseline 就此闭合。至此本机已有的官方资格化件：owner-root 23/23、
  trustcache PASS、pmgr 六 mode PASS、SystemOS analyze 跑全、screen baseline PASS
- ✅ **（已被 U 步之七之三打掉）上一道闸：被派生的服务退出把内核推进了「致命关键进程退出」路径**。
  屏上 `UMI PANIC tzinit[171 exited -- no exit reason available -- (signal 0, exit status 30)`，`marks=3197`；
  超时停点 `pc=_halt_all_cpus+0x34`，栈是 `_unix_syscall+0x2b0` ← `_exit+0x1c` ← `_exit_with_reason+0x1b0` ←
  `_proc_exit+0x0` → `_panic_trap_to_debugger+0x38c` → `_kdp_trap+0x20`。
  那句话本体是原版 XNU 的（`bsd/kern/kern_exit.c` 里 `p_exit_reason == OS_REASON_NULL` 分支），
  上游观测件 `zzzzzzzzzzzz-umi-critical-exit-trace.patch` 只在其前面加了 record(8)/record(9) 观测，
  注释原话「The original crash policy and panic remain unchanged, including non-init children」——
  **所以这不是 UniXNU 自己加的保险丝，是原版对 critical 作业的退出策略真触发了**
- ✅ **上一轮那条「取数通路已经就位」已兑现**：`_exit_records` 之前「全零」的真因不是没人退出，
  是 boot-progress 仪表被 `boot-progress=` boot-arg 闸在外面（见 U 步之六之四）。补上 `boot-progress=2` +
  把停点放宽到深跑后，`49-data-mac-var` 真读到了 reason 面（`EXIT 260 nonzero 111 crash 5`，
  `recent_process_exits` 全是 `xpcproxy`），诊断页那条 `SpringBoard: absent from this process pass`
  也已翻篇——`SpringBoard p26` 在进程表里
- ✅ **U 步之七（Data 种子归因结案，2026-11-05）**：`offline scratch Data mount failed: 2` 的 ENOENT 已归到
  原版 APFS 驱动 `nx_mount` 的 checkpoint 描述符校验——**`mkapfs` 造的容器压根没有描述符区**（种子全镜像 `NXSB`
  仅 2 处 vs 真 Apple 容器 45 处），64 枚槽全失败；`/private/var` 不可写就是 `tzinit` 那道闸的根。
  Linux 三条替代路（`apfs-dkms` 编不出 / `apfsprogs` 无写件 / 内核无 hfs）实测全断，
  **「干净卸载标志」支路**即使补上也只解决挂载、解决不了可写事务 → **判死，Data 种子上 Mac**（详见 U 步之七）
- ✅ **U 步之七之二（Mac↔Linux 交接件落地并自测，2026-11-05）**：`tools-mac/make-owner-data-seed-mac.sh`（Mac 造 `.cdr` + 随行 `seed.json`）
  → `tools-wsl/pack-umi-data-seed-mac.sh`（Linux 打包 + 按 build 侧三条闸自检）。真跑一遍产出的 `.json` 与既有 `data-512.json`
  逐键一致；缺 `seed.json` 时 rc=1 且不留半成品（`out/probes/u357.txt`、`u358.txt`）
- ✅ **U 步之七之三（Mac 空卷种子过闸，Data 挂载正式结案，2026-11-05）**：Mac 上 `hdiutil` 造 32 MiB 空 APFS 卷 →
  Linux 打包 → 重编 Data 档内核 → `48-data-mac-seed` 取证。**`status 2→0`、`stage=4`、`readonly=0`、
  `ram_block_ready=1`、身份三合一 PASS，官方口径 `data_mounted_writable` 本机首次为真**——
  Apple 原版驱动认 Linux 打包的 Apple 格式化容器，内容缺口不是挂载闸。
  同一档 `_exit_records` 活起来：`process_exit_counts=[19,3,0]`，失败三件 `launchd`/`MSUEarlyBootTask`/
  **`tzinit status=200 exit=2`**；`critical_exit_recorded` 转假，屏上换成 launchd 自己的
  **`userspace panic: boot task failure: tzinit - exited due to exit(2)`**（红屏，`out/screens/48-data-mac-seed.png`）
- ✅ **U 步之七之九（带内容种子过闸，跨进 iOS 用户态，2026-11-05）**：`49-data-mac-var`——
  `stage=4 readonly=0` 保持，**`native_ram_block_writes` 0 → 201**（`actual_ram_writes_observed` 本机首次为真）、
  **`panic_recorded=False`**（900 秒一次没 panic，超时停点 `_ml_get_timebase+0x18` 是空闲环读时基）、
  进程面 `19/3/0` → **`EXIT 260 nonzero 111 crash 5`**，`recent` 全是 `xpcproxy`，
  屏上 **`SpringBoard p26` / `backboardd p147` / `runningboardd p157` 真在进程表里**（`PreBoard`/`lsd` 仍 absent），
  标题换成 `LIVE: DEADLINE EXCEEDED — OS and diagnostic recording continue`。
  **U 步之七整步结案**：闸的性质已从内核变成用户态服务——新露出来的四条（`configd`/`fseventsd`/
  `containermanagerd_system` 被 SIGKILL、`watchdogd` 三发 SIGTRAP、`OS display service not connected`、
  开机期限已过）都在 `out/screens/49-data-mac-var.png` 上，详见 U 步之七末段
- ✅ **U 步之八（jetsam 击杀归因结案，2026-11-05）**：49 档那三条同形 `ns=1 sub=4`（SIGKILL）判到本体——
  `JETSAM_REASON_MEMORY_VMPAGESHORTAGE`，触发判据 `available <= critical`，门槛按 **`max_mem`** 算。
  **客存这条被 50/51 实测否掉**（`dram-size`/`-m` 抬到 2 GiB，`darwinboot-memory-size` 仍 320 MiB，jetsam 照旧）；
  **owned-memory 单变量 A/B（54=320 / 55=512，其余全同）当场打掉这道闸**：55 环内 JETSAM **7 → 0**、
  `free 129<min 266` → `626>507`、`available 17 MiB` → `69 MiB`、`counts [667,376,0]` → `[191,36,30]`、
  `native_ram_block_writes 257 → 1173`，屏上 `MEM totalMiB=512` 且 `SpringBoard p144`/`lsd p105`/`backboardd p57` 全活。
  真因是 wired 吃掉池子 91%（290/320 MiB：prelink 内核 + dyld cache + 三个 APFS 窗都是 wired）。
  **下一闸换成 `ns=2 sub=5`（SIGTRAP）三发**，且已归因到指令：三发全是 `brk`（`EC=0x3c`、`FAR=0`），
  SpringBoard 那发在 `-[FBSDisplayMonitor _initWithBookendObserver:transformer:]` 里、调用方是
  `-[FBDisplayManager invalidate]`；liveactivitiesd 那发是 Swift 强制解包 nil。详见 U 步之八之二
- ✅ **U 步之八之二（SIGTRAP 指令级归因结案，2026-11-05）**：判读件扩到 `crash[3]×400`@852 与 `reason[330]`@2052
  并真跑过（`out/probes/u465.txt`，54 崩溃环 0 发 / 55 三发全解）。`reason` 段对 SIGTRAP 恒空是语义如此。
  方法名靠 `__objc_methlist` 相对列表 + 全 cache 共用 name 锚 `B=0x181d6b32c`；**静态反解路线判死**——
  跳板岛终点落在 `0x28~0x2b` 区，比这份 cache 的 vm 上界 `0x234494000` 高 1.2~2.0 GB，而整枚 8.74 GiB 镜像
  再无第二组 `dyld_v1` 头；LC_SYMTAB 符号池基准两种试法全不可读（u461~u464）
- ℹ️ **Mac VM：现在是硬需求，别删**（本轮校准）。Linux 侧已顶掉 AEA 解密、`dwarfdump/nm`、官方 trustcache 资格化，
  但**可写 Data 种子只能由 macOS 的 `hdiutil`/`diskutil` 造**（`newfs_apfs` 才会写 checkpoint 描述符区），
  上游自己也只在 `hvf`（macOS）上资格化过这条路。**两趟都已实测**：空卷过「驱动认容器 + rw 挂 `/private/var`」，
  带 `/private/var` 骨架的 64 MiB 卷把 `tzinit` 那道闸一起带走（`49-data-mac-var`，见上）。
- ℹ️ **V 步口径已核对（2026-11-05）**：上游八步里我们 **1–5 全过、6 部分、7 host 全链过 + 真机只到菜单、8 未做**；
  **umi 页在上游站上已存在**（钉 `reAAAq/UniXNU-umi@3eb7257`，本地那棵树的头，`format=1` 手写 preserve 页，
  报的是**另一台 12 GiB** 到 Hello/Setup+touch）。要在设备页展示我们的项目 = 两条闸（`board.toml` 要有 `[components]`、
  内容不能与已收录条目逐字节相同）+ 一份能过 `porting-record.py check` 的 `porting.toml`；判据全部核对到源码，见上面 V 步


## 硬约束（用户原话级，不要重新征询）

- **装 D 盘，不要放 C**；本机 Ryzen5 6c12t/32GB，大构建放 D:
- **回复保持简短**，全程中文；结尾标明是纯汇报还是要用户动手/拍板
- **未经明确确认，不得对手机分区做任何写入/刷机**；`fastboot boot` 属零写入、已获授权
- 手机已连好，可以直接操作；需要从手机取信息也可以
- **阶段性改动推 `https://github.com/keno80/hackios-umi`**；新功能先开分支，完成后合并回 main
- **调试日志与线索不进 git**；本仓 git 身份：`keno80` / `1211582428@qq.com`
- 镜像位置 `C:\Users\admin\Desktop\phone-capture`，platform-tools 在 `E:\Android\SDK\platform-tools`
- 长任务要主动播报进度；能自测的全自己测；闭环自己做完（合并/推送直接执行，破坏性操作单独问）

## 别碰 / 别信

- `tools-wsl/attic/` — 614 份一次性探针归档，别引用、别当入口；顶层 127 项规范脚本（外加 2 份 `umi_*_tail.c`）
- `/usr/local/bin` 里除 `sync-helpers.sh` 白名单那 7 个之外的命令 — 都是早年全量快照的历史残留，改仓库脚本不会生效；要清就跑 `reboot-restore.sh --prune`
- `unixnu-logs/latest.txt` 指向的是 11-02 的失败 bootstrap 日志；最近内核构建看 `kernel-walk-latest.txt`
- `tNN-` / `sNN-` / `run-NN` 这类序号名脚本是归档命名，新脚本用「步名-语义名」（如 `make-amfi-guard-patch.py`）
- 直接编辑 `.cache/xnu-work` 下的源——构建会还原抹掉，必须落成 `patches/umi-xnu/` 补丁

## 本树踩过的码值坑（省几小时）

- `EXTERNAL_HEADERS/mach-o/loader.h`：本树 `MH_DYLINKER = 0x7`（不是常见 0x6），`LC_LOAD_DYLINKER=0xe`，`LC_CODE_SIGNATURE=0x1d`（0x1b 是 LC_UUID）
- `lc_str` 偏移**相对本条 load command 起点**，不是段首
- 代码签名结构是**网络序（大端）**；CDHash = 对第一张 CodeDirectory 的 `cdlen` 字节做摘要
- `CODE_SIGNING_MONITOR` 在本构建走 `#else` 分支 = 0（无 ppl/txm），所以 `#if CODE_SIGNING_MONITOR` 的段被编掉
- `kern_return` / Mach 返回码编号与本树一致，别按 BSD 直觉填
- **本机 QEMU 8.2.2 的 gdbstub 把 EL1 控制寄存器登记为 `SCTLR`（regnum 150），不是 `SCTLR_EL1`**；
  上游 `gdb-stop.py` 按精确名收，`MIDR_EL1` 本机也不存在 → 用 `make-gdb-stop-sctlr-observer.py`
  的别名观测件把同一个值**双写**成两个键，别改 audit 脚本的判据
- 「native 4K」三位判据实测值：`TCR_EL1=0x22a51a251a`（`>>14&3==0` 是 TG0、`>>30&3==2` 是 TG1）、
  `SCTLR_EL1=0x3454593d`（bit0=M=1）、`TTBR0=0x4c0a8000`/`TTBR1=0x4c0a9000`
- OSMetaClass 对象内 `+16 = superClassLink`、`+32 = classSize`（IOAESAccelerator 元类 classSize=`0x120`，
  IOService=`0x88`）；快照读址长度必须给 `0x50`（80 字节），audit 里 `length>=40/0x50` 两种都出现过
- **`run_umi_qemu.py --stop` 的符号名要带 Mach-O 前导下划线**（它的 `symbol()` 直接吃 `xcrun nm -n` 第 3 列原名）；
  少了下划线是 `error: missing exact kernel symbol`，且失败发生在建 run 目录之前，不会留空档挡住重跑
- `gdb-stop.json` 的 `function_return_stack_matched` / `function_entry_arguments` **只在带 `--finish-function` 时写**；
  上游 `check_umi_owner_root_qemu.py` 那两条断言在纯 `--stop` 档里必然取不到键
- `--root-volume` 不需要别名观测件：`run_umi_qemu.py` 在 `accel=="tcg"` 时自动追加 `--system-registers`，
  默认件已带 `TCR_EL1`/`TTBR0_EL1`/`SCTLR_EL1`（本机 QEMU 只有 `SCTLR` 那个登记名要双写）
- `memory` 键格式是 `<地址:#x>:<长度十六进制>`（`_umi_owner_root_observation` 的 18 个 `Q` 就是 `:90`）；
  `--read-symbol NAME:LEN` 的 LEN 直接写十六进制字节数
- `--crypto-bootstrap prelinked` 的 kernel 步把产物**直接**写成 `kernel/qemu-prelink-source-kernel.macho`
  （不是 `source-kernel.macho`，构建自己的 status JSON 里 `kernel` 字段就是它），所以每编一档覆盖一次；
  `run-umi-prelink.sh` 写死吃它 → 各档 prelink 产物 sha 不同（audit `58f2840b…` / trust `b11d3148…` /
  systemos `5fbddad6…`），**编完一档立刻 prelink + 取证**，别拿过期输入件去跑另一档
- **判内核符号在位只能用 cctools 那份 `nm`（`$TC/CommandLineTools/usr/bin/nm`）**：本机
  `/opt/unixnu-linux/CommandLineTools/usr/bin/llvm-nm` **不存在**，配 `2>/dev/null` 时 `command not found`
  被吞掉、`grep -c` 恒 0，会把「全都在」静默判成「全都缺」（`h-wait-systemos-chain.sh` 被这坑停手过一次）。
  现在该件先 `[ -x "$NM" ]` 硬闸，再打印 `nm 符号行数`，空 dump 不可能冒充结果
- **`_exit_records` 不是内核符号，是 `devices/umi/package/boot-progress/BootProgress.c` 里的 `static`**
  （`static struct bp_exits exit_records,exit_snapshot;`），只有 `--screen-diagnostics` 档才链进内核，
  而 `--screen-diagnostics` 又硬要求 `--gic-diagnostics`。所以 `--read-symbol _exit_records:…` 会让
  `run_umi_qemu.py` 在建 run 目录前就 `missing exact kernel symbol` 全档失败；官方
  `analyze_umi_systemos_qemu.py:59` 无条件读它 2382 字节
- **本机 QEMU 8.2.2 gdbstub 单发 `m` 包上限 ≈ (4096-16)/2 = 2040 字节，超了直接回 `E22`**；上游
  `gdb-stop.py` 的 `--read-memory` 把应答**原样存进 `report['memory']`**，于是那条 2382 字节的读存的是字符串
  `"E22"`，官方 analyze 件在 `bytes.fromhex` 处炸 `non-hexadecimal number found … position 3`（不是 KeyError，
  也不是内核问题）。160 B / 0x90 / 0xa0 这些短读全都正常 → 用
  `make-run-umi-qemu-chunked-read.py` 拆成上游自己的「页边界 + ≤512 字节」分段读
- **boot-progress 的 provider 清单要 `out/umi-xnu/umi/kernel/kernel.macho` 先存在**
  （`scripts/build-boot-progress.py:73`，只拿它跑 `nm -g -U -j` 取「已定义全局」），而 umi 管线从不产这个文件名
  （`prefix = ("qemu-" if profile=="qemu") + ("prelink-" if prelink_input else "") + "source-kernel.macho"`）。
  `run-kernel-systemos-screen.sh` 会从 `qemu-prelink-source-kernel.macho` 复制一份并写
  `kernel.macho.provider-inventory.json` 说明来路——**别拿它当「资格化内核」**：`--pmgr` 与 storage providers
  把同一件当**审计输入**，手抄件在那儿会真失败
- **`build-boot-progress.py:53/142` 直接点名 `/opt/homebrew/opt/llvm/bin/llvm-objdump`**（没有 env 覆盖口），
  本机根本没有 `/opt` 那棵树 → `sync-helpers.sh` 里给它装了个指向 `/usr/bin/llvm-objdump`（LLVM 18.1.3）的
  symlink shim。装之前实测过那四条大小写敏感的指令断言本机 objdump 全认（u186）
- **APFS 盘上块 0 的偏移（本轮实测，两个容器都对得上）**：`NXSB` 魔数在 `+0x20`、blocksize（4096）在 `+0x24`、
  容器 UUID 在 `+0x48..0x57`、**`nx_cksum_count`（checkpoint 描述符枚数）在 `+0x68`**。
  `mkapfs` 给 64、真 Apple 容器给 56、cryptex 给 36。别把它和内存里 `nx_mount` 读的 `[x19,#0x68]` 混为一谈
  （数值同源、语义一个盘上一个结构体）
- **判「种子容器合不合法」最便宜的一把尺子是扫块魔数**：全镜像按 4096 对齐找 `NXSB` 出现次数。
  Apple 格式化的容器每两块就有一枚 checkpoint 超块拷贝（`apfs.bin` 光 128 MiB 窗口就 45 处），
  `mkapfs` 造的只有 2 处（块 0 + 块 2 备份）→ 描述符区是空的，原版驱动必然拒（`out/probes/u336.txt`）
- **WSL2 的内核头是个空壳**：`/usr/src/linux-headers-6.18.54.1-microsoft-standard-WSL2` 里既无 `Makefile` 也无 `.config`，
  所以**任何 DKMS 外部模块（`apfs-dkms` 等）在这台机器上都编不出来**——`make -C /lib/modules/$(uname -r)/build M=… modules`
  报 `No targets specified and no makefile found`，`dkms build` 报 `kernel package … is not supported`（u351~u353）。
  要 Linux 侧内核模块就得先换标准 Ubuntu 内核镜像，别在 WSL2 定制内核上耗
- **`apfsck`（apfsprogs）没有 `-n`**，只认 `-cuvw`；`apfsprogs` 全套也没有任何往 APFS 写文件的可写通路。
  想「Linux 造出 Apple 认的容器」前先想清这条，别拿 `mkapfs` 的输出当格式等价物
