# lua

ソースツリー: [`packages/lua`](../packages/lua)

Lua 5.5.1 を rootless 脱獄 iOS 上でセルフビルドする。

## パッケージ情報

Procursus は `lua5.4` / `liblua5.4-0` / `liblua5.4-dev` まで。5.5 は無い。
版なしの `lua` は alternatives で 5.4 のまま。

| パッケージ | 中身 |
|---|---|
| `lua5.5` | `lua5.5` / `luac5.5` |
| `liblua5.5-0` | `liblua5.5.0.dylib`（`@rpath/liblua5.5.0.dylib`） |
| `liblua5.5-dev` | `include/lua5.5/`、`liblua5.5.dylib`、`liblua5.5.a`、`lua5.5.pc` |
| `lua-default` | `lua` / `luac`（`lua5.5` を指す） |

版: 5.5.1-4

iPhone 8 / iOS 16.7.14 で `./make.sh lua` が通り、`lua5.5` / `liblua5.5-0` /
`liblua5.5-dev` を `dpkg -i` した。`lua-default` が `lua` / `luac` を 5.5 にする。

## ビルドの要点

上流 Makefile に `ios` ターゲットがある。`LUA_USE_IOS` で POSIX と dlopen を
付ける。`os.execute` は SDK の `system(3)` ではなく `mayflower_system` を呼ぶ。
共有ライブラリは上流が出さないので、同じ `.o` から `liblua5.5.0.dylib` をリンクし、
`lua` だけそれへ付け替える。`luac` は `luaU_dump` など `LUAI_FUNC`（非公開）を
使うので `liblua.a` のまま。

`LUA_ROOT` は `/var/jb/usr/`（パッチ）。`-target arm64-apple-ios16.0`。

### Dopamine shebang（pkgrel 4）

`liblua5.5.0.dylib` / `lua5.5` は既定 `LDFLAGS` の `-lmayflower_spawn -liosexec`
を引き、プロセス内で `posix_spawn` / `execve` の shebang を再試行する。
以前の `MYLDFLAGS` は `-lios_compat` だけを書いて既定 LDFLAGS を落としていた。
