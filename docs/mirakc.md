# mirakc

ソースツリー: [`packages/mirakc`](../packages/mirakc)

[mirakc](https://github.com/mirakc/mirakc) — Mirakurun 互換の録画バックエンド。

## パッケージ情報

- 版: 3.4.86
- パッケージ: `mirakc`
- ビルド: **端末**（Mayflower `rustc` 1.98 / `cargo`、`vendor.tar.gz` で `--offline`）
- ソース: GitHub タグ tarball（`mirakc/mirakc` `3.4.86`）
- ビルド対象: `-p mirakc` のみ（`mirakc-timeshift-fs` / FUSE は建てない）
- vergen: tarball に `.git` が無いので `VERGEN_DEFAULT_ON_ERROR=1`、および
  `patches/0001-vergen-default-on-error.patch`（`Emitter::default_on_error()`）
- Procursus: 無し（新規）

## 端末

```sh
sudo apt install rust-default   # rustc-1.98 / cargo-1.98
./make.sh mirakc
sudo apt install ./packages/mirakc/arm64/mirakc_*.deb
mirakc --version
```

`vendor.tar.gz` は Mac で `cargo vendor --locked` したもの（約 33MB）。crates.io が端末から
403 になることがあるため同梱する。作業一時ディレクトリは `$HOME/tmp`
（jb の `/tmp` は SIGKILL されやすい）。`CARGO_BUILD_JOBS=1` 推奨。

## 注意

- チューナー用ヘルパー（`recpt1` 等）は同梱しない。別途用意すること。
- timeshift FUSE（`mirakc-timeshift-fs`）は iOS 向けに建てていない。

## 端末ツールチェーン注意

`/var/jb/usr/bin/cargo` と `rustc` は実体への shell ラッパー。`cargo` がラッパー経由で
`rustc` を `posix_spawn` すると iOS で EPERM になることがある。`make.sh` は
`/var/jb/usr/lib/rust-1.98/bin` の Mach-O を直接指し、`SDKROOT` に
`/var/jb/usr/share/SDKs/iPhoneOS.sdk` を立てる。
