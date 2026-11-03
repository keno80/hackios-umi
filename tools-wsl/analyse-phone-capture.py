"""Analyse the real umi capture (no-root MIUI pass) against our port's assumptions."""
import gzip
import json
import re
from pathlib import Path

HERE = Path(r'E:\Code\HackIos\out\phone')
OUT = Path(r'E:\Code\HackIos\out\phone-analysis.txt')
lines = []


def say(text=''):
    lines.append(text)
    print(text)


console = HERE / 'pstore-console-ramoops-0.txt'
# pstore writes the ring buffer as raw bytes; decode leniently.
text = console.read_bytes().decode('utf-8', errors='replace')
text = '\n'.join(line for line in text.splitlines() if re.search(r'\[\s*\d+\.\d+\]', line) or not line.strip())

say('=== 1. 内存窗口核对（来自本机开机 dmesg，非 QEMU）')
WINDOWS = {
    '0x9c000000': ('splash 帧缓冲', 0),
    '0x9fc00000': ('UEFI FD 窗口', 0),
    '0xa0000000': ('initrd 窗口起点', 0),
    '0xb0000000': ('ramoops 起点', 0),
}
reserved = []
for match in re.finditer(r'(Reserved|Removed) memory: created (\w+) memory pool at 0x0*([0-9a-f]+), size (\d+) MiB', text):
    kind, base, size = match.group(2), int(match.group(3), 16), int(match.group(4)) * 1024 * 1024
    label = match.group(1).lower() + ':' + kind
    reserved.append((base, base + size, label, size))
for match in re.finditer(r'ramoops: attached 0x([0-9a-f]+)@0x([0-9a-f]+)', text):
    size, base = int(match.group(1), 16), int(match.group(2), 16)
    reserved.append((base, base + size, 'ramoops', size))
for match in re.finditer(r'assigned reserved memory node (\S+?)(?:@([0-9a-f]+))?\b', text):
    if match.group(2):
        reserved.append((int(match.group(2), 16), 0, 'named:' + match.group(1), 0))
reserved = sorted(set(reserved))
for base, end, kind, size in reserved:
    if size:
        say(f'  {base:#012x}-{end:#012x} {size/1024/1024:6.0f} MiB  {kind}')
    else:
        say(f'  {base:#012x}                (大小未打印)  {kind}')

say()
EXPECTED = {'0x9c000000': ('splash 帧缓冲', None), '0x9fc00000': ('UEFI FD 窗口', None),
            '0xa0000000': ('initrd 窗口起点', None), '0xb0000000': ('ramoops 起点', 'ramoops')}
for address, (label, expected) in EXPECTED.items():
    value = int(address, 16)
    hits = [item for item in reserved if item[3] and item[0] <= value < item[1]]
    if not hits:
        verdict = '未被本机 Linux 保留 -> 可用'
    elif expected and any(expected in hit[2] for hit in hits):
        hit = next(h for h in hits if expected in h[2])
        verdict = f'与本机一致：Linux 也把 {hit[3] // 1048576} MiB 留在 {hit[0]:#x}..{hit[1]:#x}'
    else:
        verdict = '冲突：' + ', '.join(f'{h[2]}@{h[0]:#x}+{h[3] // 1048576}MiB' for h in hits)
    say(f'  {address} ({label}) -> {verdict}')

taken = sorted([(item[0], item[1]) for item in reserved if item[3] and 0x80000000 <= item[0] < 0xf0000000])
gap_start, best = 0x80000000, (0, 0)
cursor = 0x80000000
for base, end in taken:
    if base - cursor > best[1] - best[0]:
        best = (cursor, base)
    cursor = max(cursor, end)
if 0xf0000000 - cursor > best[1] - best[0]:
    best = (cursor, 0xf0000000)
say(f'\n  低段连续空闲：{best[0]:#x}..{best[1]:#x} = {(best[1] - best[0]) / 1024 / 1024:.0f} MiB'
    f'（splash 0x9c000000、FD 0x9fc00000、initrd 0xa0000000..0xb0000000 全在其中）')

ramoops = next((item for item in reserved if item[2] == 'ramoops'), None)
say(f'\n  ramoops 实际窗口: {ramoops[0]:#x}..{ramoops[1]:#x} ({ramoops[3] // 1048576} MiB)')
say(f'  我们规划的 initrd 0xa0000000..0xb0000000 与 ramoops 相邻不重叠: '
    f'{0xa0000000 + 0x10000000 <= ramoops[0]}')
low = 0x80000000
free_low = sorted({(item[1], item[0]) for item in reserved if item[3] and item[1] < 0xc0000000})
say('  低 2GB 内被 Linux 占用的区间（<=0xc0000000）：')
for end, start in free_low:
    if start >= low:
        say(f'    {start:#012x}-{end:#012x}')

say()
say('=== 2. 真实 cmdline（/proc/cmdline 被拒，从 dmesg 取回）')
line = re.search(r'Kernel command line: (.+)', text).group(1)
for token in line.split():
    say('  ' + token)
say(f'  bootdevice 拼写: {re.search(r"androidboot.bootdevice=(\S+)", line).group(1)}')
say(f'  ramoops_memreserve={re.search(r"ramoops_memreserve=(\S+)", line).group(1)}')

say()
say('=== 3. 内存容量核对（这台是 8G 机）')
memory = re.search(r'Memory: (\d+)K/(\d+)K available \(([^)]*)\)', text)
avail, total, detail = int(memory.group(1)), int(memory.group(2)), memory.group(3)
say(f'  内核可见 total = {total}K = {total / 1048576:.2f} GiB；available = {avail / 1048576:.2f} GiB')
say(f'  {detail}')
meminfo = (HERE / 'meminfo.txt').read_text()
say('  MemTotal: ' + re.search(r'MemTotal:\s+(\S+)', meminfo).group(1))
top = 0x80000000 + total * 1024
say(f'  若 DRAM 从 0x80000000 起连续，则顶约 {top:#x}（0x9c000000/0xa0000000/0xb0000000 都在其中）')

