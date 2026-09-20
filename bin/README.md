# Mayflower のビルド用 PATH ツール

`cc` / `c++` / `make` は `make.sh` の `ensure_bin_wrappers` が
`files/mayflower-cc.c` と `files/mayflower-make.c` から Mach-O として建てる。

Git に載せているのはプレースホルダ（UTF-8 テキスト）だけ。端末で
`./make.sh` すると Mach-O に置き換わる。shebang スクリプトに戻さないこと。
Dopamine では shebang の `posix_spawn` が EPERM になる。
