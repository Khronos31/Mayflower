# grok

ソースツリー: [`packages/grok`](../packages/grok)

xAI Grok Build TUI（`xai-grok-pager`）1.0.24 を、端末の Mayflower rustc 1.98 で建てる。

上流: [`xai-org/grok-build`](https://github.com/xai-org/grok-build) @ `37949780`

## パッケージ情報

- 版: 1.0.24-1
- `grok`: `/usr/bin/grok`。公式 installer と同じく `/usr/bin/agent` → `grok`
- jemalloc オフ、`sandbox-enforce` は残す（iOS では no-op）
- cargo の rust-objcopy strip は使わない。リンク後に `strip -S` してから `ldid`
- 実行時は PATH の `rg`（`ripgrep-15` / `ripgrep-default`）

## vendor

crates.io は端末から 403 になる。`vendor.tar.xz` は git に入れない（1.7G 級）。

建てる機械で:

```sh
export GROK_VENDOR_DIR=/path/to/vendor   # cargo vendor --locked の出力
./make.sh grok
```

`packages/grok/vendor-overlay/` は iOS 用の vendored crate 差分。
`packages/grok/patches/0001-ios.patch` は grok-build 本体の差分。

## ビルド依存

`rust-default`、`cmake`、`protobuf-compiler`、`clang`、`pkg-config`、
`odcctools`、`llvm`（`llvm-ar`）、`libssl-dev`。
