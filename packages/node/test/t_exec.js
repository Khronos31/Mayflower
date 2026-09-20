'use strict';
const { execFileSync, execSync, spawnSync } = require('child_process');

console.log('hello from node');
const sh = execSync('echo exec_sh_c ok', { encoding: 'utf8' });
process.stdout.write(sh);

const file = spawnSync('./t.sh', { encoding: 'utf8' });
process.stdout.write(file.stdout || '');
console.log('spawnSync rc=', file.status);
if (file.status !== 0) {
  process.stderr.write(file.stderr || '');
  process.exit(1);
}

const ex = execFileSync('./t.sh', { encoding: 'utf8' });
process.stdout.write(ex);
console.log('execFileSync ok');
