# swift（Swift 6.1）

ソースツリー: [`packages/swift`](../packages/swift)

llvm（Clang 19）とは**別パッケージ**。Depends は `clang-19`、`ldid`、`profile.d`（legacy driver 警告抑制）。

| パッケージ | 内容 |
|---|---|
| `swift-6.1` | 版付き `swift-6.1` / `swiftc-6.1` + stdlib（Mac dist 次第） |

Procursus の unversioned `swift` メタは当面触らない（`swift-default` は後続）。

## Mac ビルド

[`tools/mac/llvm-swift/`](../tools/mac/llvm-swift/) — Clang 用 `build/ios` とは別に `build/native-swift` → `build/ios-swift`。

```sh
export WORKDIR="$HOME/dev/toolchain-swift-6.1"
export CMAKE_BUILD_PARALLEL_LEVEL=2   # Mac mini 8GB 目安
./tools/mac/llvm-swift/build.sh fetch
./tools/mac/llvm-swift/build.sh native-swift    # 長い
./tools/mac/llvm-swift/build.sh configure-swift
./tools/mac/llvm-swift/build.sh ninja-swift     # さらに長い
./tools/mac/llvm-swift/build.sh install-swift
./tools/mac/llvm-swift/build.sh pack-swift
# => $WORKDIR/dist/swift-6.1.1-aarch64-apple-ios.tar.xz
```

依存ソース: `swift` / `swift-cmark` / `swift-syntax` @ `swift-6.1.1-RELEASE`（既存の `llvm-project` と共用）。

## 端末

```sh
export SWIFT_DIST_DIR="$HOME/dev/toolchain-swift-6.1/dist"
./make.sh swift
sudo dpkg -i packages/swift/arm64/swift-6.1_*.deb
```
