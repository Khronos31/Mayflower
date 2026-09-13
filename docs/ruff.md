# ruff

ソースツリー: [`packages/ruff`](../packages/ruff)

[Ruff](https://docs.astral.sh/ruff/) — Astral の超高速 Python linter / formatter。

## パッケージ情報

- 版: 0.16.7
- パッケージ: `ruff`
- ビルド: **端末**（Mayflower `rustc` 1.98 / `cargo`、`vendor.tar.gz` で `--offline`）
- ソース: crates.io の `ruff` crate（GitHub モノレポ全体ではない）
- パッチ:
  - `0001-disable-jemalloc-on-ios.patch`（Cargo.toml で `tikv-jemallocator` 依存を iOS 除外）
  - `0002-disable-jemalloc-global-allocator-on-ios.patch`（`main.rs` の `#[global_allocator]` も同様）
- Procursus: 無し（新規）

## 端末

```sh
sudo apt install rust-default   # rustc-1.98 / cargo-1.98
./make.sh ruff
sudo dpkg -i packages/ruff/arm64/ruff_*.deb
ruff --version
```

`vendor.tar.gz` は Mac で `cargo vendor --locked` したもの。crates.io が端末から
403 になることがあるため同梱する（約 57MB）。ビルドは重い（十数分以上を想定）。
作業一時ディレクトリは `$HOME/tmp`（jb の `/tmp` は SIGKILL されやすい）。
