# python

ソースツリー: [`packages/python`](../packages/python)

CPython を rootless 脱獄 iOS 上でセルフビルドする。

## パッケージ情報

- 版: 3.14.7-3
- パッケージ構成:
  - `python3.14`: 版付きの名前のみ
  - `python3-default`: 版なしのシンボリックリンク（`Provides: python3`、`Conflicts`/`Replaces: python3`）

### パッケージ分割と同居

Debian と同じく版付きと版なしに分ける。`python3.14` は Procursus の
`python3` 3.9.9 と同居できる。`python3-default` を入れると `python`・`python3`・
`pip3`・`pydoc3`・`python3-config` がこちらを向き、Procursus の `python3` が外れる。
`idle3` と `2to3` は出さない（3.13 で `lib2to3` が消え、`idlelib` は tkinter が要るため）。

`rdepends` 上 Procursus の `python3` に依存する物は無く、実際に使っているのは
git の `git-p4` だけで、これは新しい `python3` で動く。

## ビルドの要点

### darwin として建てる

darwin として建てる（`--build=aarch64-apple-darwin`）。CPython 3.13 以降は
PEP 730 で iOS を公式にサポートしているが、App Store の制約を前提にした構成で、
プロセス生成を落とす方向に寄っている。脱獄機では subprocess が使えてこそ
意味があるため、この公式サポートは使わない。`uname -m` が `iPhone10,1` を返すので
`--build=aarch64-apple-darwin` を明示する。

### -target の明示

`-target arm64-apple-ios16.0` の指定が必須。`--build=...darwin` と名乗ると
configure の Darwin 判定が走り、OS の版を読んで `MACOSX_DEPLOYMENT_TARGET=16.7`
（iOS の版）を採用する。これが環境変数として clang に渡ると iPhoneOS の sysroot を
macOS 向けに読む状態になり、可用性マクロが噛み合わず `getentropy` が未宣言になって
落ちる。`-target` を明示することで抑える。

### パッチ構成

適用するパッチは以下の3点:
1. `Modules/posixmodule.c`: `system` を `mayflower_system` に差し替える。
2. `Lib/urllib/request.py`: `_scproxy` 不在を許容する。
3. `Lib/subprocess.py`: `shell=True` のシェルを `/var/jb/bin/sh` に向ける。
4. `Modules/_posixsubprocess.c`: shebang 直 `execve` が Dopamine で EPERM
   になるので、Mach-O の `/var/jb/bin/sh` 経由でやり直す。fishhook は使わない
   （iOS 16 の chained fixups で SIGSEGV する）。

`_scproxy` は macOS の SystemConfiguration からプロキシ設定を読むモジュールだが、
使っている定数がすべて `API_UNAVAILABLE(ios)` であるため `Modules/Setup.local` で
無効化する。

### configure の検出回避

iOS SDK は宣言を出さないが libSystem にシンボルはある関数が存在する。configure は
リンクで見つけて `HAVE_*` を立てるが、コンパイル時に
`-Werror=implicit-function-declaration` で落ちるため、以下を指定して代替経路へ落とす:
- `ac_cv_func_getentropy=no`: iOS の `sys/random.h` に宣言が無いため `/dev/urandom` へ落とす。
- `ac_cv_func_clock_settime=no`: iOS では root が要るうえ意味がないため外す。

なお、`ios_compat` のヘッダを `-include` で全体に入れてはいけない。
改名用ヘッダが `<stdlib.h>` を先に読むと、autoconf の古い形式の関数検出が
本物のプロトタイプを rename の前に見てしまい、`wait` / `waitpid` /
`realpath` / `getpriority` / `ptsname` などの一連の関数がまとめて「無い」と
判定されてしまうためである。

### ensurepip を使わないパッケージング

`make install ENSUREPIP=no` でインストールし、同梱の wheel を
`--ignore-installed --root` で手動で入れる。make install の ensurepip は
ビルドツリーの `./python`（`sys.prefix` が `/var/jb/usr`）を使うため、既に
python3.14 を入れた端末で梱包し直すと `Requirement already satisfied` と判定され
pip が .deb に入らなくなるためである。

### 依存関係の検査

拡張モジュール（`lib-dynload/*.so`）は `@rpath/...` でリンクされており
`dpkg -S` では引けないため、依存は `otool -L` で辿って確認する。この追跡により
`libgdbm6` と `libuuid16` の依存抜けが判明し、3.14.7-2 で修正された。
gettext が入っている端末では `libintl.h` で `_localemodule` が gettext を呼ぶのに
configure の `-lintl` 試験は no になる。3.14.7-3 で `LIBS += -lintl` と
`libintl8` を足した。
