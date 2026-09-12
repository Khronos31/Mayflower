# node

ソースツリー: [`packages/node`](../packages/node)

Node.js をパッケージングする。

## パッケージ情報

- 版: 24.21.0-1（LTS Krypton）
- パッケージ構成:
  - `nodejs-24`: 版付きの `node-24` / `npm-24` / `npx-24`。実体は `/var/jb/usr/lib/nodejs-24/node-bin`
  - `node-default`: `/var/jb/usr/bin` の `node` / `npm` / `npx`。
    `Provides: nodejs, npm`。`Conflicts` / `Replaces: npm` で Procursus の
    npm 8.1.1 を置換する（`python3-default` と同じ形）。

ios-ports の `nodejs-ios24` とは名前を分け、あちらへの `Conflicts` は付けない。

## 建て方とパッケージング

**Node は端末の上で建てない。** ホスト用 V8 を同時に建てるため、RAM 1.93GB の
iPhone 8 では成立しない。

Mac でのクロスビルドは [`tools/mac/node/build.sh`](../tools/mac/node/build.sh)。
clang ラッパーは Rust と同じ `~/ios-tools`。**SDK だけ Xcode の iPhoneOS**（端末 SDK
16.2 の libc++ に `std::ranges` が無く、ada / simdjson が落ちる）。triple は
`arm64-apple-ios16.0` のまま。configure は
`--dest-os=ios --dest-cpu=arm64 --cross-compiling`。

パッチは `packages/node/patches-host/` にあり、母艦側で適用するため
`make.sh` の `applyPatch` の対象には含めない。

- c-ares の `<sys/random.h>`（iPhoneOS SDK に無い）
- macOS Keychain の証明書読み込み（iOS に API が無い）

端末側では `NODE_DIST_DIR` に tarball の場所を渡して実行する:

```sh
NODE_DIST_DIR=/path/to/dist ./make.sh node
```

## 端末上での実行

`node-24` は既定で V8 に `--jitless` を付ける。Dopamine では JIT 用の実行可能
メモリ確保が SIGBUS になる。palera1n で JIT を試すときは
`NODE_IOS_ALLOW_JIT=1`。実体は JIT 用 entitlements 付きで署名してある。

npm のグローバル prefix はラッパーが `NPM_CONFIG_PREFIX=/var/jb/usr` に固定する。
