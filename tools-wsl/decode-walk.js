const fs = require('fs');
const src = process.argv[2] || 'E:/Code/HackIos/out/probes/run27-gdb-stop.json';
const obj = JSON.parse(fs.readFileSync(src, 'utf8')).memory;
const names = ['getppid', 'gettimeofday', 'getrusage', 'open(/nonexistent)', 'open(/launchd)',
               'read', 'close', 'stat64(/dev)', 'fork_ret', 'wait4_ret'];
const nzNames = ['getppid_nz', 'gettimeofday_nz', 'getrusage_nz', 'open_none_nz', 'open_launchd_nz',
                 'read_nz', 'close_nz', 'stat64_nz', 'fork_nz', 'wait4_nz'];
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
for (const [addr, hex] of Object.entries(obj)) {
  console.log('==== ' + addr + ' (' + hex.length / 2 + ' bytes) ====');
  const v = u64s(hex);
  const base = parseInt(addr.split(':')[0], 16);
  const isNz = base === 0x1000040c0;
  v.forEach((x, i) => {
    const label = isNz ? (nzNames[i] || '?') : (names[i] || '?');
    const s = x.toString();
    const signed = x > 0x7fffffffffffffffn ? (x - (1n << 64n)).toString() : s;
    console.log(String(i).padStart(2) + ' +' + (i * 8).toString(16).padStart(3, '0') +
      '  ' + label.padEnd(14) + ' = ' + s.padStart(21) + '  (0x' + x.toString(16) + ')' +
      (signed !== s ? '  signed=' + signed : ''));
  });
}