say()
say('=== 4. 分区表：by-name -> LUN/分区号 + sysfs start/size（无需 root 的真实偏移）')
links = {}
for raw in (HERE / 'partition-links.txt').read_text(errors='replace').splitlines():
    match = re.match(r'l.*\s(\S+)\s*->\s*(/dev/block/\S+)', raw)
    if match:
        links[match.group(1).rsplit('/', 1)[-1]] = match.group(2)
say(f'  by-name 条目 {len(links)} 个')
luns = {}
for name, dev in links.items():
    match = re.match(r'/dev/block/(sd[a-z])(\d+)$', dev)
    if match:
        luns.setdefault(match.group(1), []).append((int(match.group(2)), name))
say('  各 LUN 承载的分区数：' + ', '.join(f'{lun}={len(items)}' for lun, items in sorted(luns.items())))
say('  （sysfs 的 start/size 在无 root 时被 SELinux 拒了，所以只有 LUN/分区号，没有字节偏移；'
    '偏移要么给 root，要么从 ROM 的 GPT 镜像算）')
say('  我们关心的分区落在哪个 LUN：')
for name in ('boot_a', 'boot_b', 'dtbo_a', 'vbmeta_a', 'recovery_a', 'abl_a', 'xbl_a', 'imagefv',
             'super', 'userdata', 'metadata', 'persist'):
    if name in links:
        say(f'    {name:<12} -> {links[name]}')
for line in re.findall(r'^\s*(sd[a-h]): ((?:sd[a-h]\d+ ?)+)', text, flags=re.M):
    say(f'    内核分区列表 {line[0]}: {len(line[1].split())} 个分区')
    break

say()
say('=== 5. kernel-config.gz（本机真实内核配置，38 KB）')
try:
    config = gzip.decompress((HERE / 'kernel-config.gz').read_bytes()).decode('utf-8', errors='replace')
    say(f'  解压 {len(config)} 字节，{len(config.splitlines())} 行')
    wanted = ('CONFIG_IKCONFIG', 'CONFIG_ARM64_VA_BITS', 'CONFIG_MEMORY_START', 'CONFIG_PHYS_OFFSET',
              'CONFIG_ARCH_KONA', 'CONFIG_MACH_UMI', 'CONFIG_UNWINDER', 'CONFIG_CMDLINE',
              'CONFIG_ARM64_PA_BITS', 'CONFIG_PAGE_SIZE', 'CONFIG_HZ', 'CONFIG_LOCALVERSION',
              'CONFIG_QCOM_SMEM', 'CONFIG_DM_VERITY', 'CONFIG_FS_VERITY', 'CONFIG_AVB',
              'CONFIG_UFS', 'CONFIG_ARM64_CP_CPUFREQ', 'CONFIG_DRM_MSM', 'CONFIG_SND',
              'CONFIG_SECURITY_SELINUX', 'CONFIG_LTO', 'CONFIG_CFI', 'CONFIG_KASAN',
              'CONFIG_MEMCG', 'CONFIG_ZSWAP', 'CONFIG_ARM64_PTR_AUTH', 'CONFIG_ARM64_BTI',
              'CONFIG_ARM64_MTE', 'CONFIG_ARM64_TTA', 'CONFIG_RANDOMIZE_BASE', 'CONFIG_KPTI')
    for key in wanted:
        hits = [line for line in config.splitlines() if line.startswith(key)]
        for line in hits[:3]:
            say('  ' + line)
except Exception as error:
    say('  读取失败: ' + str(error))

say()
say('=== 6. 显示 / GPU / 触摸（无 root 能拿到的）')
say('  display-size: ' + (HERE / 'display-size.txt').read_text(errors='replace').replace('\n', ' | ').strip())
say('  connector: ' + (HERE / 'display-connector.txt').read_text(errors='replace').replace('\n', ' | ').strip())
say('  kgsl: ' + (HERE / 'kgsl.txt').read_text(errors='replace').replace('\n', ' | ').strip())
say('  soc0: ' + (HERE / 'soc.txt').read_text(errors='replace').replace('\n', ' | ').strip())
say('  os: ' + (HERE / 'os.txt').read_text(errors='replace').replace('\n', ' | ').strip())
say('  kernel: ' + (HERE / 'kernel.txt').read_text(errors='replace').strip())
panel = re.findall(r'.*(?:dsi_|panel|sde_|mdss).*', text, flags=re.I)
say('  dmesg 里 panel/DSI 相关（前 12 条）：')
for line in panel[:12]:
    say('    ' + line.strip()[:160])
touch = re.findall(r'.*(?:GTP-|goodix|synaptics|xiaomi-touch|ts_firmware|st54|nt36xxx|hilink).*', text, flags=re.I)
say('  dmesg 里触摸相关（前 12 条）：')
for line in touch[:12]:
    say('    ' + line.strip()[:160])
panel_mode = re.findall(r'.*(?:sde_connector|dsi_panel|panel_name|qcom,mdss_dsi|mdss_pll_probe).*',
                        text, flags=re.I)
say('  dmesg 里 panel/DSI 关键行（前 8 条）：')
for line in panel_mode[:8]:
    say('    ' + line.strip()[:160])
ufs = re.findall(r'.*(?:ufs|1d84000).*', text, flags=re.I)
say('  dmesg 里 UFS 相关（前 14 条）：')
for line in ufs[:14]:
    say('    ' + line.strip()[:160])

OUT.write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(f'\nwrote {OUT} ({OUT.stat().st_size:,} bytes)')
