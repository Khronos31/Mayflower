# clang-19 / lld ldid 検証マトリクス

実行: `bash packages/llvm/tests/ldid-matrix.sh`（実機、`clang-19` 導入後）

```sh
export PATH="/var/jb/usr/lib/llvm-19/bin:$PATH"
# 作業ファイルは $HOME/tmp（/tmp だと SIGKILL されることがある）
bash packages/llvm/tests/ldid-matrix.sh
# KEEP=1 で作業ディレクトリを残す
```

署名の見方（dylib / bundle 含む）:

| 方法 | 見ること |
|---|---|
| `ldid -e FILE` | entitlements。空 `-S` でも plist / exit 0 になりがち。未署名は非0 |
| `otool -l FILE \| grep LC_CODE_SIGNATURE` | 署名ロードコマンドの有無（確実） |

---

## 経路（誰が ldid するか）

| ID | パターン | 署名担当 | 期待 |
|---|---|---|---|
| C1 | `clang -fuse-ld=lld hello.c` | **lld** | 手動 ldid なしで実行可 + 署名あり |
| C2 | `clang++` | lld | 同上 |
| C3 | `-g`（dsymutil） | lld → dsymutil 後に **clang** 再署名 | 実行可 + 署名あり |
| L1 | 直接 `ld64.lld` | **lld** | 実行可（可能なとき） |
| F1 | `-fuse-ld=` 非 lld（Procursus `ld`） | **clang Linker** | 実行可 + 署名あり |
| D1 | `-shared` dylib | lld | `ldid -e` / `otool` で署名あり。消費者も実行可 |
| D2 | `-bundle` | lld | リンク成功 + 署名あり |
| A1 | `llvm-ar` → `.a` → link | lld（最終 exe） | 実行可 |
| A2 | `llvm-nm` / `llvm-ranlib` | （対象外） | アーカイブ読める |
| O1 | `-O2` | lld | 実行可 |
| O2 | `-flto` | lld | できれば実行可（SKIP 可） |
| M1 | 複数 `.o` | lld | 実行可 |

---

## 環境変数マトリクス（網羅）

対象変数:

| 変数 | 効く場所 |
|---|---|
| `CLANG_NO_LDID` | clang（非 lld / dsymutil）**と** lld（どちらもスキップ） |
| `LLD_NO_LDID` | **lld のみ**スキップ（clang の非 lld 経路は動いたまま） |
| `CLANG_LDID_ENTITLEMENTS` | clang / lld 共通。plist パス。`ldid -S<path>` |

| ID | CLANG_NO_LDID | LLD_NO_LDID | CLANG_LDID_ENTITLEMENTS | 経路 | 期待 |
|---|---|---|---|---|---|
| E1 | unset | unset | unset | clang→lld | 署名あり・実行可（プレーン `-S`） |
| E2 | `1` | unset | unset | clang→lld | **未署名**（lld も CLANG_NO_LDID でスキップ） |
| E3 | unset | `1` | unset | clang→lld | **未署名**（lld だけスキップ） |
| E4 | `1` | `1` | unset | clang→lld | **未署名** |
| E5 | unset | unset | 有効な plist | clang→lld | 署名あり。`ldid -e` にその内容 |
| E6 | `1` | `1` | 有効な plist | clang→lld | **未署名**（ents は無視） |
| E7 | unset | unset | unset | clang→lld **`-g`** | dsymutil 後も署名あり・実行可 |
| E8 | `1` | `1` | unset | clang→lld **`-g`** | **未署名**（lld も dsymutil 後 clang もスキップ） |
| E9 | unset | `1` | unset | clang→lld **`-g`** | lld は未署名 → dsymutil 後 **clang が署名** → 実行可 |
| E10 | unset | unset | 有効な plist | clang→lld **`-g`** | 再署名後も `ldid -e` がその plist |
| E11 | unset | unset | unset | clang→**非 lld** | clang が署名・実行可 |
| E12 | `1` | unset | unset | clang→**非 lld** | **未署名**（clang スキップ。LLD_NO_LDID は無関係） |
| E13 | unset | `1` | unset | clang→**非 lld** | **署名あり**（lld 変数は非 lld に効かない） |
| E14 | unset | unset | 有効な plist | clang→**非 lld** | `ldid -e` がその plist |
| E15 | unset | unset | unset | clang→lld **dylib** | `ldid -e` / `otool` で署名あり |
| E16 | `1` | `1` | unset | clang→lld **dylib** | **未署名**（`ldid -e` 失敗 / LC なし） |
| E17 | unset | unset | unset | 直接 `ld64.lld` | 署名あり（可能なとき） |
| E18 | unset | `1` | unset | 直接 `ld64.lld` | **未署名** |
| E19 | 手動 `ldid -S` で E2/E4 成果物を回復 | — | — | — | 実行可に戻る |

メモ:

- `CLANG_NO_LDID` / `LLD_NO_LDID` は「何か入っていれば」スキップ（空文字は未設定扱いの実装。台本は `1` を使う）。
- 未署名でも環境によっては exec できることがある → その場合は **署名有無**（`ldid -e` / `otool`）を正とする。
- E9 が通れば「dsymutil 後の clang 再署名」が独立に効いている証拠。

---

## 同梱ツール方針（llvm-ar ほか）

`clang-19` に LLVM binutils 相当を **版付きで同梱**。アーカイブ出力に ldid 不要。ツール本体の署名は梱包時。

| ツール | PATH symlink | 役割 |
|---|---|---|
| `clang` / `clang++` / `clang-cpp` | `*-19` | コンパイラ |
| `lld` / `ld64.lld` / `ld.lld` | `lld-19` / `ld64.lld-19` など | リンカ（ldid 主担当） |
| `llvm-ar` / `llvm-ranlib` / `llvm-nm` | `*-19` | 静的ライブラリ |
| `llvm-config` | `llvm-config-19` | ビルド補助 |
| その他 (`llvm-objdump` 等) | ツリー内にあれば同梱、必須 symlink は後回し | 必要になったら追加 |

Swift 系は `swift-6.1`。`clang-cl` / `wasm-ld` / `lld-link` は iOS 用途外だが残してよい。

## 既知のパッチ前提

Apple `swift-6.1.1-RELEASE` の lld は Mach-O の platform check を常時エラーにする stub がある。
`patches-host/lld_macho_ios_platform.patch` で外さないと `ld64.lld` は iOS をリンクできない。
