# git

ソースツリー: [`packages/git`](../packages/git)

Git 2.56.0 を、rootless 脱獄 iOS 上でセルフビルドする。

## パッケージ情報

- 版: 2.56.0-1
- `git-2.56`: PATH の `git-2.56` は libexec の実体を呼ぶ Mach-O ラッパー。
  shebang は Dopamine で `posix_spawn` が EPERM になる。
  版付き名を直接実行すると、2.55 と同じく本体が `2.56` を subcommand と取る。
  通常の入口は `git-default` が用意する `git` コマンド。
  helpers は `/usr/libexec/git-2.56`
- フックの shebang は `run-command.c` が EPERM / ENOEXEC で
  `SHELL_PATH`（`/var/jb/bin/sh`）経由に回す。
- `git-default`: PATH の `git`。`Provides` / `Conflicts` / `Replaces: git`
  で Procursus の 2.39.1 を置換する
- 2.55 から両 deb を `dpkg -i` で更新する場合は、旧 `git-default` を
  一時的に deconfigure するため `--auto-deconfigure` を付ける。

gettext / Tcl/Tk / expat / gitweb は建てない。HTTPS は Procursus の libcurl + OpenSSL。
Perl モジュールは `share/perl5/Git-2.56` に置き、Procursus の `Git.pm` と同居する。
