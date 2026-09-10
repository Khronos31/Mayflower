# Mayflower

脱獄した iOS へパッケージを移植するためのビルドファイル集。**端末の上で**（Mac を介さず）
ソースからビルドし、`.deb` を作る。

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

| パッケージ | Procursus `1900` | upstream |
|---|---|---|
| python3 | 3.9.9 | 3.14.7 |
| golang | 1.22.4 | 1.27.1 |
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
