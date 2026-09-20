# perl

ソースツリー: [`packages/perl`](../packages/perl)

Perl をパッケージングする。

## パッケージ情報

- 版: 5.42.0-1
- Procursus の `perl` 5.32.1 と同名にしない。`perl5.42` と `perl-default`。
- `perl-default` は `Provides` / `Conflicts` / `Replaces: perl` で 5.32.1 を置換する。
- `system` / `exec` / バッククォート / パイプ open は `/var/jb/bin/sh`。shebang は EPERM / ENOEXEC / ENOENT で同じ sh を再試行。libiosexec は付けない。

## 建て方

端末（ip8）でセルフビルド。Configure は darwin として名乗り、`-target arm64-apple-ios16.0` で iOS SDK を固定する。`-Dsh=/var/jb/bin/sh`。

```sh
./make.sh perl
```
