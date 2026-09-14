# packages/zig

Zig 0.16.0 for Mayflower (rootless, `iphoneos-arm64`).

設計の正本は [`docs/zig.md`](../../docs/zig.md)。

## いまの状態（2026-09-14）

- 依存関係・可否調査は docs に書いた。
- **Mac-cross で端末実行可能な `zig` ホストを得る公式経路は無い**
  （`zig-bootstrap` に `aarch64-ios` 無し、download に ios ホスト無し）。
- スケルトンは Rust 流儀: 母艦成果物を `ZIG_DIST_DIR` で受けて deb 化。
- 実ビルド / 煙テストは未完。通るまで PR しない。

## 梱包（端末、成果物ができたあと）

```sh
# 例: 交叉または rewrite 済みの prefix を置く
ZIG_DIST_DIR=~/dev/zig-ios-prefix ./make.sh zig
```

`ZIG_DIST_DIR` は次のどちらか:

1. `zig` 実行ファイルと `lib/` が直下にあるディレクトリ
2. 公式 `zig-*-0.16.0.tar.xz` が置いてあるディレクトリ

## 母艦での最初の実験

```sh
# 1) 公式 macos ホストで aarch64-ios プログラム交叉（SDK 要）
curl -fsSL -o ~/dev/zig-aarch64-macos-0.16.0.tar.xz \
  https://ziglang.org/download/0.16.0/zig-aarch64-macos-0.16.0.tar.xz
mkdir -p ~/dev/zig-macos && tar -xJf ~/dev/zig-aarch64-macos-0.16.0.tar.xz -C ~/dev/zig-macos
ZIG=~/dev/zig-macos/zig-aarch64-macos-0.16.0/zig
SDK=$(# 端末由来 iPhoneOS.sdk。tools/mac/README.md 参照)
$ZIG build-exe hello.zig -target aarch64-ios --sysroot "$SDK"

# 2) コンパイラ自身の交叉（未知・重い）
# git/source: zig-0.16.0.tar.xz
# $ZIG build -Dtarget=aarch64-ios -Doptimize=ReleaseFast ...
```

## スコープ外

- zls（言語サーバ）— 後回し
- `zig cc` のシステム CC 化
