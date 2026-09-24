# Mayflower

脱獄した iOS へパッケージを移植するためのビルドファイル集。原則として端末の上で
（Mac を介さず）ソースからビルドし、`.deb` を作る。例外は Rust と Node と llvm（Clang 19）と swift（Swift 6.1）
（ツールチェイン / V8 自身は Mac からクロスビルド、出来たバイナリは端末で動く）。

`make.sh <パッケージ名>` を叩くと、取得・パッチ適用・ビルド・検証・パッケージング
までを順に行う。Arch Linux の PKGBUILD に似た構成で、パッケージごとの知識は
`packages/<名前>/` に閉じている。

```sh
./make.sh nim
# => packages/nim/arm64/nim_2.2.12-1_iphoneos-arm64.deb
sudo dpkg -i packages/nim/arm64/nim_*.deb
```

## 入れる

できた `.deb` は GitHub Pages で配っている。Sileo / Zebra / Cydia にはこれを入れる。

```
https://khronos31.github.io/Mayflower/
```

端末の apt から直接使うなら `deb https://khronos31.github.io/Mayflower/ ./`。
署名はしていない（脱獄リポジトリでは通例で、Sileo も警告を出さない）。

> ⚠️ **Sileo はリポジトリを登録するときに URL を小文字へ変えてしまう。** GitHub Pages の
> パスは大文字小文字を区別するので `/mayflower/` は 404 になる。起きるのは登録の1回だけ
> なので、`/var/jb/etc/apt/sources.list.d/` の該当ファイルを開いて `Mayflower` に
> 直せば以後は通る。リポジトリ側の改名はしない。リポジトリの作り方や公開の手順は
> [docs/apt.md](docs/apt.md) を参照。

## 対象

rootless の脱獄のみ（palera1n / Dopamine などの Procursus ブートストラップ）。
接頭辞 `/var/jb` を前提に書いてある。rootful 時代（`/usr` 直下・`iphoneos-arm`）の
構成はタグ `rootful-2021` に残してある。

| 項目 | 値 |
|---|---|
| 検証機 | iPhone 8（`iPhone10,1` / A11）・iOS 16.7.14・palera1n rootless |
| アーキテクチャ | `arm64` のみ（`iphoneos-arm64`） |
| 必要なもの | `clang` `ldid` `make` `patch` `curl` `dpkg` `libiosexec1` |

`sudo apt install -y clang ldid make patch curl` でおおむね揃う。

## 収録パッケージ

