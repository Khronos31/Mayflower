# ruby

ソースツリー: [`packages/ruby`](../packages/ruby)

CRuby を rootless 脱獄 iOS 上でセルフビルドする。

## パッケージ情報

- パッケージ名: `ruby`（Procursus に同名は無い）
- 版: 4.0.6-1
- YJIT / ZJIT: **建てない**。端末に rustc があると configure が既定で有効にするので、
  `--disable-yjit --disable-zjit` を明示する。あとで足す余地はある。
- Depends: `libssl3`, `libyaml-0-2`, `libffi8`, `libgmp10`, `libreadline8`,
  `libncursesw6`

端末でのビルドはまだ通していない。

## ビルドの要点

### darwin として建てる

`--build=aarch64-apple-darwin`。`uname -m` が `iPhone10,1` を返すので
`--build` を明示する。`--with-coroutine=arm64` は configure が
`arm64-darwin` なら同じものを選ぶが、ucontext へ落ちないように明示する。

`-target arm64-apple-ios16.0` を付けないと、Darwin 判定が
`MACOSX_DEPLOYMENT_TARGET` に iOS の版を入れ、clang が macOS モードになる
（Python と同じ）。

iOS SDK に `sys/vnode.h` は無い。`dir.c` が使う定数だけ XNU の値を置く
（`VT_HFS` 16、`VT_CIFS` 23、`VREG` 1、`VDIR` 2、`VLNK` 5）。

`getentropy` はヘッダが `API_UNAVAILABLE(ios)` なので、configure に
`ac_cv_func_getentropy=no` を渡す（`clock_settime` も同じ。Python と同じ）。

### シェル

rootless に `/bin/sh` は無い。パッチで次を `/var/jb/bin/sh` に向ける。

- `process.c` の `execve` / `execv` / `execle` / `execl` / `spawnv` / `spawnl`
  （Darwin は fork 経路なので後ろ2つはコンパイルされない）
- `ext/pty/pty.c` の既定シェル
- `lib/mkmf.rb` が Makefile に書く `SHELL`

`Kernel#system` は Darwin では fork+exec なので `system(3)` を使わない。
ただし `vm_dump.c` の `RUBY_ON_BUG` は `system(3)` を直呼びするので、
`ios_compat=1` で `mayflower_system` に差し替える。miniruby は `MAINLIBS`
経由でリンクする。

`ext/strscan` は `HAVE_RB_REG_ONIG_MATCH` が立たないと `ruby/re.h` の宣言と
衝突する。in-tree の 3.3 以降ではヘッダを正とする。

### 文書

`--disable-install-doc --disable-install-rdoc`。ri / rdoc の本体は入れない。

### ビルド時に要る開発用パッケージ

`libssl-dev` `libyaml-dev` `libffi-dev` `libgmp-dev` `libreadline-dev`
`libncurses-dev`。yaml はランタイムの `libyaml-0-2` が端末に無いことがある。
