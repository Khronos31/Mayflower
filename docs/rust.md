# rust

ソースツリー: [`packages/rust`](../packages/rust)

Rust ツールチェインをパッケージングする。

## パッケージ情報

- 版: 1.98.1-4
- PATH の `rustc` / `cargo` は Mach-O ラッパー（Dopamine の shebang EPERM）。SDKROOT は未設定なら iPhoneOS.sdk を焼く。
- Depends（`rustc-1.98`）: `build-essential`, `clang`, `ldid`
- パッケージ構成:
  - `rustc-1.98`: ツールチェイン本体（`bin/rustc`、`librustc_driver`、`lib/rustlib`）
  - `rust-std-1.98`: `aarch64-apple-ios` 向けの std
  - `cargo-1.98`: cargo
  - `rust-default`: `/var/jb/usr/bin` に置くラッパー

Procursus には `rustc` も `cargo` も存在しないため（`bat` / `fd` / `dust` /
`hyperfine` などのバイナリのみ配布されている）、同名を避けるための特殊な
命名回避は必要としない。

## 建て方とパッケージング

**Rust だけは端末の上で建てない。** rustc の bootstrap は LLVM を建てるため、
RAM 1.93GB の iPhone 8 では成立しない。

Mac でのクロスビルド手順の正本は [`tools/mac/README.md`](../tools/mac/README.md)
を参照。Mac 側でビルドした dist tarball を端末へ持ち込んでパッケージングする。

パッチは `packages/rust/patches-host/` にあり、母艦側で適用するため
`make.sh` の `applyPatch` の対象には含めない。

端末側では `RUST_DIST_DIR` に tarball の場所を渡して実行する:

```sh
RUST_DIST_DIR=/path/to/dist ./make.sh rust
```

Go の `GOROOT_BOOTSTRAP` と同様の扱いで、母艦のビルド事情は `make.sh` に持ち込まない。

## 端末上での実行とラッパー

出来上がった `rustc` と `cargo` は端末上でそのまま動作する。

- **SDKROOT ラッパー**: `/var/jb/usr/bin` に置くラッパーが補うのは `SDKROOT` だけである。
  端末には `xcrun` が無いため、指定しないと rustc が SDK を見つけられない旨の警告を
  毎回出力する（リンク自体は端末の clang が既定の sysroot として同じ SDK を
  持っているため通る）。
- **sysroot 探索**: iOS でも `_NSGetExecutablePath` は機能するため、Go の GOROOT の
  ような探索失敗は起きず、sysroot の解決コードを修正する必要はない。

## rust-objcopy の署名

`lib/rustlib/aarch64-apple-ios/bin/rust-objcopy` は **rustc の dist** に入る
（rust-std ではない）。rustc のリンカパッチを通らないので、梱包時に
`ldid` しないと cargo の release strip が SIGKILL する。`package_rustc` が
ここの Mach-O を署名する。`pkgrel=2`。
