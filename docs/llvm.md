# llvm（Clang 19）

ソースツリー: [`packages/llvm`](../packages/llvm)

## 方針

- **端末ではソースビルドしない**（Node / Rust と同じ例外）。
- Mac で Apple `llvm-project`（Swift 6.1.x タグの LLVM）をクロスし、tarball を梱包。
- Procursus と同じ **lib\*** / versioned / meta 分割で、`libllvm16` などと**同居**しつつ
  メタだけ置換できる。
- Swift フロントエンドは別パッケージ（`packages/swift` — 触らない）。

| パッケージ | 内容 |
|---|---|
| `libllvm19` | `libLLVM.dylib` + `libLLVM-19.dylib` |
| `libclang-cpp19` | `libclang-cpp*.dylib` |
| `libclang1-19` | `libclang.dylib` + `libclang-19.dylib` |
| `libclang-common-19-dev` | `lib/clang/19` resource headers（+ Polly if any） |
| `llvm-19-linker-tools` | `libLTO.dylib`（+ LLVMPolly）；**lld バイナリは含まない** |
| `lld-19` | `lld` / `ld64.lld` / `ld.lld` under llvm-19/bin + versioned PATH |
| `lld` | メタ: 非版付き PATH → lld-19（Procursus `lld` メタ置換） |
| `llvm-19` | 拡張ツール群；Depends `libllvm19`, `llvm-19-linker-tools` |
| `llvm-19-dev` | `include/llvm`, `include/llvm-c`, static libs if any |
| `llvm-dev` | メタ: Depends `llvm-19-dev` + `llvm-19-linker-tools`；Provides `liblto`；`usr/include/llvm{,-c}` と `usr/lib/libLTO.dylib` の symlink |
| `libc++-19-dev` | `include/c++`（+ `__pstl*` / `pstl`）。ヘッダのみ。`libllvm16` に依存しない |
| `libc++-dev` | メタ: Depends `libc++-19-dev`；`/var/jb/usr/include/c++` → llvm-19。Procursus 同名を置換 |
| `clang-19` | frontend + wrappers；Depends lib\* + `libclang-common-19-dev` + `libc++-19-dev` + `lld-19` + `ld64` + `ldid` |
| `clang-default` | PATH の `clang` 等。`Provides: clang`；Depends `libc++-dev` |
| `llvm-default` | PATH の `llvm-ar` 等。`Provides: llvm` で Procursus `llvm` を置換 |

## 版ピン

| | |
|---|---|
| Swift | 6.1.1-RELEASE |
| LLVM | 19.1.4（`swift-6.1.1-RELEASE` の CMake） |
| Mayflower `pkgver` / `pkgrel` | 19.1.4-7 |

## Mac ビルド

[`tools/mac/llvm-swift/`](../tools/mac/llvm-swift/) を見ること。

```sh
export WORKDIR="$HOME/dev/toolchain-swift-6.1"
# DYLIB フラグ導入後は必ずクリーン configure
rm -rf "$WORKDIR/build/ios"
./tools/mac/llvm-swift/build.sh configure
ninja -C "$WORKDIR/build/ios" …   # clang / lld / libLLVM など
./tools/mac/llvm-swift/build.sh libcxx    # ヘッダ専用 runtimes → stage/include/c++
./tools/mac/llvm-swift/build.sh install   # DESTDIR=stage（selective install-* + libc++ headers）
./tools/mac/llvm-swift/build.sh pack      # dist/*.tar.xz（include/c++ 含む）
```

`libcxx` は `$WORKDIR/build/ios-libcxx` で `runtimes` (libcxx;libcxxabi) を
ヘッダ専用に configure する。Darwin の `libc++.dylib` は置かない（Apple の
ランタイムを使う）。`install` は stage を作り直したあと libc++ ヘッダをマージする。

以前の cache（DYLIB 無し）のまま `install` しても `libLLVM.dylib` は出ない。
README の reconfigure note を参照。

## Procursus との関係（慎重に）— migration

1. **先に versioned + lib\*** を入れる（`libllvm19`, `libclang-*19`, `llvm-19`,
   `lld-19`, `clang-19`, …）。Procursus 16 系と**同居**できる。
2. 必要ならメタを置換: `clang-default` / `llvm-default` / `llvm-dev` / `lld` /
   `libc++-dev`。
3. **`libllvm16` は `swift-5.9.2` が入っている間は外さない。**
4. **Conflict/Replace しないもの:** `libllvm16`, `clang-16`, `llvm-16*`,
   `libc++-16-dev`, `swift-5.9.2`。
5. メタ（同名）だけ Conflicts/Replaces してよい: `clang`（via clang-default）,
   `llvm`（via llvm-default）, `llvm-dev`, `lld`, `libc++-dev`。

`libc++-19-dev` のあと `libc++-dev` メタを Mayflower に差し替えると、
`/var/jb/usr/include/c++` が llvm-19 のヘッダを指すので、C++ は 16 の
ヘッダに頼らなくなる。`libllvm16` は Swift 6.1 が出るまで
`swift-5.9.2` 用に残す。`libc++-16-dev` 自体は消さない（外す指示が無い限り）。

`clang` メタに依存する例: `rustc-1.98`, `nim`, `golang-*`, `libtool`。
default 導入後は `clang-19` が PATH の `clang` になる。

## 端末で梱包

```sh
export LLVM_DIST_DIR="$HOME/dev/toolchain-swift-6.1/dist"
./make.sh llvm
# 例: lib* / versioned を先に、metas は任意
sudo dpkg -i packages/llvm/arm64/libllvm19_*.deb \
             packages/llvm/arm64/libclang-cpp19_*.deb \
             packages/llvm/arm64/libclang1-19_*.deb \
             packages/llvm/arm64/libclang-common-19-dev_*.deb \
             packages/llvm/arm64/llvm-19-linker-tools_*.deb \
             packages/llvm/arm64/lld-19_*.deb \
             packages/llvm/arm64/llvm-19_*.deb \
             packages/llvm/arm64/libc++-19-dev_*.deb \
             packages/llvm/arm64/clang-19_*.deb
# optional metas (replace Procursus metas):
# sudo dpkg -i packages/llvm/arm64/lld_*.deb \
#              packages/llvm/arm64/clang-default_*.deb \
#              packages/llvm/arm64/llvm-default_*.deb \
#              packages/llvm/arm64/llvm-dev_*.deb \
#              packages/llvm/arm64/llvm-19-dev_*.deb \
#              packages/llvm/arm64/libc++-dev_*.deb
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

コンパイラは `clang-19`、リンカは `lld-19`、LTO プラグインは `llvm-19-linker-tools`、
`llvm-ar` 等は `llvm-19`。アーカイブ出力に ldid は不要。ツール本体の署名は梱包時。

## 実機検証

[`packages/llvm/tests/MATRIX.md`](../packages/llvm/tests/MATRIX.md) と
[`packages/llvm/tests/ldid-matrix.sh`](../packages/llvm/tests/ldid-matrix.sh)。

```sh
export PATH="/var/jb/usr/lib/llvm-19/bin:$PATH"
# 作業ファイルは $HOME/tmp（/tmp だと SIGKILL されることがある）
bash packages/llvm/tests/ldid-matrix.sh
```
