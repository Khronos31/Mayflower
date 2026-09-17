# claude-code (Mayflower)

Unofficial Claude Code build for jailbroken iOS (iphoneos-arm64).

- Wrapper: `/var/jb/usr/bin/claude` (`BUN_JSC_useCodeCache=0`, `DISABLE_UPDATES=1`, `DISABLE_AUTOUPDATER=1`, `DISABLE_INSTALLATION_CHECKS=1`)
- Binary: `/var/jb/usr/libexec/claude-code/claude.bin`
- Shim: `/var/jb/usr/libexec/claude-code/libsystemshim.dylib`

See `/var/jb/usr/share/licenses/claude-code/NOTICE`.

## Updates

The wrapper sets `DISABLE_UPDATES=1`, `DISABLE_AUTOUPDATER=1`, and `DISABLE_INSTALLATION_CHECKS=1`
so Claude Code does not rewrite `~/.local/bin/claude` or self-update over
the Mayflower package. Prefer `apt` / a new Mayflower build for upgrades.
