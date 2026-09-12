# swift（Swift 6.1）

ソースツリー: [`packages/swift`](../packages/swift)

llvm（Clang 19）とは**別パッケージ**。Depends は `clang-19`。

| パッケージ | 内容 |
|---|---|
| `swift-6.1` | 版付き `swift-6.1` / `swiftc-6.1`（ランタイム同梱は dist 次第） |

Procursus の `swift` / `swift-5.9.2` は置換しない（`libllvm16` 逆依存があるため慎重に）。

ビルドは Mac の [`tools/mac/llvm-swift/`](../tools/mac/llvm-swift/)。
