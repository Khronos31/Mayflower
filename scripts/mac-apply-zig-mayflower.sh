#!/bin/bash
# Run ON Mac mini (machineId 02dec2b3-2187-41e7-b218-a7e8114f6e26) as ゆの 長嶺.
# Applies Mayflower Zig MachO patch, builds host zig, smokes hello on ip8,
# commits on zig-0.16-wip (no merge).
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH"

MF="${MF:-$HOME/dev/Mayflower}"
SMOKE="${SMOKE:-$HOME/dev/zig-smoke}"
SRC="${SRC:-$SMOKE/zig-0.16.0}"
HOST_ZIG="${HOST_ZIG:-$SMOKE/zig-aarch64-macos-0.16.0/zig}"
PREFIX="${PREFIX:-$SMOKE/zig-mayflower-prefix}"
ENT="${ENT:-$MF/entitlements.plist}"
HANDOFF_TGZ="${1:-}"

if [ -n "$HANDOFF_TGZ" ]; then
  tar -xzf "$HANDOFF_TGZ" -C /tmp
  # expect Mayflower-zig-handoff/{docs,packages,scripts}
  HANDOFF="$(echo /tmp/Mayflower-zig-handoff* | awk '{print $1}')"
  mkdir -p "$MF/packages/zig/patches" "$MF/docs" "$MF/scripts"
  cp -R "$HANDOFF/packages/zig/." "$MF/packages/zig/"
  cp "$HANDOFF/docs/zig.md" "$MF/docs/zig.md"
  cp "$HANDOFF/scripts/mac-apply-zig-mayflower.sh" "$MF/scripts/" || true
fi

cd "$MF"
git fetch origin || true
git checkout zig-0.16-wip 2>/dev/null || git checkout -b zig-0.16-wip
git status -sb

test -d "$SRC" || { echo "missing $SRC" >&2; exit 1; }
test -x "$HOST_ZIG" || { echo "missing $HOST_ZIG" >&2; exit 1; }
test -f "$MF/packages/zig/patches/src_link_MachO.zig.patch"

cd "$SRC"
# idempotent-ish: reverse then apply
patch -p1 -R --dry-run < "$MF/packages/zig/patches/src_link_MachO.zig.patch" >/dev/null 2>&1 \
  && patch -p1 -R < "$MF/packages/zig/patches/src_link_MachO.zig.patch" || true
patch -p1 < "$MF/packages/zig/patches/src_link_MachO.zig.patch"

# Build patched host zig into PREFIX
rm -rf "$PREFIX"
mkdir -p "$PREFIX"
# zig build installs to zig-out; stage into PREFIX
"$HOST_ZIG" build -Doptimize=ReleaseFast -Dno-langref --prefix "$PREFIX"

ZIG_BIN="$PREFIX/bin/zig"
if [ ! -x "$ZIG_BIN" ]; then
  # older layouts put zig at prefix root
  ZIG_BIN="$PREFIX/zig"
fi
test -x "$ZIG_BIN"
"$ZIG_BIN" version

# Locate iPhoneOS SDK
SDK="$(ls -d "$HOME/Downloads/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS"*.sdk 2>/dev/null | head -1 || true)"
if [ -z "$SDK" ]; then
  SDK="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)"
fi
test -n "$SDK" && test -d "$SDK"

WORK="$SMOKE/mayflower-hello"
rm -rf "$WORK"
mkdir -p "$WORK"
cat > "$WORK/hello.zig" <<'ZIG'
const std = @import("std");
pub fn main() void {
    std.debug.print("hello\n", .{});
}
ZIG

# Prefer an existing libc kit under zig-smoke if present
LIBC_ARGS=()
if [ -f "$SMOKE/libc.txt" ]; then
  LIBC_ARGS=(--libc "$SMOKE/libc.txt")
fi

cd "$WORK"
export ZIG_LDID_ENTITLEMENTS="$ENT"
"$ZIG_BIN" build-exe hello.zig -target aarch64-ios -mcpu=apple_a11 \
  --sysroot "$SDK" "${LIBC_ARGS[@]}" -fno-strip

echo "=== ldid -e ==="
ldid -e ./hello || true
file ./hello
otool -hv ./hello | head -20 || true

echo "=== push to ip8 via ha ==="
# pipe binary; avoid /tmp on device
ssh ha "ssh ip8 'mkdir -p ~/dev/zig-smoke && cat > ~/dev/zig-smoke/hello && chmod +x ~/dev/zig-smoke/hello && ~/dev/zig-smoke/hello'" < ./hello

echo "=== commit Mayflower tree ==="
cd "$MF"
git add docs/zig.md packages/zig
git status -sb
git commit -m "$(cat <<'MSG'
zig: ios device link via system clang, ldid last

Self-hosted Mach-O SIGILLs on ip8. For ios (non-simulator) Exe/dylib,
MachO.flush delegates final link to clang then runs ldid last
(ZIG_LDID_ENTITLEMENTS, Go-style). No ZIG_NO_LDID; do not auto-set
CLANG_NO_LDID/LLD_NO_LDID.
MSG
)" || echo "nothing to commit?"
git push -u origin zig-0.16-wip

echo "DONE — update PR #44 body if needed; do not merge"
