# packages/zig

Zig 0.16.0 for Mayflower (rootless, `iphoneos-arm64`).

設計の正本は [`docs/zig.md`](../../docs/zig.md)。

## パッチ

| ファイル | 内容 |
|----------|------|
| `patches/src_link_MachO.zig.patch` | ios device の Exe/dylib 最終リンクを system clang に委譲し、**ldid last**。`ZIG_LDID_ENTITLEMENTS` 対応。`ZIG_NO_LDID` なし。子に `CLANG_NO_LDID`/`LLD_NO_LDID` を立てない。 |

適用（zig-0.16.0 ソースツリーで）:

```sh
patch -p1 < /path/to/Mayflower/packages/zig/patches/src_link_MachO.zig.patch
```

## 梱包

```sh
ZIG_DIST_DIR=~/dev/zig-mayflower-prefix ./make.sh zig
```

## スコープ外

- zls
- `zig cc` のシステム CC 化
- `ZIG_NO_LDID`（作らない）

## CI（macos / LLVM stage3）

8GB Mac mini では LLVM 入り stage3 が OOM しやすい。GitHub Actions の
`zig-mayflower-macos` workflow でパッチ適用ビルドと artifact を作る。
