# jq

ソースツリー: [`packages/jq`](../packages/jq)

jq 1.8.2 を、rootless 脱獄 iOS 上でセルフビルドする。

## パッケージ情報

- 版: 1.8.2-1
- `libjq1`: `libjq.1.dylib`
- `jq-1.8`: 版付きの `jq-1.8`
- `libjq-dev`: ヘッダと `libjq.dylib`
- `jq-default`: PATH の `jq`。`Provides` / `Conflicts` / `Replaces: jq`
  で Procursus の 1.6 を置換する

正規表現は Procursus の `libonig5`。gettext / 文書は建てない。
