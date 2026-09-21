# epgstation

ソースツリー: [`packages/epgstation`](../packages/epgstation)

[EPGStation](https://github.com/l3tnun/EPGStation) 2.10.0 をパッケージングする。

## パッケージ情報

- 版: 2.10.0-2
- パッケージ: `epgstation`
- コード: `/var/jb/usr/lib/epgstation`
- データ: `/var/jb/var/lib/epgstation`（`data` / `recorded` / `logs` / `thumbnail` / `drop` / `config.yml`）
- PATH: `epgstation`（Mach-O。`node-bin --jitless`。引数が無ければ `dist/index.js`、あればそれを渡す。子プロセスの `spawn(argv[0], …)` 用）
- Depends: `nodejs-24`, `nodejs-sqlite3`

ffmpeg が無くても起動する。無変換ライブと生 TS 録画は ffmpeg を呼ばない。
変換・サムネは `/var/jb/usr/bin/ffmpeg` を使う（Procursus の ffmpeg 5.1.2 には
`-dual_mono_mode` が無い）。

既定の `mirakurunPath` は `http://127.0.0.1:40772/`。unix socket ではない。
mirakc が向こうで応答するまで、上流どおり接続待ちでループする。

## 建て方

**端末の上で `npm i` しない。** JS のコンパイルは Mac。

```sh
# Mac
$MAYFLOWER/tools/mac/epgstation/build.sh

# 端末
EPGSTATION_DIST_DIR=/path/to/dist ./make.sh epgstation
sudo dpkg -i packages/epgstation/arm64/epgstation_*.deb
```

sqlite3 の `.node` は payload に入れない。`nodejs-sqlite3` へのリンク。

子プロセス（Service / EPG updater）は `process.execPath`（`node-bin`）へ `--jitless` 付きで spawn する。`argv[0]` のラッパを spawn すると、IPC の相手が Node になる前に切れる。

`--jitless` では undici の `fetch` が WebAssembly を要求して落ちる。mirakc 向けの
`/api/services/:id/programs` は `http.get` に差し替えてある。

## 端末上での実行

mobile で `epgstation`。root で上げると上流が `video` グループへ `setgid` しようとする。

設定は `/var/jb/var/lib/epgstation/config.yml`。パッケージを入れ直しても、既にあるファイルは postinst が上書きしない。
