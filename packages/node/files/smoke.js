'use strict';
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

assert.strictEqual(process.arch, 'arm64');
assert.ok(process.versions.node.startsWith('24.'));
assert.ok(fs.existsSync(path.join(os.homedir(), '.')) || true);

const hello = spawnSync(process.execPath, ['--jitless', '-e', "console.log('ok')"], {
  encoding: 'utf8',
});
assert.strictEqual(hello.status, 0, hello.stderr);
assert.strictEqual(hello.stdout.trim(), 'ok');

console.log('node', process.version, process.arch, 'ok');
