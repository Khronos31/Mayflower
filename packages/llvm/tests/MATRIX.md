# clang-19 / lld ldid 検証マトリクス

実行: `bash packages/llvm/tests/ldid-matrix.sh`（実機、`clang-19` 導入後）

| ID | パターン | 期待 |
|---|---|---|
| C1 | `clang -fuse-ld=lld hello.c` | 手動 `ldid` なしで実行可 |
| C2 | `clang++` | 同上 |
| C3 | `-g`（dsymutil） | dsymutil 後も実行可 |
| C4 | `CLANG_NO_LDID=1` + `LLD_NO_LDID=1` | 未署名。手動 `ldid -S` で回復 |
| C5 | `CLANG_LDID_ENTITLEMENTS=plist` | 実行可 |
| L1 | 直接 `ld64.lld`（可能なとき） | lld 内 ldid で実行可 |
| D1 | `-shared` dylib + リンク | 実行可 |
| D2 | `-bundle` | リンク成功 |
| A1 | `llvm-ar` → `.a` → link | 実行可 |
| A2 | `llvm-nm` / `llvm-ranlib` | アーカイブ読める |
| F1 | `-fuse-ld=` 非 lld（Procursus `ld`） | clang ドライバ側 ldid で実行可 |
| O1 | `-O2` | 実行可 |
| O2 | `-flto` | できれば実行可（環境次第で SKIP 可） |
| M1 | 複数 `.o` | 実行可 |

## 同梱ツール方針（llvm-ar ほか）

`clang-19` に LLVM binutils 相当を **版付きで同梱**する。出力に `ldid` は不要（アーカイブ等）。ツール本体の署名はパッケージ化時。

| ツール | PATH symlink | 役割 |
|---|---|---|
| `clang` / `clang++` / `clang-cpp` | `*-19` | コンパイラ |
| `lld` / `ld64.lld` / `ld.lld` | `lld-19` など | リンカ（ldid 主担当） |
| `llvm-ar` / `llvm-ranlib` / `llvm-nm` | `*-19` | 静的ライブラリ |
| `llvm-config` | `llvm-config-19` | ビルド補助 |
| その他 (`llvm-objdump` 等) | ツリー内にあれば同梱、必須 symlink は後回し | 必要になったら追加 |

Swift 系は `swift-6.1` パッケージ。`clang-cl` / `wasm-ld` / `lld-link` は iOS では使わないが、ツリーに残っていても害は小さい。
