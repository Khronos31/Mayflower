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

## ライセンス

各パッケージのソースそのものは、それぞれのライセンスに従う（`.deb` には
`/var/jb/usr/share/licenses/` に同梱する）。このリポジトリのビルドファイル自体の
ライセンスはまだ決めていない。
