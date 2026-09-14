# nim

ソースツリー: [`packages/nim`](../packages/nim)

Nim を rootless 脱獄 iOS 上でセルフビルドする。

## パッケージ情報

- パッケージ名: `nim`
- 版: 2.2.12-2
- 含まれるもの: コンパイラ、`nimble`、`atlas`、`nimsuggest`、`nimgrep`、`nimpretty`、`testament`
- Depends: `build-essential`, `clang`, `ldid`, `libiosexec1 (>= 1.3.1)`
- Recommends: `libpcre1`

## ビルドの要点

1. **warm と cold の両対応**:
   端末に nim が入っていればそれを種にしてビルドする（warm）。無ければ同梱の
   C ソース（csources）から立ち上げる（cold）。どちらの経路でも `koch boot`
   による自己再生成まで通る。
2. **cold 時のシステムコール**:
   cold では `system(3)` が iOS SDK で unavailable であり、かつ `/bin/sh` も
   存在しないため、`shim/ios_system.h` を `-include` し、別途コンパイルした
   `ios_system.o` をリンクして対処する。
3. **並列度の制御**:
   csources 版コンパイラは並列ビルドで `startProcess` 経由の `/bin/sh` を呼ぶため、
   `--parallelBuild:1` が必要となる（直列なら `system()` ＝ シム経由となる）。
4. **プラットフォームの指定**:
   `uname -m` が `iPhone10,1` を返すため、`ucpu=arm64` と `uos=darwin` は手動で
   与える。
5. **自己署名とチェック**:
   entitlements 付きの ldid 署名が無いと、生成バイナリは起動時に SIGKILL される。
   パッチによって nim 自身がリンク後に署名するようにし、ブートストラップ段は
   `bin/cc` ラッパーが肩代わりする。`check()` ではラッパー無しの素の `nim c` で
   `t_exec`、`t_ssl`、`nimgrep`（PCRE 読み込み）が動作することを検証する。
