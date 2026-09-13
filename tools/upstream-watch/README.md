# upstream-watch

上流 GitHub の release / tag を見て、Mayflower の `pkgver` より新しければ Issue を開く。

- **通知だけ**（自動 bump / 自動 PR はしない）
- **LLVM / Clang は監視しない**
- 版上げより Procursus 穴埋め優先、の方針はそのまま

## 使い方

```sh
# dry-run（Issue を作らない）
python3 tools/upstream-watch/check.py --dry-run

# 本番（要 gh 認証）
python3 tools/upstream-watch/check.py
```

GitHub Actions: `.github/workflows/upstream-watch.yml`（毎日 + `workflow_dispatch`）。

## 監視リスト

`manifest.yml`。`packages/<id>/make.sh` の `pkgver=` が現行版。
