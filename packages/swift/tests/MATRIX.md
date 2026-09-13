# swiftc / mayflower-swift-ld 検証マトリクス

実行（実機、`swift-6.1` 導入後）:

```sh
export CLANG_NO_LDID=1 LLD_NO_LDID=1
# 作業は $HOME/tmp
bash packages/swift/tests/ldid-matrix.sh
```

Swift ドライバは `ld` を直呼びする（clang のリンカドライバを通らない）。
署名は `mayflower-swift-ld`（`-tools-directory` または `bin/mayflower-swift-ld`）が担当。

| ID | 条件 | 期待 |
|---|---|---|
| S1 | CLANG_NO_LDID+LLD_NO_LDID | Mayflower ents + 実行可 |
| S2 | + SWIFT_NO_LDID | Mayflower ents **なし** |
| S3 | CLANG_NO_LDID のみ | 署名あり（Swift 経路） |
| S4 | LLD_NO_LDID のみ | 署名あり（Swift 経路） |
| S5 | CLANG_LDID_ENTITLEMENTS | カスタム ents |
| S6 | `-g` | dsymutil 後も署名 |
| S7 | `-emit-library` | dylib 署名 |
| S8 | `-O` | 署名 + 実行 |
| S9 | multi-file | 署名 + 実行 |
| S10 | SWIFT_NO_LDID → 手動 ldid | 回復して実行可 |
