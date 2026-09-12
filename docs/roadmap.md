# 追加予定と在庫の調べ方

移植する値打ちがあるのは次の3種類。いずれも「Procursus（`apt.procurs.us` の
rootless スイート）で間に合わないもの」という一本の基準の言い換えである。

## 1. Procursus に無いもの

rootless スイート `1900` の索引にバイナリが1つも無いもの。Procursus の
ビルドツリーには makefile があるのに公開物が出ていないものも、ここに入る。

| パッケージ | 状況 | |
|---|---|---|
| rust | 索引に無い（ビルドツリーには makefile がある） | ← 収録した |
| node | 索引に無い（同上） | |
| ruby | 索引に無い（同上） | ← レシピを足した（4.0.6、YJIT なし。端末未ビルド） |
| ghc（Haskell） | 索引に無い（同上） | |
| openjdk | 索引に無い（同上） | |
| mariadb | 索引に無い（同上） | |

同じ条件に当てはまるソースは全部で 268 件ある。ただし索引は `Source:` 欄を
あまり持たないため、`expat` に対する `libexpat1` のように**ソース名とバイナリ名が
違うだけのもの**が混ざる。1件ずつバイナリ名で引いて確かめること。

## 2. Procursus にあるが古いもの

| パッケージ | Procursus `1900` | upstream | |
|---|---|---|---|
| python3 | 3.9.9 | 3.14.7 | ← 収録した |
| golang | 1.22.4 | 1.27.1 | ← 収録した（1.26.8） |
| perl | 5.32.1 | 5.44.0 | |
| openssl | 3.2.1 | 4.0.2 | |
| git | 2.39.1 | — | |
| sqlite3 | 3.34.1 | — | |
| curl | 8.7.1 | — | |
| meson | 0.64.0 | — | |

## 3. 在庫の調べ方

rootful（`iphoneos-arm`）のスイートは `apt.procurs.us` から消えており、
生きているのは rootless の `1800` / `1900` / `2000` だけ。

```sh
# 索引を取る
curl -sSLO https://apt.procurs.us/dists/1900/main/binary-iphoneos-arm64/Packages.xz

# 収録されているか（バイナリ名で引く。libfoo1 / foo-dev のような名前に注意）
xz -dc Packages.xz | grep -E '^(Package|Version): ' | grep -A1 -x 'Package: curl'

# Procursus 自身がビルドしているものの一覧
gh api 'repos/ProcursusTeam/Procursus/git/trees/main?recursive=1' \
  --jq '.tree[].path' | grep '^makefiles/.*\.mk$'
```
