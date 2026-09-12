# llvm（Clang 19）

ソースツリー: [`packages/llvm`](../packages/llvm)

## 方針

- **端末ではソースビルドしない**（Node / Rust と同じ例外）。
- Mac で Apple `llvm-project`（Swift 6.1.x タグの LLVM）をクロスし、tarball を梱包。
- 版付きパッケージに加え、`clang-default` / `llvm-default` で Procursus の `clang` / `llvm` メタを置換できる。
- Swift フロントエンドは別パッケージ。

| パッケージ | 内容 |
|---|---|
| `clang-19` | コンパイラ + resource headers + `clang-19` ラッパー |
| `llvm-19-linker-tools` | `lld` / `ld64.lld`（ldid 署名込み） |
| `llvm-19` | `llvm-ar` / `llvm-nm` / `llvm-ranlib` / `llvm-config` |
| `clang-default` | PATH の `clang` 等。`Provides: clang` で Procursus `clang` を置換 |
| `llvm-default` | PATH の `llvm-ar` / `lld` 等。`Provides: llvm` で Procursus `llvm` を置換 |

Swift は別パッケージ（このツリーには含めない）。

## 版ピン

| | |
|---|---|
| Swift | 6.1.1-RELEASE |
| LLVM | 19.1.4（`swift-6.1.1-RELEASE` の CMake） |
| Mayflower `pkgver` | 19.1.4 |

## Mac ビルド

[`tools/mac/llvm-swift/`](../tools/mac/llvm-swift/) を見ること。

```sh
export WORKDIR="$HOME/dev/toolchain-swift-6.1"
./tools/mac/llvm-swift/build.sh all
# patches-host 適用済みソースで:
ninja -C "$WORKDIR/build/ios"   # clang / lld など
./tools/mac/llvm-swift/build.sh install   # DESTDIR=stage（slim）
./tools/mac/llvm-swift/build.sh pack      # dist/*.tar.xz
```

## 端末で梱包

```sh
export LLVM_DIST_DIR="$HOME/dev/toolchain-swift-6.1/dist"
./make.sh llvm
sudo dpkg -i packages/llvm/arm64/llvm-19-linker-tools_*.deb \
             packages/llvm/arm64/llvm-19_*.deb \
             packages/llvm/arm64/clang-19_*.deb \
             packages/llvm/arm64/clang-default_*.deb \
             packages/llvm/arm64/llvm-default_*.deb
```

## 参考

- Procursus `makefiles/llvm.mk` / `build_patch/llvm/`
- 申し送り: `ha:/config/.tools/handoff/20260912-clang-procursus-patches.md`
- Node の先例: [`docs/node.md`](node.md)

## ldid

署名は **リンカ（lld）が主**。clang は後処理があるときだけ補う。

| パッチ | 場所 | いつ動く |
| --- | --- | --- |
| `lld_macho_ios_platform.patch` | `lld/MachO/InputFiles.cpp` | Swift フォークの「iOS 未対応」stub を外す（必須） |
| `lld_macho_writer_ldid.patch` | `lld/MachO/Writer.cpp` `writeOutputFile` 直後 | `MH_EXECUTE` / `MH_DYLIB` / `MH_BUNDLE` を書いたあと |
| `clang_driver_darwin_ldid.patch` | `darwin::Linker` | **lld 以外**のリンカ（例: Apple `ld64`）のときだけ |
| 同上 | `darwin::Dsymutil` | `-g` で dsymutil がイメージを触ったあと、リンク成果物を再署名 |

`clang` が `lld` を spawn して終わる通常パスは lld 側だけで足りる。dsymutil がバイナリを書き換える経路だけ clang 側も持つ。

| 環境変数 | 意味 |
| --- | --- |
| （未設定） | 上記どおり自動で `ldid` |
| `CLANG_NO_LDID` または `LLD_NO_LDID` | 署名しない。Go/Rust/Nim など自前で最後に署名するとき用（どちらでも両方スキップ） |
| `CLANG_LDID_ENTITLEMENTS` | entitlements plist のパス。未設定ならプレーン `ldid -S`（clang 経路はプレフィックス旁の `entitlements.plist` も見る） |

## PATH ラッパー

`clang-19` / `clang++-19` / `clang-cpp-19` は Procursus と同じく `/var/jb/usr/bin` の薄いラッパー。
実体は `/var/jb/usr/lib/llvm-19/bin`。こうしないと `InstalledDir` が preboot 実パスになり、
未指定時の `SDKROOT`（`iPhoneOS.sdk`）も入らない。

## 同梱ツール

コンパイラは `clang-19`、リンカは `llvm-19-linker-tools`、`llvm-ar` 等は `llvm-19`。
アーカイブ出力に ldid は不要。ツール本体の署名は梱包時。

## 実機検証

[`packages/llvm/tests/MATRIX.md`](../packages/llvm/tests/MATRIX.md) と
[`packages/llvm/tests/ldid-matrix.sh`](../packages/llvm/tests/ldid-matrix.sh)。

```sh
export PATH="/var/jb/usr/lib/llvm-19/bin:$PATH"
# 作業ファイルは $HOME/tmp（/tmp だと SIGKILL されることがある）
bash packages/llvm/tests/ldid-matrix.sh
```

