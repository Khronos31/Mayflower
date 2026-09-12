# Mac: Swift 6.1 / Clang 19 → iOS dist

iPhone 上では建てない。ここでクロスして tarball を作り、端末の
`packages/llvm/make.sh` が梱包する。

## 前提

- macOS + Xcode（iPhoneOS.sdk）
- `cmake` / `ninja` / `python3` / `xz`
- 空き容量に余裕（ソース + ビルドで数十 GB 見ておく）

## 使い方（概略）

```sh
export WORKDIR="$HOME/dev/toolchain-swift-6.1"
./tools/mac/llvm-swift/build.sh
# => $WORKDIR/dist/llvm-19.1.4-swift-6.1.1-aarch64-apple-ios.tar.xz
```

端末（または Mac から `LLVM_DIST_DIR` を渡して）:

```sh
export LLVM_DIST_DIR=/path/to/dist
./make.sh llvm
```

## 版

| 項目 | 値 |
|---|---|
| Swift | 6.1.1-RELEASE |
| LLVM（CMake） | 19.1.4 |
| 三重項 | `arm64-apple-ios16.0`（要調整） |
| 接頭辞 | `/var/jb/usr/lib/llvm-19` |

Procursus の `llvm.mk`（Swift 同梱・二段ビルド・rootless prefix）を参考にしている。
