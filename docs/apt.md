# apt リポジトリの管理

できた `.deb` を GitHub Pages で flat リポジトリ（`deb <URL> ./`）として
公開・保守する手順。署名はしない（脱獄リポジトリでは無署名が通例）。

## リポジトリの作成

```sh
./tools/make-apt-repo <出力先> packages/*/arm64/*.deb
```

`Release`・`Packages`・`Packages.gz`・`Packages.xz`・`debs/` を生成する。
`apt-ftparchive` や `dpkg-scanpackages` は使わない。要るのは `dpkg-deb` と
coreutils だけである。

- **端末で回すこと。** `Packages.xz` を作るのに圧縮できる `xz` が必要。別の機械の
  busybox xz は展開専用の場合があるため、端末上で生成する。
- `Architectures` に `all` を並べない。flat なリポジトリ（`deb <URL> ./`）では
  購読側が `Packages` を1つ読むだけで、この欄をアーキテクチャごとのファイル
  選択に使わないため。
- `Architectures` は収録した `.deb` から拾う（`all` は除く）。
- メタデータは環境変数で上書きできる:
  - `ORIGIN`（既定: `Mayflower`）
  - `LABEL`（既定: `Khronos31`）
  - `SUITE`（既定: `stable`）
  - `CODENAME`（既定: `stable`）
  - `COMPONENTS`（既定: `main`）
  - `DESCRIPTION`（既定: `Packages built on-device for rootless jailbroken iOS.`）

## 公開の仕方（GitHub Pages）

`gh-pages` ブランチを**毎回ゼロから作って force-push する**。`git clone` は
既定で全ブランチを取るので、`.deb` の履歴が積もると、ビルドしたいだけの人まで
巻き込む。毎回作り直せば clone の費用は常に1スナップショット分で止まる。

```sh
rm -rf /tmp/ghp && mkdir /tmp/ghp && cd /tmp/ghp
cp -a <make-apt-repo の出力>/. .
cp <アイコン> CydiaIcon.png          # Sileo / Cydia がリポジトリの絵として出す
touch .nojekyll                      # Jekyll に触らせない
git init -b gh-pages && git add -A && git commit -m "apt: ..."
git remote add origin git@github.com:Khronos31/Mayflower
git push -f origin gh-pages
```
