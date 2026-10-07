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

def replace_exact(old: bytes, new: bytes, label: str, expected_count: int = 1):
    if len(old) != len(new):
        raise SystemExit(f"{label}: length mismatch {len(old)} != {len(new)}")
    c = data.count(old)
    if c != expected_count:
        raise SystemExit(f"{label}: expected exactly {expected_count} occurrence(s), found {c}")
    data[:] = data.replace(old, new)
    print(f"{label}: replaced {c}")

def replace_padded(old: bytes, new: bytes, label: str, expected_count: int = 1):
    if len(new) > len(old):
        raise SystemExit(f"{label}: new longer than old")
    padded = new + b"\x00" * (len(old) - len(new))
    c = data.count(old)
    if c != expected_count:
        raise SystemExit(f"{label}: expected exactly {expected_count} occurrence(s), found {c}")
    data[:] = data.replace(old, padded)
    print(f"{label}: replaced {c}")

# 1) SharedArrayBuffer sleep → busy-wait (exact length)
replace_exact(
    # 2.1.293 renamed locals again (ke/se/xe/Ae → se/ce/Ae/Le); the wait Int32Array
    # is Ae and the sleep function is Le. Keep exact-length busy-wait.
    b"Ae=new Int32Array(new SharedArrayBuffer(4));function Le(e){Atomics.wait(Ae,0,0,e)}",
    b"Ae=0;function Le(e){for(var n=Date.now();Date.now()-n<e;);}/*xxxxxxxxxxxxxxxxxxx*/",
    "sab-sleep",
    1,
)
# Remaining SharedArrayBuffer sites left intact (NUL-pad inside JS breaks parse).
# Startup crash is covered by sab-sleep above; revisit per-version if needed.

# 2) CoreFoundation / CoreServices macOS versioned paths → iOS unversioned
replace_padded(
    b"/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation",
    b"/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation",
    "cf-path",
    6,
)
replace_padded(
    b"/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices",
    b"/System/Library/Frameworks/CoreServices.framework/CoreServices",
    "cs-path",
    3,
)

# 3) Force plaintext credential store (skip broken Darwin Keychain composer)
replace_exact(
    # 2.1.293: getSecureStorage is zn(); composer is M(b,T); T is the plaintext store.
    b"function zn(){if(K)return K;return M(b,T)}",
    b"function zn(){if(K)return K;return T/*M*/}",
    "plaintext-store",
    1,
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
SDKROOT="${SDKROOT:-$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || xcrun --show-sdk-path 2>/dev/null || true)}"
# Pin minos/sdk to match the patched binary (vtool ios 15.0/17.0), not the
# host SDK version that -arch-only would inherit (e.g. 18.4).
clang -dynamiclib -target arm64-apple-ios15.0 -isysroot "${SDKROOT}" \
  -install_name @executable_path/libsystemshim.dylib \
  -o "$SHIM_OUT" "$SHIM_C" \
  -Wl,-reexport_library,/usr/lib/libSystem.B.dylib
vtool -set-build-version ios 15.0 17.0 -replace -output "$SHIM_OUT" "$SHIM_OUT" 2>/dev/null || true
echo "shim: built $SHIM_OUT (ios15.0 target)"

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
