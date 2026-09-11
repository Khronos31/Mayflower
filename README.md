# Mayflower

脱獄した iOS へパッケージを移植するためのビルドファイル集。**原則として端末の上で**
（Mac を介さず）ソースからビルドし、`.deb` を作る。

**例外は Rust だけ。** rustc の bootstrap は LLVM を建てるので、RAM 1.93GB の
iPhone 8 では成立しない。あれは Mac からクロスビルドする（[tools/mac](tools/mac)）。
**出来上がる rustc と cargo は端末の上で動く**ので、インストール後は端末だけで
Rust のプログラムをコンパイルできる。端末で建てられないのはツールチェイン自身だけ。

`make.sh <パッケージ名>` を叩くと、そのパッケージの取得・パッチ適用・ビルド・検証・
パッケージングまでを順に行う。Arch Linux の PKGBUILD に似た構成で、パッケージごとの
知識は `packages/<名前>/` に閉じている。

```sh
./make.sh nim
# => packages/nim/arm64/nim_2.2.12-1_iphoneos-arm64.deb
sudo dpkg -i packages/nim/arm64/nim_*.deb
```

## 対象

**rootless の脱獄のみ**（palera1n / Dopamine などの Procursus ブートストラップ）。
接頭辞 `/var/jb` を前提に書いてある。rootful 時代（`/usr` 直下・`iphoneos-arm`）の構成は
タグ `rootful-2021` に残してある。

| 項目 | 値 |
|---|---|
| 検証機 | iPhone 8（`iPhone10,1` / A11）・iOS 16.7.14・palera1n rootless |
| アーキテクチャ | `arm64` のみ（`iphoneos-arm64`） |
| 必要なもの | `clang` `ldid` `make` `patch` `curl` `dpkg` `libiosexec1` |

`sudo apt install -y clang ldid make patch curl` でおおむね揃う。

## 脱獄 iOS でビルドするときの勘所

このリポジトリの仕掛けは、ほぼ以下の3点への対処でできている。

### 1. 署名が無い実行ファイルは起動できない

素の clang が吐いた Mach-O は、実行しようとすると **SIGKILL（rc=137）** される。
entitlements 無しの `ldid -S` でも足りない。`platform-application` と
`com.apple.private.security.container-required=false` を持つ plist が要る
（`entitlements.plist`）。

そのため `CC` / `CXX` は素の clang ではなく `bin/cc` / `bin/c++` を指す。
これは clang を呼んだあと出力を `ldid -S` するラッパーで、`configure` が作る
テストバイナリのような「ビルドの途中で実行される実行ファイル」もこれで動く。

#### 自前のリンカを持つ言語では、`dsymutil` を探す

Go や Rust や Nim のように**自分でリンカを起動する**処理系は、ラッパーを
`CC` に置くだけでは足りず、リンク後に `ldid` を呼ぶコードを本体に入れる
必要がある。その差し込み場所は `dsymutil` を grep すると一発で見つかる。

```sh
grep -lr dsymutil <ソースツリー>
```

`dsymutil` は Darwin でリンクした直後にデバッグ情報を取り出す後処理なので、
**それを呼んでいる場所＝リンクが終わった直後**であり、署名を挿すべき場所と
一致する。実際に3つとも隣り合っていた。

| 処理系 | 見つかるファイル |
|---|---|
| Nim | `compiler/extccomp.nim`（`getExtraCmds` の dsymutil の直後に ldid を足した） |
| Go | `src/cmd/link/internal/ld/lib.go`（`hostlink`。`llvm-ar` への差し替えも同じ関数） |
| Rust | `compiler/rustc_codegen_ssa/src/back/link.rs`（dsymutil のブロックの直前） |

### 2. `/bin/sh` が無い

rootless では rootfs が封印されていて、`/bin` には `df` と `ps` しかない。
`system()` は iOS SDK では unavailable（コンパイルエラー）で、しかも実行時は
`/bin/sh` を探す。

