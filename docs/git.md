# git

ソースツリー: [`packages/git`](../packages/git)

Git 2.55.0 を、rootless 脱獄 iOS 上でセルフビルドする。

## パッケージ情報

- 版: 2.55.0-1
- `git-2.55`: PATH の `git-2.55` は libexec の実体を呼ぶラッパー。
  `git-2.55` という Mach-O 名だと本体が subcommand `2.55` と取る。
  helpers は `/usr/libexec/git-2.55`
- `git-default`: PATH の `git`。`Provides` / `Conflicts` / `Replaces: git`
  で Procursus の 2.39.1 を置換する

gettext / Tcl/Tk / expat / gitweb は建てない。HTTPS は Procursus の libcurl + OpenSSL。
Perl モジュールは `share/perl5/Git-2.55` に置き、Procursus の `Git.pm` と同居する。
