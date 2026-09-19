# Mayflower build PATH tools

`cc`, `c++`, and `make` here are built as Mach-O by `ensure_bin_wrappers` in
`make.sh` from `files/mayflower-cc.c` and `files/mayflower-make.c`.
Do not restore shebang scripts — Dopamine `posix_spawn` returns EPERM on them.
