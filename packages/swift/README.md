# swift（Swift 6.1）

Procursus と同様、**llvm とは別パッケージ**。`clang-19` に依存する。

```sh
export LLVM_DIST_DIR="$HOME/dev/toolchain-swift-6.1/dist"   # または SWIFT_DIST_DIR
./make.sh swift
sudo dpkg -i packages/swift/arm64/swift-6.1_*.deb
```

`swift-default`（Procursus `swift` メタ置換）はランタイムが揃ってから。
