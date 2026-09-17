#!/usr/bin/env bash
# Apply Mayflower iOS patches to a Claude Code darwin-arm64 Mach-O in-place.
# Usage: patch-ios.sh <path-to-claude-binary> <dir-for-libsystemshim.dylib>
set -euo pipefail

BIN="${1:?claude binary}"
OUTDIR="${2:?output dir for libsystemshim.dylib}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHIM_C="${ROOT}/shim.c"
ENTS="${ROOT}/entitlements-jit.plist"
ENTFILE="${ENTFILE:-${ENTS}}"

if [[ ! -f "$BIN" ]]; then
  echo "patch-ios: missing binary: $BIN" >&2
  exit 1
fi
mkdir -p "$OUTDIR"

python3 - "$BIN" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = bytearray(path.read_bytes())

def replace_exact(old: bytes, new: bytes, label: str, min_count: int = 1):
    if len(old) != len(new):
        raise SystemExit(f"{label}: length mismatch {len(old)} != {len(new)}")
    c = data.count(old)
    if c < min_count:
        raise SystemExit(f"{label}: expected >= {min_count} occurrence(s), found {c}")
    data[:] = data.replace(old, new)
    print(f"{label}: replaced {c}")

def replace_padded(old: bytes, new: bytes, label: str, min_count: int = 1):
    if len(new) > len(old):
        raise SystemExit(f"{label}: new longer than old")
    padded = new + b"\x00" * (len(old) - len(new))
    c = data.count(old)
    if c < min_count:
        raise SystemExit(f"{label}: expected >= {min_count} occurrence(s), found {c}")
    data[:] = data.replace(old, padded)
    print(f"{label}: replaced {c}")

# 1) SharedArrayBuffer sleep → busy-wait (exact length)
replace_exact(
    # 2.1.274 renamed locals (st/X/ct/ut → lt/j/dt/mt); keep exact-length busy-wait.
    b"var lt=4,j=50,dt=new Int32Array(new SharedArrayBuffer(4));function mt(t){Atomics.wait(dt,0,0,t)}",
    b"var lt=4,j=50,dt=0;function mt(t){for(var e=Date.now();Date.now()-e<t;);}/*xxxxxxxxxxxxxxxxxxx*/",
    "sab-sleep",
)
# Remaining SharedArrayBuffer sites left intact (NUL-pad inside JS breaks parse).
# Startup crash is covered by sab-sleep above; revisit per-version if needed.

# 2) CoreFoundation / CoreServices macOS versioned paths → iOS unversioned
replace_padded(
    b"/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation",
    b"/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation",
    "cf-path",
)
replace_padded(
    b"/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices",
    b"/System/Library/Frameworks/CoreServices.framework/CoreServices",
    "cs-path",
)

# 3) Force plaintext credential store (skip broken Darwin Keychain composer)
replace_exact(
    # 2.1.274: getSecureStorage is In(); composer is k(T,R) not v(E,_).
    b"function In(){if(U)return U;return k(T,R)}",
    b"function In(){if(U)return U;return R/*T*/}",
    "plaintext-store",
)

path.write_bytes(data)
print("wrote", path, "bytes", len(data))
PY

# 4) Platform → iOS
if command -v vtool >/dev/null 2>&1; then
  vtool -set-build-version ios 15.0 17.0 -replace -output "$BIN" "$BIN"
  echo "vtool: ios 15.0/17.0"
else
  echo "patch-ios: vtool not found" >&2
  exit 1
fi

# 5) Build libsystemshim and retarget libSystem
SHIM_OUT="${OUTDIR}/libsystemshim.dylib"
SDKROOT="${SDKROOT:-$(xcrun --show-sdk-path 2>/dev/null || true)}"
clang -dynamiclib -arch arm64 -isysroot "${SDKROOT}" \
  -install_name @executable_path/libsystemshim.dylib \
  -o "$SHIM_OUT" "$SHIM_C" \
  -Wl,-reexport_library,/usr/lib/libSystem.B.dylib
echo "shim: built $SHIM_OUT"

# Change libSystem load to shim (match whatever install name the binary uses)
if otool -L "$BIN" | grep -q 'libSystem.B.dylib'; then
  install_name_tool -change /usr/lib/libSystem.B.dylib @executable_path/libsystemshim.dylib "$BIN"
  echo "install_name_tool: libSystem → shim"
fi

# 6) Sign
if command -v ldid >/dev/null 2>&1; then
  ldid -S"$ENTFILE" "$BIN"
  ldid -S"$ENTFILE" "$SHIM_OUT"
  echo "ldid: signed bin+shim with $ENTFILE"
else
  echo "patch-ios: ldid not found" >&2
  exit 1
fi

echo "patch-ios: OK $BIN"
