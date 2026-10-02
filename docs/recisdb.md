# recisdb

ソースツリー: [`packages/recisdb`](../packages/recisdb)

[recisdb-rs](https://github.com/kazuki0824/recisdb-rs) の decode を、rootless
脱獄 iOS 上でセルフビルドする。

## ソース

`kazuki0824/recisdb-rs` の公式 `1.3.1` タグを使う。上流
[PR #188](https://github.com/kazuki0824/recisdb-rs/pull/188) の macOS decode-only
対応が含まれるほか、macOS ARM64 リリースビルドが追加された。iOS 向けの
decode-only、`libpcsclite`、`LPTSTR` 対応は
Mayflower 側で引き続き適用する。

## パッケージ情報

- `Package:` `recisdb` / 版 1.3.1-1
- 上流の Cargo manifest は 1.3.0 のままのため、`recisdb --version` は 1.3.0 と表示する。
- Depends: `libpcsclite1`
- Recommends: `pcscd`, `px4-userland`
- バイナリ: `/var/jb/usr/bin/recisdb`（サブコマンドは `decode` のみ）

## ビルドの要点

- `vendor.tar.gz` は git 外。crates.io が端末から 403 になることがある。
- GitHub の自動 tarball は submodule を含まないので、prepare で
  `tsukumijima/libaribb25` @ `12213899` を入れる。
- cmake は Mayflower の `bin/make`（`SHELL=/var/jb/bin/sh`）。
- pcsc-lite の Apple `wintypes.h` に `LPTSTR` が無いので aribb25 側で typedef。

## 使い方

`px4d` と `pcscd` を同じユーザーで上げ、`px4-pcsc-register` したうえで:

```sh
px4-ts --device '<serial>' --runtime-dir "$rt" \
  --receiver 2 --system isdb-t --frequency-khz 557142 \
  --output - \
| recisdb decode --input - /tmp/out.ts
```