| パッケージ | 版 | 備考 |
|---|---|---|
| [apple-a14](docs/apple-a14.md) | 1.0 | 空のゲート。`cy+model.iphone (>= 13.1) \| cy+model.ipad (>= 13.1)`。Claude Code が依存する |
| [ast-grep](docs/ast-grep.md) | 0.45.3 | `ast-grep` / `sg`。端末の rustc で建てる。Procursus に無し |
| [claude-code](docs/claude-code.md) | 2.1.274 | 非公式。**ビルドは Mac**。darwin-arm64 をパッチ。Depends `apple-a14`。ラッパーで自動更新と ~/.local 再生成を抑止 |
| [epgstation](docs/epgstation.md) | 2.10.0 | `epgstation`。JS は Mac。sqlite3 は nodejs-sqlite3。PATH は Mach-O。 |
| [fd](docs/fd.md) | 10.5.0 | `fd-10` / `fd-default`。端末の rustc で建てる。Procursus 8.6.0 を置換 |
| [git](docs/git.md) | 2.55.0 | `git-2.55` / `git-default`。端末で建てる。Procursus 2.39.1 を置換 |
| [git-delta](docs/git-delta.md) | 0.19.2 | バイナリ `delta`。端末の rustc で建てる。Procursus に無し |
| [glow](docs/glow.md) | 3.0.0 | 端末の Go で建てる。Procursus に無し |
| [go](docs/go.md) | 1.26.8 | `golang-1.26-go` / `golang-1.26-src` / `golang-default` |
| [grok](docs/grok.md) | 1.0.24 | `grok`。端末の rustc。jemalloc オフ。vendor は git 外 |
| [jq](docs/jq.md) | 1.8.2 | `jq-1.8` / `libjq1` / `libjq-dev` / `jq-default`。端末で建てる。Procursus 1.6 を置換 |
| [llvm](docs/llvm.md) | 19.1.4 | `clang-19` / `llvm-19` / `llvm-19-linker-tools` + `clang-default` / `llvm-default`。**ビルドは Mac**。default で Procursus `clang` / `llvm` を置換可。Swift は別パッケージ |
| [lua](docs/lua.md) | 5.5.1 | `lua5.5` / `liblua5.5-0` / `liblua5.5-dev` / `lua-default` |
| [luarocks](docs/luarocks.md) | 3.13.0 | Lua 5.5 用。ユーザートリーは `~/.luarocks` |
| [mirakc](docs/mirakc.md) | 3.4.86 | Mirakurun 互換 PVR。端末の rustc で建てる（`-p mirakc` のみ）。Procursus に無し |
| [mirakc-arib](docs/mirakc-arib.md) | 0.9.1 | `mirakc-arib`。ARIB TS の scan/EIT/filter。**ビルドは Mac**。Procursus に無し |
| [nim](docs/nim.md) | 2.2.12 | コンパイラ・nimble・atlas・nimsuggest・nimgrep・nimpretty・testament |
| [node](docs/node.md) | 24.21.0 | `nodejs-24` / `node-default`。ビルドだけ Mac。`--jitless` 既定。`node-default` が Procursus の npm 8.1.1 を置換 |
| [node-sqlite3](docs/node-sqlite3.md) | 5.1.7 | `nodejs-sqlite3`。npm の sqlite3 を Mac からクロス。Procursus の sqlite3 CLI とは別。PATH にコマンドは出さない |
| [pcsc-lite](docs/pcsc-lite.md) | 2.5.1-4 | `libpcsclite1` / `pcscd` / `libpcsclite-dev`。端末で建てる。Procursus に無し。Dopamine 向け再署名 |
| [px4-userland](docs/px4-userland.md) | 0.1.4 | `Name: PX4 Driver`。`px4d` / `px4-ts` / `px4ctl` + IFD dylib。ファーム非同梱 |
| [python](docs/python.md) | 3.14.7 | `python3.14` / `python3-default` |
| [ripgrep](docs/ripgrep.md) | 15.2.0 | `ripgrep-15` / `ripgrep-default`。端末の rustc で建てる。Procursus 12.1.1 を置換 |
| [ruby](docs/ruby.md) | 4.0.6 | インタプリタ。YJIT / ZJIT は建てない。subprocess は palera1n で建て Dopamine で確認 |
| [ruff](docs/ruff.md) | 0.16.7 | Python linter/formatter。端末の rustc で建てる。Procursus に無し |
| [rust](docs/rust.md) | 1.98.1 | `rustc-1.98` / `rust-std-1.98` / `cargo-1.98` / `rust-default`。ツールチェインのビルドだけ Mac |
| [sd](docs/sd.md) | 1.1.0 | 直感的な find & replace。端末の rustc で建てる。Procursus に無し |
| [siano-userland](docs/siano-userland.md) | 0.1.5 | `Name: Siano Driver`。バイナリは `siano-ts`。Siano RIO (PX-S1UD) の ISDB-T |
| [swiftformat](docs/swiftformat.md) | 0.63.0 | 端末の `swiftc-6.1` で建てる（SPM 無し・直 `swiftc`）。Procursus に無し |
| [swift](docs/swift.md) | 6.1.1 | `swift-6.1`。**ビルドは Mac**。Depends `clang-19`。Procursus swift は当面並立 |
| [tmux](docs/tmux.md) | 3.7c | `tmux-3.7` / `tmux-default`。端末で建てる。Procursus 3.4 を置換 |

Procursus と同じパッケージ名は使わない。あちらは
`/var/jb/etc/apt/preferences.d/procursus` で `Package: *` を `Pin-Priority: 1001` に
固定しており、同名では `apt upgrade` で戻されるためである。`preferences.d` を配って
自分を上に置くのは第三者リポジトリのすべきことではないので、名前を変え `Provides` /
`Conflicts` / `Replaces` で置き換える形にしている。

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
`check`（定義されていれば）→ `package` → `tidy` → `makedeb`。脱獄環境特有の
署名・シェバン・ライブラリ探索への対処など、ビルドの勘所は [docs/building.md](docs/building.md)
を参照。パッケージを足す・版を上げる手順は [docs/adding.md](docs/adding.md)。

## 追加予定

移植の基準は「Procursus（`apt.procurs.us` の rootless スイート）で間に合わないもの」。
在庫の調べ方や詳細な経緯は [docs/roadmap.md](docs/roadmap.md) を参照。

| 種別 | パッケージ |
|---|---|
| Procursus に無いもの | ghc, openjdk, mariadb |
| あるが古いもの | perl, openssl, git, sqlite3, curl, meson |

## ライセンス

ビルドファイル（`make.sh` / `util/` / `bin/` / 各 `packages/*/make.sh` / `shim/` /
`test/`）は **MIT**。[LICENSE](LICENSE) を見ること。

`packages/*/patches/` の下は例外で、パッチは当てる先の派生物なので、その処理系の
ライセンスに従う。現在収録している Nim のパッチは Nim 自身が MIT なので MIT と
衝突しない。今後 GPL の処理系を足す場合、そのパッチは GPL になる。

`entitlements.plist` は Apple が公開している entitlement キー2つを plist の定型に
入れただけのもので、他に書きようがない。

各パッケージのソースそのものは、それぞれのライセンスに従う（`.deb` には
`/var/jb/usr/share/licenses/` に同梱する）。
