# ast-grep

ソースツリー: [`packages/ast-grep`](../packages/ast-grep)

AST ベースの検索・書き換え（`ast-grep` / `sg`）。

## パッケージ情報

- 版: 0.45.3
- パッケージ: `ast-grep`
- ビルド: **端末**（Mayflower rustc、`--offline` + `vendor.tar.gz`）
- Procursus: 無し

## 端末

```sh
./make.sh ast-grep
sudo dpkg -i packages/ast-grep/arm64/ast-grep_*.deb
sg --version
```
