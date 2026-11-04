const fs = require('fs');
const src = process.argv[2] || 'E:/Code/HackIos/out/probes/run28-gdb-stop.json';
const obj = JSON.parse(fs.readFileSync(src, 'utf8')).memory;
// 槽位序 = walk-user.S 里 str x0,[x19,#N] 的顺序，凭记忆写必错
const names = ['getppid', 'gettimeofday', 'getrusage', 'open(/nonexistent)', 'open(/launchd)',
               'read(/launchd)', 'close', 'stat64(/dev)', 'fork_ret', 'wait4_ret',
               'pipe(rfd)', 'write(pipe)', 'read(pipe)', 'dup2', 'fcntl(F_GETFD)',
               'mmap', 'mprotect', 'madvise', 'munmap', 'kqueue', 'kevent', 'issetugid', 'umask'];
const nzNames = names.map((n) => n + '_nz');
const EXEC_MARK = 0x100n;  // 件里 orr x9,x9,#0x100：返回 0 的调用也能和「没跑到」区分
function u64s(hex) {
  const out = [];
  for (let i = 0; i + 16 <= hex.length; i += 16) {
    const chunk = hex.slice(i, i + 16);
    let v = 0n;
    for (let j = 14; j >= 0; j -= 2) v = (v << 8n) | BigInt('0x' + chunk.slice(j, j + 2));
    out.push(v);
  }
  return out;
}
// gdb 侧会按对齐多回吐几个字节，键里声明的长度才是我们要的范围，多出来的全是隔壁数据
const blocks = Object.entries(obj).map(([addr, raw]) => {
  const want = parseInt(addr.split(':')[1], 10);
  const hex = Number.isFinite(want) ? raw.slice(0, want * 2) : raw;
  return { addr, hex, base: parseInt(addr.split(':')[0], 16), v: u64s(hex) };
});
const isNzBase = (b) => b === 0x100004140 || b === 0x1000040c0;
const walk = blocks.find((b) => !isNzBase(b.base));
const nz = blocks.find((b) => isNzBase(b.base));

for (const b of blocks) {
  console.log('==== ' + b.addr + ' (' + b.hex.length / 2 + ' bytes) ====');
  const isNz = isNzBase(b.base);
  b.v.forEach((x, i) => {
    const label = (isNz ? nzNames[i] : names[i]) || (i >= names.length ? '（未用）' : '?');
    const s = x.toString();
    const signed = x > 0x7fffffffffffffffn ? (x - (1n << 64n)).toString() : s;
    console.log(String(i).padStart(2) + ' +' + (i * 8).toString(16).padStart(3, '0') +
      '  ' + label.padEnd(20) + ' = ' + s.padStart(21) + '  (0x' + x.toString(16) + ')' +
      (signed !== s ? '  signed=' + signed : ''));
  });
}

// 走到多深：有标记位就按标记位；老件（run-27/28）没标记位，退回「写过非零」的近似口径
const hasMark = nz && nz.v.some((x) => (x & EXEC_MARK) !== 0n);
let deepest = -1;
for (let i = 0; i < names.length; i++) {
  const w = walk && walk.v[i];
  const n = nz && nz.v[i];
  if (w === undefined || n === undefined) break;
  const ran = hasMark ? (n & EXEC_MARK) !== 0n : (w !== 0n || n !== 0n);
  if (ran) deepest = i;
}
console.log('最深槽位: ' + (deepest >= 0 ? deepest + ' ' + names[deepest] : '（一个都没写）') +
  (hasMark ? '' : '  [老件无 executed 位，口径偏保守]'));
