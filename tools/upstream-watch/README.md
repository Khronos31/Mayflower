# upstream-watch

上流 GitHub の release / tag を見て、Mayflower の `pkgver` より新しければ Issue を開く。

- **通知だけ**（自動 bump / 自動 PR はしない）
- **LLVM / Clang / Swift は監視しない**
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

## 特定バージョンを無視したいとき

その版の Issue を **close** すればよい（例: go 1.27.1 に既知バグがあり 1.27.2 待ち）。

- 同じ `pkg` + `ver` は open / closed どちらでも再作成しない
- さらに新しい版（1.27.2 など）が出たら、別 Issue が新しく開く

## 並走リリース（Node など）

`same_major: true` を付けると、Mayflower の `pkgver` と同じメジャーだけを見る。
Node の Current (26) と LTS (24) のように並走している上流で、別トラックを「更新」と誤検知しないため。

