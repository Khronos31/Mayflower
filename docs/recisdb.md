# recisdb

ソースツリー: [`packages/recisdb`](../packages/recisdb)

[recisdb-rs](https://github.com/kazuki0824/recisdb-rs) の decode を、rootless
脱獄 iOS 上でセルフビルドする。

## ピン留め

いまの `source` は **Khronos31/recisdb-rs**
`badc171f15bb010b972740c17a92cfe0cbfe8584`（上流
[PR #188](https://github.com/kazuki0824/recisdb-rs/pull/188) の fork）。
Cargo の版表示は 1.2.4 のまま。

公式がその PR をマージして **次のリリースタグ** を出したら、`make.sh` の
`source` を

```
https://github.com/kazuki0824/recisdb-rs/archive/refs/tags/vX.Y.Z.tar.gz
```

に差し替える。iOS 向けパッチ（decode-only、`libpcsclite`、`LPTSTR`）は残す。

## パッケージ情報

- `Package:` `recisdb` / 版 1.2.4-1
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
