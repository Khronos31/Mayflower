# git-delta

ソースツリー: [`packages/git-delta`](../packages/git-delta)

dandavison の git diff ハイライタ（コマンド名 `delta`）。

## パッケージ情報

- 版: 0.19.2
- パッケージ: `git-delta`（バイナリ `delta`）
- ビルド: **端末**（Mayflower rustc 1.98 / cargo、`--offline` + `vendor.tar.gz`）
- ビルド依存: `libonig-dev`、`pkg-config`、`clang`
- 実行時 Depends: `libonig5`
- Procursus: 無し

## 端末

```sh
sudo apt install libonig-dev
# Mac で vendor 済みの packages/git-delta/vendor.tar.gz を使う

./make.sh git-delta
sudo dpkg -i packages/git-delta/arm64/git-delta_*.deb
delta --version
```

git に組み込む例:

```sh
git config --global core.pager delta
git config --global interactive.diffFilter 'delta --color-only'
```
