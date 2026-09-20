# Mayflower build PATH tools

`cc`, `c++`, and `make` here are built as Mach-O by `ensure_bin_wrappers` in
`make.sh` from `files/mayflower-cc.c` and `files/mayflower-make.c`.
Do not restore shebang scripts — Dopamine `posix_spawn` returns EPERM on them.

The tracked files here are tiny text placeholders so the tree is complete on
non-device hosts. `ensure_bin_wrappers` replaces them with Mach-O on first
on-device `./make.sh` (it rejects non-Mach-O outputs, not just mtime).
