# tmux

ソースツリー: [`packages/tmux`](../packages/tmux)

[tmux](https://github.com/tmux/tmux) 3.7c を、rootless 脱獄 iOS 上でセルフビルドする。

## パッケージ情報

- 版: 3.7c-1
- `tmux-3.7`: 版付きの `tmux-3.7`
- `tmux-default`: PATH の `tmux`。`Provides` / `Conflicts` / `Replaces: tmux`
  で Procursus の 3.4 を置換する

Depends は `libevent-2.1-7` と `libncursesw6`（どちらも Procursus）。
`libutf8proc` は使わない（Procursus の `-dev` が存在しない `libutf8proc2` を要求する）。

## ビルドの要点

公式 release tarball を使う。`configure` は同梱だが yacc 検査があるので bison が要る。
Darwin 系は jemalloc を明示しないと止まるので `--disable-jemalloc`。

rootless には `/bin/sh` が無い。`run-shell` / `if-shell` / `#()` が参照する
`_PATH_BSHELL` を `/var/jb/bin/sh`（dash）に差し替える。ペインのシェルは
`$SHELL`（zsh）のまま。

iOS SDK は `system(3)` と `libproc.h` が無い。前者は fork+exec の代替、
後者は `osdep-darwin.c` を sysctl 側に落とす。

IOKit は不要。ルートの薄い entitlements で足りる。

## 端末

```sh
sudo apt install libevent-dev bison   # ビルド時。utf8proc-dev は入れない
./make.sh tmux
sudo dpkg -i packages/tmux/arm64/tmux-3.7_*.deb packages/tmux/arm64/tmux-default_*.deb
tmux -V
tmux new -s work
```

エージェントの長い `cargo` / `make.sh` は tmux セッション内で回す。