端末には **libiosexec**（Procursus）が入っており、`ie_system` / `ie_exec*` /
`ie_posix_spawn` が接頭辞付きのシェルと shebang を解決する。移植対象がシェルを
呼ぶなら、そこへ差し替えるパッチを当てる。動的リンクするときは
`-Wl,-rpath,/var/jb/usr/lib` が要る（Procursus の clang は自動では付けない）。

**シェバンに `/bin/bash` や `/usr/bin/env` は書けない。** どちらのパスも存在しない。
libiosexec を引いている実行ファイルから呼ばれた場合だけ解決されるため一見動くが、
素の `execve` からは `No such file or directory` になる。このリポジトリの
スクリプトは `#!/var/jb/bin/bash` で統一している。

### 3. 動的ライブラリが見つからない

`dlopen("libfoo.dylib")` は既定で `/usr/lib` と `/usr/local/lib` しか見ない。
実行ファイルに `LC_RPATH` として `/var/jb/usr/lib` が入っていれば、素の名前でも
そこから解決される。

## 構成

```
make.sh                 ドライバ。パッケージ側の関数を順に呼ぶ
entitlements.plist      ldid に渡す entitlements
bin/cc, bin/c++         リンク後に ldid 署名する clang ラッパー
util/common.sh          download / applyPatch / makedeb
util/options.sh         tidy の on/off（staticlibs / zipman / resign）
util/tidy.sh            pkgdir の後始末
example/                新しいパッケージの雛形
packages/<名前>/
  make.sh               pkgname / pkgver / source と prepare/build/check/package
  patches/*.patch       `patch -p1` で srcdir に当たるもの
  deb/DEBIAN/control    @VERSION@ / @ARCH@ / @INSTALLED_SIZE@ を置換して使う
```

`make.sh` が呼ぶ順序は `clean` → `download` → `prepare` → `applyPatch` → `build` →
`check`（定義されていれば）→ `package` → `tidy` → `makedeb`。

## 収録パッケージ

| パッケージ | 版 | 備考 |
|---|---|---|
| [nim](packages/nim) | 2.2.12 | コンパイラ・nimble・atlas・nimsuggest・nimgrep・nimpretty・testament |
| [go](packages/go) | 1.26.8 | `golang-1.26-go` / `golang-1.26-src` / `golang-default` に分ける |
| [python](packages/python) | 3.14.7 | `python3.14`（版付きのみ）/ `python3-default`（版なしの入口） |

**Procursus と同じパッケージ名は使わない。** あちらは
`/var/jb/etc/apt/preferences.d/procursus` で `Package: *` を `Pin-Priority: 1001`
に固定している。1001 は「降格してでもその版を入れる」を意味するので、同名で
新しい版を出してもこちら（500）が負け、`apt upgrade` で戻される。`golang-go`
1.26.8-1 を入れた状態で `apt-get -s upgrade` を回すと Procursus の 1.22.4 への
降格が提案された。`preferences.d` を配って自分を上に置くのは第三者リポジトリの
すべきことではないので、名前を変え `Provides` / `Conflicts` / `Replaces` で
置き換える形にしている。

Python は Debian と同じく版付きと版なしに分ける。`python3.14` は Procursus の
`python3` 3.9.9 と同居でき、`python3-default` を入れると `python`・`python3`・
`pip3`・`pydoc3`・`python3-config` がこちらを向き、Procursus の `python3` が
外れる。`idle3` と `2to3` は出さない（3.13 で `lib2to3` が消え、`idlelib` は
tkinter が要る）。`rdepends` 上 Procursus の `python3` に依存する物は無く、
実際に使っているのは git の `git-p4` だけで、これは新しい `python3` で動く。

`go` と `gofmt` は `/var/jb/usr/bin` に置くラッパーで、GOROOT を補ってから
本体を呼ぶ。iOS では `os.Executable` が失敗するため、go が GOROOT を実行ファイルの
位置から見つける経路が効かないことへの対処である。環境変数の GOROOT は要らない。

**exec には libiosexec の限界がそのまま出る。** `exec.Command("sh", …)` と
`#!/bin/sh` のシェバンは通るが、`exec.Command("/bin/sh", …)` のように絶対パスで
封印された rootfs を指すと通らない。libiosexec は shebang の解釈先とシェルの探索は
prefix 付きで行うが、直接渡された絶対パスは読み替えないため。Procursus の go でも同じ。

