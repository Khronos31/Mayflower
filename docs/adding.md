# パッケージの追加と版上げ

`main` に直接載せない。枝を切って Pull Request にする。
apt リポジトリ（`gh-pages`）への掲載はこの手順の外。

**PR を出すのは、端末で `./make.sh <名前>` が通って `.deb` を `dpkg -i` したあと。**
出す前に落ちても、出したあとに直して push してよい。

## 枝

`<package>-<version>`。`main` から切る。

- `package` は `packages/` のディレクトリ名（`nim` / `go` / `python` / `rust` / `ruby` / `lua`）
- `version` は `pkgver`（`pkgrel` は付けない）

```sh
git switch -c node-22.9.0 main
```

版の無い長期枝（2020 年の `nim` / `go` など）は使わない。

## Pull Request

先は `main`。題名は次のいずれか。

| | 題名 |
|---|---|
| 新規 | `Add <Package> <version>` |
| 版上げ | `Update <Package> <version>` |

`<Package>` は人が読む名前（`Nim` / `Go` / `Python` / `Rust` / `Ruby` / `Lua`）。
`<version>` は枝と同じ `pkgver`。

```
Add Node 22.9.0
Update Go 1.27.2
```

## 載せるもの

その枝に置くのは、そのパッケージのビルドファイルと案内。

- `packages/<package>/`（雛形は [`example/`](../example)）
- `docs/<package>.md`
- 新規なら README の収録表の行。版上げならそこの版と `docs/<package>.md`

共通層（`make.sh` / `util/` / `bin/` / `compat/`）を触るなら、このパッケージの
ために必要だと PR 本文に書く。
