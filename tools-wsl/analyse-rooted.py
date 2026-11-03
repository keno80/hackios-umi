"""Cross-check the rooted umi capture against the addresses our UEFI/XNU port hard-codes."""
import re
from pathlib import Path

D = Path(r'E:\Code\HackIos\out\phone2')
OUT = Path(r'E:\Code\HackIos\out\phone2-analysis.txt')
lines = []


def say(text=''):
    lines.append(text)


def cells(node_text, parent_props, which):
    default = {'#address-cells': 2, '#size-cells': 1}
    return default[which]


dts = (D / 'running.dts').read_text(errors='replace')


def quads(text):
    values = [int(v, 16) for v in re.findall(r'0x[0-9a-f]+', text)]
    return [((values[i] << 32) + values[i + 1], (values[i + 2] << 32) + values[i + 3])
            for i in range(0, len(values) - 3, 4)]


say('=== 1. /memory 节点（这台 8G 机的物理内存窗口）')
mem_node = re.search(r'^\tmemory \{(.*?)^\t\};', dts, re.S | re.M)
for start, size in quads(re.search(r'reg = <([^>]*)>', mem_node.group(1)).group(1)):
    say(f'  {start:#012x} .. {start + size - 1:#012x}  ({size / 1024 ** 3:.2f} GiB)')

say()
say('=== 2. /reserved-memory 全部条目')
block = re.search(r'reserved-memory \{(.*?)\n\t\};', dts, flags=re.S)
regions = []
if block:
    for node in re.finditer(r'^\t\t([A-Za-z0-9_,.@-]+)(?:@[0-9a-f]+)? \{(.*?)^\t\t\};',
                            block.group(1), flags=re.S | re.M):
        reg = re.search(r'reg = <([^>]+)>', node.group(2), flags=re.S)
        if not reg:
            continue
        for start, size in quads(reg.group(1)):
            regions.append((start, size, node.group(1).split('@')[0]))
regions = sorted(set(regions))
low = [(s, z, n) for s, z, n in regions if s < 0x100000000]
for start, size, name in low:
    say(f'  {start:#012x} .. {start + size - 1:#012x}  {size / 1024 / 1024:8.1f} MiB  {name}')
say(f'  （低 4GB 内 {len(low)} 条，总计 {sum(z for _, z, _ in low) / 1024 / 1024:.0f} MiB）')

say()
say('=== 3. 我们端口里写死的地址，逐个判定')
iomem = (D / 'iomem.txt').read_text(errors='replace')
ram, iomem_reserved = [], []
for raw in iomem.splitlines():
    match = re.match(r'\s*([0-9a-f]+)-([0-9a-f]+) : (.*)$', raw)
    if not match:
        continue
    span = (int(match.group(1), 16), int(match.group(2), 16) + 1)
    if span[0] >= 1 << 32:
        continue
    label = match.group(3).strip()
    if label == 'System RAM':
        ram.append(span)
    elif label == 'reserved':
        iomem_reserved.append(span)


def classify(start, end):
    hits = [(s, z, n) for s, z, n in regions if s < end and z and s + z > start]
    in_ram = [a for a, b in ram if a < end and b > start]
    in_res = [a for a, b in iomem_reserved if a < end and b > start]
    return hits, in_ram, in_res


WINDOWS = [
    ('splash 帧缓冲', 0x9C000000, 0x9C000000 + 0x00F00000),
    ('UEFI FD 窗口', 0x9FC00000, 0x9FC00000 + 0x00100000),
    ('initrd 窗口', 0xA0000000, 0xB0000000),
    ('ramoops', 0xB0000000, 0xB0400000),
]
for label, start, end in WINDOWS:
    hits, in_ram, in_res = classify(start, end)
    same_base = [n for s, z, n in hits if s == start]
    if same_base:
        verdict = f'本机 DT 里就是 {same_base[0]}（同基址，容量 {max(z for s, z, n in hits) / 1048576:.0f} MiB）'
    elif in_res:
        verdict = 'iomem 标 reserved: ' + ', '.join(f'{a:#x}' for a in in_res)
    elif hits:
        verdict = '冲突: ' + ', '.join(f'{n}@{s:#x}+{z // 1048576}MiB' for s, z, n in hits[:4])
    else:
        verdict = 'DT 未保留，可用'
    say(f'  {label} {start:#x}..{end - 1:#x} -> {verdict}')
    say(f'      iomem: System RAM 命中 {len(in_ram)} 段, reserved 命中 {len(in_res)} 段')

say()
say('  低 4GB 内最大连续空闲段（扣除 DT 保留 + iomem reserved）：')
blocked = sorted([(s, s + z) for s, z, n in regions if s < (1 << 32)] + iomem_reserved +
                 [(0x80000000, 0x80000000)])
cursor, gaps = 0x80000000, []
for start, end in sorted(blocked):
    if start > cursor:
        gaps.append((cursor, start))
    cursor = max(cursor, end)
for start, end in sorted(gaps, key=lambda p: p[1] - p[0], reverse=True)[:5]:
    say(f'    {start:#010x} .. {end - 1:#010x}  {(end - start) / 1048576:7.1f} MiB 空闲')

