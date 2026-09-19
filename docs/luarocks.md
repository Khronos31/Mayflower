# luarocks

ソースツリー: [`packages/luarocks`](../packages/luarocks)

LuaRocks 3.13.0。Lua 5.5 専用。

## パッケージ情報

- パッケージ名: `luarocks`（Procursus に無い）
- 版: 3.13.0-3
- Depends: `lua5.5`, `liblua5.5-0`, `liblua5.5-dev`, `unzip`, `curl`

ユーザートリーは `~/.luarocks`。システムツリーは `/var/jb/usr/local`。

## ビルドの要点

C コンパイラはほぼ使わない。`configure` に `--lua-version=5.5` と
`--with-lua-interpreter=lua5.5` を渡さないと、PATH の `lua` を掴む。

`io.popen("pwd")` は Lua 側の `mayflower_popen`（`/var/jb/bin/sh`）が要る。
LuaRocks 側にも、popen が空のとき `PWD` / `HOME` に落ちるパッチを当てている。

C 拡張を `luarocks install` するときは Mayflower の `bin/cc` を `CC` と `LD`
に渡し、`CFLAGS=-target arm64-apple-ios16.0` を付ける。`gcc` は端末に無い。

iPhone 8 で `luasocket` / `luasec` / `lua-cjson` / `lua-messagepack` を
`--local` で入れて、TCP ループバック・HTTPS・JSON・MessagePack を確認した。

### Dopamine shebang（pkgrel 3）

上流の `luarocks` / `luarocks-admin` は `#!/usr/bin/env lua` のスクリプト。
`/usr/bin/env` は rootless に無く、Dopamine では PATH 入り口の shebang が
`posix_spawn` EPERM になる。スクリプトは `/var/jb/usr/libexec/luarocks/` に
置き、`/var/jb/usr/bin` には `lua5.5` + スクリプトを argv に渡す Mach-O
ラッパーを置く（`files/mayflower-exec.c`、npm と同じ）。
