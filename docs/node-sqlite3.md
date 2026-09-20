# node-sqlite3

ソースツリー: [`packages/node-sqlite3`](../packages/node-sqlite3)

npm の [`sqlite3`](https://github.com/TryGhost/node-sqlite3) をパッケージングする。
Procursus の `sqlite3`（CLI）および `libsqlite3-1` とは別物。

## パッケージ情報

- 版: 5.1.7-1
- パッケージ: `nodejs-sqlite3`
- 入れる先: `/var/jb/usr/lib/nodejs-24/node_modules/sqlite3`
- Depends: `nodejs-24`
- PATH にコマンドは出さない（Mach-O ラッパー不要）

`require("sqlite3")` は TypeORM / EPGStation が使う N-API 拡張
（`node_sqlite3.node`）を `dlopen` する。`sqlite3` コマンドも
`libsqlite3.dylib` も呼ばない。

Node の `globalPaths` は `node-bin` が `.../nodejs-24/` 直下にある都合で
`/usr/lib/lib/node` を見に行く。このパッケージは node 実体の隣の
`node_modules` に置く。任意のカレントから読むときは
`NODE_PATH=/var/jb/usr/lib/nodejs-24/node_modules` を付ける。

## 建て方とパッケージング

**端末の上で建てない。** `npm i sqlite3` の `prebuild-install` は
`darwin-arm64` を macOS と取り、`binding.gyp` は
`MACOSX_DEPLOYMENT_TARGET=10.7` を焼く。

Mac でのクロスビルドは [`tools/mac/node-sqlite3/build.sh`](../tools/mac/node-sqlite3/build.sh)。
clang ラッパーは Node と同じ `~/ios-tools`。SDK は Xcode の iPhoneOS。
ヘッダは nodejs.org の `node-v24.21.0-headers.tar.gz`。

パッチは `packages/node-sqlite3/patches-host/` にあり、母艦側で適用するため
`make.sh` の `applyPatch` の対象には含めない。

端末側では `SQLITE3_DIST_DIR` に tarball の場所を渡して実行する:

```sh
SQLITE3_DIST_DIR=/path/to/dist ./make.sh node-sqlite3
sudo dpkg -i packages/node-sqlite3/arm64/nodejs-sqlite3_*.deb
```

## 端末上での確認

```sh
cd /var/jb/usr/lib/nodejs-24
node -e "const s=require('sqlite3'); const d=new s.Database(':memory:'); d.get('select 1 as x', (e,r)=>{ if (e) throw e; console.log(r); d.close(); })"
```
