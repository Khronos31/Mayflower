'use strict';
const assert = require('assert');
const path = require('path');
const sqlite3 = require('sqlite3');

assert.ok(sqlite3.Database, 'sqlite3.Database');
const db = new sqlite3.Database(':memory:');
db.serialize(() => {
  db.run('CREATE TABLE t (x INTEGER)');
  db.run('INSERT INTO t VALUES (?)', 7);
  db.get('SELECT x FROM t', (err, row) => {
    assert.ifError(err);
    assert.strictEqual(row.x, 7);
    db.close((cerr) => {
      assert.ifError(cerr);
      console.log('node-sqlite3', sqlite3.VERSION || path.basename(__dirname), 'ok');
    });
  });
});
