# mirakc-arib

ソースツリー: [`packages/mirakc-arib`](../packages/mirakc-arib)

[mirakc-arib](https://github.com/mirakc/mirakc-arib) 0.9.1。ARIB TS を読む
`scan-services` / `sync-clocks` / `collect-eits` / `filter-service` /
`filter-program` など。mirakc の jobs と filters がこれを呼ぶ。

## パッケージ情報

- 版: 0.9.1-3
- パッケージ: `mirakc-arib`
- PATH: `/var/jb/usr/bin/mirakc-arib`（Mach-O。ラッパ無し）
- ビルド: **Mac**（`tools/mac/mirakc-arib/build.sh`）
- ソース: GitHub タグ `0.9.1`（`mirakc/mirakc-arib`）
- Depends: 無し（tsduck-arib / aribb24 / fmt / spdlog は静的リンク）
- Procursus: 無し（新規）

## 建て方

**端末の上で cmake しない。** tsduck は Darwin ホストを macOS とみなし、
`libproc.h` と `/usr/local/include` を引く。aribb24 は `./bootstrap` する。

```sh
# Mac
export MAYFLOWER=~/dev/Mayflower
export PATH=~/ios-tools:$PATH
"$MAYFLOWER/tools/mac/mirakc-arib/build.sh"

# 端末
MIRAKC_ARIB_DIST_DIR=/path/to/dist ./make.sh mirakc-arib
sudo dpkg -i packages/mirakc-arib/arm64/mirakc-arib_*.deb
mirakc-arib --version
```

パッチは `packages/mirakc-arib/patches-host/`。母艦で当てるので
`make.sh` の `applyPatch` の対象には含めない。

- CMake: `SPDLOG_FMT_EXTERNAL=OFF`（Homebrew の fmt を掴まない）、
  aribb24 の `CC`/`CXX` に ios-clang を渡す、`COMMON_WARNINGS=-Wall`
  （`-Werror` の reserved-id で tsduck が落ちる）
- tsduck-arib: macOS 専用の `/usr/local/include` と `libtsduck/mac` を外す。
  iPhone では `libproc.h` が無いので `_NSGetExecutablePath` を使う
- collect-eits の Component / AudioComponent JSON に mirakc 3.4.86 が
  要求するフィールドを足す（欠けていると serde がセクションごと捨て、
  番組名が空になる）
- 直前の3時間 EIT セグメントは捨てない（8時開始の番組が9時台に消える）

SDK は Node と同じく Xcode の iPhoneOS（`ios-clang`）。triple は
`arm64-apple-ios16.0`。

## 端末上での実行

mirakc の `config.yml` ではフルパスを書く。

```yaml
jobs:
  scan-services:
    command: /var/jb/usr/bin/mirakc-arib scan-services
  sync-clocks:
    command: /var/jb/usr/bin/mirakc-arib sync-clocks
  update-schedules:
    command: /var/jb/usr/bin/mirakc-arib collect-eits
filters:
  service-filter:
    command: /var/jb/usr/bin/mirakc-arib filter-service
  program-filter:
    command: /var/jb/usr/bin/mirakc-arib filter-program
```

ログは既定で出ない。`MIRAKC_ARIB_LOG=info` を付ける。