say()
say('=== 4. /proc/iomem 低段 System RAM / reserved 分段')
for line in iomem.splitlines():
    if re.match(r'\s*[0-9a-f]+-[0-9a-f]+ : (System RAM|reserved)\s*$', line):
        say('  ' + line.strip())

say()
say('=== 5. 真实 cmdline')
cmdline_text = (D / 'cmdline.txt').read_text(errors='replace').strip()
say('  ' + cmdline_text)

say()
say('=== 6. chosen / cmdline 在 DT 里的样子')
for match in re.finditer(r'chosen \{(.*?)\n\t\};', dts, flags=re.S):
    for line in match.group(1).splitlines():
        if line.strip():
            say('  ' + line.strip()[:200])

say()
say('=== 7. 分区真实偏移（by-name -> LUN:分区号 + sysfs start/size）')
links = {}
for raw in (D / 'partition-links.txt').read_text(errors='replace').splitlines():
    match = re.match(r'l.*\s(\S+)\s*->\s*(/dev/block/(sd[a-z])(\d+))$', raw.strip())
    if match:
        links[match.group(1)] = (match.group(2), match.group(3), int(match.group(4)))
say(f'  by-name 条目 {len(links)}')
raw_text = (D / 'block-sizes.txt').read_text(errors='replace')
nodes = {}
for chunk in re.split(r'NODE /sys/class/block/', raw_text)[1:]:
    dev = chunk.split()[0]
    info = {}
    for key in ('START_512', 'SIZE_512', 'CAP', 'LOGICAL_BLOCK_BYTES'):
        found = re.search(key + r'\s+(\d+)', chunk)
        if found:
            info[key] = int(found.group(1))
    found = re.search(r'DEVTYPE=(\S+)', chunk)
    if found:
        info['DEVTYPE'] = found.group(1)
    nodes[dev] = info
say(f'  sysfs 块 {len(nodes)} 个，其中有 start 的 {sum(1 for v in nodes.values() if "START_512" in v)} 个')
rows = []
for name, (dev, lun, index) in links.items():
    info = nodes.get(f'{lun}{index}', {})
    if 'START_512' in info and 'SIZE_512' in info:
        rows.append((name, f'{lun}{index}', info['START_512'] * 512, info['SIZE_512'] * 512))
KEY = ('boot', 'recovery', 'vbmeta', 'vbmeta_system', 'vbmeta_vendor', 'dtbo', 'abl',
       'xbl', 'xbl_config', 'imagefv', 'tz', 'hyp', 'super', 'userdata', 'metadata',
       'persist', 'misc', 'modem', 'vendor_boot', 'init_boot')


def lun_of(dev):
    found = re.match(r'sd([a-z])\d+$', dev)
    return found.group(1) if found else '?'


say(f'  可算出偏移的 {len(rows)} 个，重点分区：')
for name, dev, off, size in sorted(rows):
    if re.sub(r'_[ab]$', '', name) in KEY:
        human = f'{size / 1024 / 1024:9.1f} MiB' if size < 1024 ** 3 else f'{size / 1024 ** 3:6.2f} GiB'
        say(f'    {name:<16} {dev:<7} LUN{lun_of(dev)} off {off:>16,} ({off:#x})  {human}')
for lun in sorted({lun_of(d) for _, d, _, _ in rows}):
    spans = [(off, off + size) for _, d, off, size in rows if lun_of(d) == lun]
    if spans:
        say(f'    LUN {lun}: {len(spans)} 个分区, 覆盖 {min(s for s, _ in spans):,} .. '
            f'{max(e for _, e in spans):,} ({max(e for _, e in spans) / 1024 ** 3:.2f} GiB)')

say()
say('=== 8. 触摸 / 显示 / GPU / UFS 的真实名字')
say('  touch-sysfs: ' + (D / 'touch-sysfs.txt').read_text(errors='replace').replace('\n', ' | ')[:400])
say('  input-devices 前 6 行:')
for line in (D / 'input-devices.txt').read_text(errors='replace').splitlines()[:12]:
    say('    ' + line[:160])
say('  dts 里的 qcom,mdss_dsi_* panel 兼容名（去重）:')
for name in sorted(set(re.findall(r'qcom,mdss_dsi_[a-z0-9_]+', dts)))[:25]:
    say('    ' + name)
panel = re.search(r'msm_drm\.dsi_display0=(\S+)', cmdline_text)
say('  cmdline 里本机实际选中的 panel: ' + (panel.group(1) if panel else '未找到'))
say('  dts 里的 UFS 控制器:')
for match in re.finditer(r'^\s*(ufshc[a-z_]*@[0-9a-f]+) \{', dts, flags=re.M):
    say('    ' + match.group(1))
say('  kgsl/fb 读取失败原因见 manifest（多为 debugfs/权限）')

OUT.write_text('\n'.join(lines) + '\n', encoding='utf-8')
print('\n'.join(lines))
print(f'\n[written {OUT}]')
