# llvm（Clang 19 / Swift 6.1）

ソースツリー: [`packages/llvm`](../packages/llvm)

## 方針

- **端末ではソースビルドしない**（Node / Rust と同じ例外）。
- Mac で Apple `llvm-project` + Swift **6.1.x** をクロスし、tarball を梱包。
- 版付きのみ。Procursus の **clang-16 / Swift 5.9.2 を default 置換しない**。

| パッケージ | 内容 |
|---|---|
| `clang-19` | `/var/jb/usr/lib/llvm-19` + `clang-19` など |
| `swift-6.1` | `swift-6.1` / `swiftc-6.1`（本体は llvm-19 ツリー） |

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
# 案内に従い ninja / install のあと:
./tools/mac/llvm-swift/build.sh pack
```

## 端末で梱包

```sh
export LLVM_DIST_DIR="$HOME/dev/toolchain-swift-6.1/dist"
./make.sh llvm
sudo dpkg -i packages/llvm/arm64/clang-19_*.deb \
             packages/llvm/arm64/swift-6.1_*.deb
```

## 参考

- Procursus `makefiles/llvm.mk` / `build_patch/llvm/`
- 申し送り: `ha:/config/.tools/handoff/20260912-clang-procursus-patches.md`
- Node の先例: [`docs/node.md`](node.md)

## ldid

ラッパではない。`patches-host/clang_driver_darwin_ldid.patch` で
`darwin::Linker::ConstructJob` の末尾に `ldid` を足している（dsymutil 別ジョブとは別経路）。
entitlements は `CLANG_LDID_ENTITLEMENTS`、無ければ
`/var/jb/usr/lib/llvm-19/entitlements.plist`、それも無ければ `ldid -S`。
