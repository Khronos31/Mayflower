# ripgrep

ソースツリー: [`packages/ripgrep`](../packages/ripgrep)

ripgrep 15.2.0 を、端末の Mayflower rustc 1.98 で建ててパッケージングする。

## パッケージ情報

- 版: 15.2.0-1
- `ripgrep-15`: 版付きの `rg-15`
- `ripgrep-default`: PATH の `rg`。`Provides` / `Conflicts` / `Replaces: ripgrep`
  で Procursus の 12.1.1 を置換する

## 建て方

crates.io は端末から 403 になることがある。`packages/ripgrep/vendor.tar.gz` は
HAOS で `cargo vendor --locked` した木。`make.sh` は `--offline` で建てる。

RAM 1.93GB のため `CARGO_BUILD_JOBS` の既定は 1。
