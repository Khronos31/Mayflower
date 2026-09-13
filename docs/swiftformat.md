# swiftformat

ソースツリー: [`packages/swiftformat`](../packages/swiftformat)

[SwiftFormat](https://github.com/nicklockwood/SwiftFormat) — Swift ソース整形 CLI（Nick Lockwood）。

## パッケージ情報

- 版: 0.63.0
- パッケージ: `swiftformat`
- ビルド: **端末**（Mayflower `swiftc-6.1`、SPM / `swift-package` 無しのため Sources を一括 `swiftc`）
- ビルド依存: `swift-6.1`, `ldid`, iPhoneOS SDK（`SDKROOT` または `$HOME/theos/sdks/iPhoneOS*.sdk`）
- 同梱: `files/libclang_rt.ios.a`（`___isPlatformVersionAtLeast`）、`files/clang-include-override/arm_vector_types.h`（18.x SDK 向け）
- 実行時 Depends: 無し（システムの `/usr/lib/swift` にリンク）
- Procursus: 無し（新規）

## 端末

```sh
sudo apt install swift-6.1
# Theos SDK 例: $HOME/theos/sdks/iPhoneOS18.4.sdk

./make.sh swiftformat
sudo dpkg -i packages/swiftformat/arm64/swiftformat_*.deb
swiftformat --version
```

作業一時ディレクトリは `$HOME/tmp` を使う（jb の `/tmp` は SIGKILL されやすい）。
ビルドはソース約 180 ファイルで数分かかる。

Mayflower の Swift には `swift-package` がまだ無いので、Package.swift は使わず
`Sources` + `CommandLineTool` を直接 `swiftc` している。