**Go は 1.27 系を採らない。** `ios/arm64` で起動時に作業ディレクトリが実行ファイルの
場所へ変わる退行が入っており（[golang/go#81465](https://github.com/golang/go/issues/81465)）、
`cmd/go` が `go.mod` を見つけられなくなる。

**上流は直しつつある（2026-09-11 時点）。** CL 830864
「runtime: keep the working directory for non-bundled ios/arm64 binaries」が
Code-Review +2・TryBot 緑で master に出ており、1.27 へのバックポートも
[golang/go#81469](https://github.com/golang/go/issues/81469) として
マイルストーン **Go1.27.2** で起票されている。中身は報告した分析どおりで、
`Info.plist` の有無を `chdir` の条件に戻し、パスの取得だけ
`CFBundleCopyBundleURL` に残す形。**Go 1.27.2 が出たらそこへ移る。**

Nim は端末に nim が入っていればそれを種にし、無ければ同梱の C ソースから
立ち上げる。どちらでも `koch boot` の自己再生成まで通る。

## Go の bootstrap を用意する

Go は自分自身でしかビルドできないので、先に動く Go が要る。**端末に入っている
Procursus の go は使えない**。無署名の実行ファイルしか吐けず、`make.bash` の
途中で実行される中間バイナリが起動できずに死ぬ。

かといって `GOOS=ios` のクロスビルドもできない。`ios/arm64` は必ず外部リンクを
使う決まりで、ターゲット用の C ツールチェインが要るためである。

**`GOOS=darwin GOARCH=arm64` でクロスビルドして、iOS 用に直す。** これは純 Go の
内部リンクなので、Xcode も iOS SDK も要らない。Linux でも構わない。

```sh
# 1. 適当な機械で（要 Go 1.24.6 以降）
cd <goのソース>/src
GOOS=darwin GOARCH=arm64 ./bootstrap.bash     # ../../go-darwin-arm64-bootstrap ができる

# 2. 端末へ運ぶ
tar cf - -C ../../go-darwin-arm64-bootstrap . | ssh <端末> 'mkdir -p ~/dev/go-bootstrap && tar xf - -C ~/dev/go-bootstrap'

# 3. 端末で iOS 用に直す（フレームワークのパスと署名）
~/dev/Mayflower/tools/fix-darwin-toolchain ~/dev/go-bootstrap ~/dev/Mayflower/entitlements.plist
~/dev/go-bootstrap/bin/go version     # go1.27.1 darwin/arm64 と出れば通っている
```

手順3が要るのは、macOS のフレームワークが `CoreFoundation.framework/Versions/A/…`
という階層を持つのに対し、**iOS は平坦**（`CoreFoundation.framework/CoreFoundation`）
だから。`install_name_tool` で書き換えると署名が壊れるので、`ldid` で付け直す。

あとは bootstrap の位置を渡してビルドする。

```sh
GOROOT_BOOTSTRAP=~/dev/go-bootstrap ./make.sh go
```

## apt リポジトリ

できた `.deb` は GitHub Pages で配っている。Sileo / Zebra / Cydia にはこれを入れる。

```
https://khronos31.github.io/Mayflower/
```

端末の apt から直接使うなら `deb https://khronos31.github.io/Mayflower/ ./`。
**署名はしていない**（脱獄リポジトリでは通例で、Sileo も警告を出さない）。

> ⚠️ **Sileo はリポジトリを登録するときに URL を小文字へ変えてしまう。** GitHub Pages の
> パスは大文字小文字を区別するので `/mayflower/` は 404 になる。起きるのは登録の1回だけなので、
> `/var/jb/etc/apt/sources.list.d/` の該当ファイルを開いて `Mayflower` に直せば以後は通る。

### 作り方

```sh
./tools/make-apt-repo <出力先> packages/*/arm64/*.deb
```

`Release`・`Packages`・`Packages.gz`・`Packages.xz`・`debs/` を作る。`apt-ftparchive` も
`dpkg-scanpackages` も使わない——母艦の HAOS ではアドオンを再起動すると apt で入れたものが
消えるため、公開のたびに入れ直す前提にしたくない。要るのは `dpkg-deb` と coreutils だけ。

**端末で回すこと。** `Packages.xz` を作るのに圧縮できる `xz` が必要で、HAOS に入って
いるのは busybox 版（展開専用）。`Architectures` に `all` を並べないのは flat な
リポジトリ（`deb <URL> ./`）では購読側が `Packages` を1つ読むだけで、この欄を
アーキテクチャごとのファイル選択に使わないため。

`Architectures` は収録した `.deb` から拾う（`all` は除く）。`ORIGIN` / `LABEL` / `SUITE` /
`CODENAME` / `COMPONENTS` / `DESCRIPTION` は環境変数で上書きできる。

### 公開の仕方

`gh-pages` ブランチを**毎回ゼロから作って force-push する**。`git clone` は既定で全ブランチを
取るので、`.deb` の履歴が積もると、ビルドしたいだけの人まで巻き込む。毎回作り直せば clone の
費用は常に1スナップショット分で止まる。

```sh
rm -rf /tmp/ghp && mkdir /tmp/ghp && cd /tmp/ghp
cp -a <make-apt-repo の出力>/. .
cp <アイコン> CydiaIcon.png          # Sileo / Cydia がリポジトリの絵として出す
touch .nojekyll                      # Jekyll に触らせない
git init -b gh-pages && git add -A && git commit -m "apt: ..."
git remote add origin git@github.com:Khronos31/Mayflower
git push -f origin gh-pages
```

## 追加予定

移植する値打ちがあるのは次の3種類。いずれも「Procursus（`apt.procurs.us` の
rootless スイート）で間に合わないもの」という一本の基準の言い換えである。

### 1. Procursus に無いもの

rootless スイート `1900` の索引にバイナリが1つも無いもの。Procursus の
ビルドツリーには makefile があるのに公開物が出ていないものも、ここに入る。

| パッケージ | 状況 |
|---|---|
| rust | 索引に無い（ビルドツリーには makefile がある） |
| node | 索引に無い（同上） |
| ruby | 索引に無い（同上） |
| ghc（Haskell） | 索引に無い（同上） |
| openjdk | 索引に無い（同上） |
| mariadb | 索引に無い（同上） |

同じ条件に当てはまるソースは全部で 268 件ある。ただし索引は
`Source:` 欄をあまり持たないため、`expat` に対する `libexpat1` のように
**ソース名とバイナリ名が違うだけのもの**が混ざる。1件ずつバイナリ名で
引いて確かめること。

### 2. Procursus にあるが古いもの

| パッケージ | Procursus `1900` | upstream | |
|---|---|---|---|
| python3 | 3.9.9 | 3.14.7 | ← 収録した |
| golang | 1.22.4 | 1.27.1 | ← 収録した（1.26.8） |
| perl | 5.32.1 | 5.44.0 |
| openssl | 3.2.1 | 4.0.2 |
| git | 2.39.1 | — |
| sqlite3 | 3.34.1 | — |
| curl | 8.7.1 | — |
| meson | 0.64.0 | — |

### 在庫の調べ方

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

## ライセンス

ビルドファイル（`make.sh` / `util/` / `bin/` / 各 `packages/*/make.sh` / `shim/` /
`test/`）は **MIT**。[LICENSE](LICENSE) を見ること。

**`packages/*/patches/` の下は例外**で、パッチは当てる先の派生物なので、
その処理系のライセンスに従う。現在収録している Nim のパッチは Nim 自身が
MIT なので MIT と衝突しない。今後 GPL の処理系を足す場合、そのパッチは
GPL になる。

`entitlements.plist` は Apple が公開している entitlement キー2つを plist の
定型に入れただけのもので、他に書きようがない。

各パッケージのソースそのものは、それぞれのライセンスに従う（`.deb` には
`/var/jb/usr/share/licenses/` に同梱する）。
