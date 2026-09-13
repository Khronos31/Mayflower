#!/usr/bin/env bash
# Mayflower | packages/swift/tests/ldid-matrix.sh
# On-device matrix: swiftc link signing via mayflower-swift-ld.
# Always disable clang/lld auto-sign so only the Swift package path counts:
#   CLANG_NO_LDID=1 LLD_NO_LDID=1
# Workdir under $HOME/tmp (not /tmp — SIGKILL on some jb setups).
# Exit: number of failures

set -u
SWIFTC="${SWIFTC:-swiftc-6.1}"
SWIFT="${SWIFT:-swift-6.1}"

if [ -z "${SDKROOT:-}" ]; then
  for d in /var/jb/usr/share/SDKs/iPhoneOS.sdk; do
    [ -d "$d" ] || continue
    SDKROOT="$d"
    break
  done
fi
SWIFT_FLAGS=()
if [ -n "${SDKROOT:-}" ]; then
  SWIFT_FLAGS+=(-sdk "$SDKROOT")
fi

if [ -z "${TMPDIR:-}" ] || [ "$TMPDIR" = /tmp ] || [ "$TMPDIR" = /private/tmp ]; then
  TMPDIR="${HOME}/tmp"
fi
mkdir -p "$TMPDIR"
WORK="${TMPDIR}/mayflower-swift-ldid-matrix.$$"
mkdir -p "$WORK"
FAILS=0
PASS=0
SKIP=0
trap 'if [ "${KEEP:-0}" = 1 ] || [ "${FAILS:-0}" -gt 0 ]; then echo "work: $WORK" >&2; else rm -rf "$WORK"; fi' EXIT

have() { command -v "$1" >/dev/null 2>&1; }
ok() { PASS=$((PASS + 1)); printf '  PASS  %s\n' "$1"; }
fail() { FAILS=$((FAILS + 1)); printf '  FAIL  %s\n        %s\n' "$1" "$2" >&2; }
skip() { SKIP=$((SKIP + 1)); printf '  SKIP  %s (%s)\n' "$1" "$2"; }
section() { printf '\n== %s ==\n' "$1"; }

# Force clang/lld off for the whole matrix (Swift package must sign alone).
export CLANG_NO_LDID=1
export LLD_NO_LDID=1
unset CLANG_LDID_ENTITLEMENTS SWIFT_LDID_ENTITLEMENTS SWIFT_NO_LDID || true

cd "$WORK" || exit 1

cat >hello.swift <<'S'
print("hello")
S
cat >lib.swift <<'S'
public func add(_ a: Int, _ b: Int) -> Int { a + b }
S
cat >use.swift <<'S'
import LibAdd
print(add(2, 3))
S

ENT_CUSTOM="$WORK/custom.entitlements"
cat >"$ENT_CUSTOM" <<'P'
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.mayflower.swift-ldid-matrix</key><true/>
  <key>platform-application</key><true/>
</dict></plist>
P

has_mf_ents() {
  local f="$1"
  ldid -e "$f" 2>/dev/null | grep -q platform-application
}
has_custom_ents() {
  local f="$1"
  ldid -e "$f" 2>/dev/null | grep -q com.mayflower.swift-ldid-matrix
}
is_signed_lc() {
  local f="$1"
  if have otool; then
    otool -l "$f" 2>/dev/null | grep -q LC_CODE_SIGNATURE && return 0
  fi
  if have llvm-objdump; then
    llvm-objdump --macho --private-headers "$f" 2>/dev/null | grep -q LC_CODE_SIGNATURE && return 0
  fi
  return 1
}
assert_mf_signed() {
  local f="$1" label="$2"
  if has_mf_ents "$f"; then ok "$label (mayflower ents)"
  else fail "$label (expected mayflower ents)" "$f"; fi
}
assert_mf_unsigned() {
  local f="$1" label="$2"
  if has_mf_ents "$f"; then fail "$label (expected no mayflower ents)" "$f"
  else ok "$label (no mayflower ents)"; fi
}
can_exec() { local f="$1"; [ -x "$f" ] || return 1; "$f" >/dev/null 2>&1; }
assert_runs() {
  local f="$1" label="$2"
  if can_exec "$f"; then ok "$label (runs)"
  else fail "$label (exec)" "$f"; fi
}

swift_link() {
  local o="$1"; shift
  "$SWIFTC" "${SWIFT_FLAGS[@]}" -o "$o" "$@"
}

if ! have "$SWIFTC"; then
  echo "missing $SWIFTC" >&2
  exit 1
fi
if [ -z "${SDKROOT:-}" ]; then
  echo "missing SDKROOT" >&2
  exit 1
fi

printf 'SWIFTC=%s SDKROOT=%s\n' "$(command -v "$SWIFTC")" "$SDKROOT"
printf 'CLANG_NO_LDID=%s LLD_NO_LDID=%s\n' "${CLANG_NO_LDID:-}" "${LLD_NO_LDID:-}"
# Show whether tools-directory / wrapper is wired
"$SWIFTC" "${SWIFT_FLAGS[@]}" -v hello.swift -o /dev/null 2>"$WORK/v.err" || true
if grep -q mayflower-swift "$WORK/v.err" || grep -q 'mayflower-swift-tools/ld' "$WORK/v.err"; then
  ok "driver uses mayflower ld (from -v)"
else
  # tools-directory shows as path/ld
  if grep -E 'libexec/mayflower-swift-tools|/ld ' "$WORK/v.err" | head -1 | grep -q ld; then
    ok "driver ld path mentions tools (from -v)"
  else
    echo "---- -v (tail) ----"
    tail -5 "$WORK/v.err"
    skip "wrapper visible in -v" "inspect manually"
  fi
fi

section "S1 default hello (clang/lld NO_LDID)"
unset SWIFT_NO_LDID SWIFT_LDID_ENTITLEMENTS CLANG_LDID_ENTITLEMENTS || true
export CLANG_NO_LDID=1 LLD_NO_LDID=1
rm -f hello
if swift_link hello hello.swift 2>"$WORK/s1.err"; then
  assert_mf_signed ./hello "S1"
  assert_runs ./hello "S1"
else
  fail "S1 compile" "$(head -c 400 "$WORK/s1.err")"
fi

section "S2 SWIFT_NO_LDID"
export CLANG_NO_LDID=1 LLD_NO_LDID=1 SWIFT_NO_LDID=1
rm -f hello-n
if swift_link hello-n hello.swift 2>"$WORK/s2.err"; then
  assert_mf_unsigned ./hello-n "S2"
  # ld64 may still leave LC_CODE_SIGNATURE ad-hoc; that is OK
else
  fail "S2 compile" "$(head -c 400 "$WORK/s2.err")"
fi
unset SWIFT_NO_LDID

section "S3 CLANG_NO_LDID alone still signs (swift path)"
unset LLD_NO_LDID SWIFT_NO_LDID || true
export CLANG_NO_LDID=1
rm -f hello-c
if swift_link hello-c hello.swift 2>"$WORK/s3.err"; then
  assert_mf_signed ./hello-c "S3"
  assert_runs ./hello-c "S3"
else
  fail "S3 compile" "$(head -c 400 "$WORK/s3.err")"
fi

section "S4 LLD_NO_LDID alone still signs (swift path)"
unset CLANG_NO_LDID SWIFT_NO_LDID || true
export LLD_NO_LDID=1
rm -f hello-l
if swift_link hello-l hello.swift 2>"$WORK/s4.err"; then
  assert_mf_signed ./hello-l "S4"
  assert_runs ./hello-l "S4"
else
  fail "S4 compile" "$(head -c 400 "$WORK/s4.err")"
fi

section "S5 custom entitlements"
export CLANG_NO_LDID=1 LLD_NO_LDID=1
export CLANG_LDID_ENTITLEMENTS="$ENT_CUSTOM"
unset SWIFT_NO_LDID || true
rm -f hello-e
if swift_link hello-e hello.swift 2>"$WORK/s5.err"; then
  if has_custom_ents ./hello-e; then ok "S5 custom ents"; else fail "S5 custom ents" "$(ldid -e ./hello-e 2>&1 | head -c 200)"; fi
  assert_runs ./hello-e "S5"
else
  fail "S5 compile" "$(head -c 400 "$WORK/s5.err")"
fi
unset CLANG_LDID_ENTITLEMENTS

section "S6 -g (dsymutil re-sign if wrapper present)"
export CLANG_NO_LDID=1 LLD_NO_LDID=1
rm -f hello-g hello-g.dSYM
if swift_link hello-g -g hello.swift 2>"$WORK/s6.err"; then
  assert_mf_signed ./hello-g "S6"
  assert_runs ./hello-g "S6"
else
  fail "S6 compile" "$(head -c 400 "$WORK/s6.err")"
fi

section "S7 -emit-library dylib"
export CLANG_NO_LDID=1 LLD_NO_LDID=1
rm -f libAdd.dylib
if swift_link libAdd.dylib -emit-library -module-name LibAdd lib.swift 2>"$WORK/s7.err"; then
  assert_mf_signed ./libAdd.dylib "S7"
else
  # Some jb SDKs need extra flags; allow skip on hard link errors
  skip "S7 dylib" "$(head -c 160 "$WORK/s7.err" | tr '\n' ' ')"
fi

section "S8 -O"
export CLANG_NO_LDID=1 LLD_NO_LDID=1
rm -f hello-O
if swift_link hello-O -O hello.swift 2>"$WORK/s8.err"; then
  assert_mf_signed ./hello-O "S8"
  assert_runs ./hello-O "S8"
else
  fail "S8 compile" "$(head -c 400 "$WORK/s8.err")"
fi

section "S9 multi-file"
export CLANG_NO_LDID=1 LLD_NO_LDID=1
cat >a.swift <<'S'
func foo() -> Int { 7 }
S
cat >b.swift <<'S'
@main
struct Main {
  static func main() { print(foo()) }
}
S
rm -f multi
if swift_link multi a.swift b.swift 2>"$WORK/s9.err"; then
  assert_mf_signed ./multi "S9"
  assert_runs ./multi "S9"
else
  fail "S9 compile" "$(head -c 400 "$WORK/s9.err")"
fi

section "S10 recover unsigned with manual ldid"
export CLANG_NO_LDID=1 LLD_NO_LDID=1 SWIFT_NO_LDID=1
rm -f hello-r
if swift_link hello-r hello.swift 2>"$WORK/s10.err"; then
  assert_mf_unsigned ./hello-r "S10 before"
  if have ldid; then
    ENT=/var/jb/usr/lib/llvm-19/entitlements.plist
    [ -f "$ENT" ] || ENT=/var/jb/usr/lib/llvm-19/libexec/entitlements.plist
    if [ -f "$ENT" ]; then ldid -S"$ENT" ./hello-r; else ldid -S ./hello-r; fi
    assert_mf_signed ./hello-r "S10 after manual ldid"
    assert_runs ./hello-r "S10"
  else
    skip "S10 manual" "no ldid"
  fi
else
  fail "S10 compile" "$(head -c 400 "$WORK/s10.err")"
fi
unset SWIFT_NO_LDID

printf '\n== summary ==\npass=%s fail=%s skip=%s\n' "$PASS" "$FAILS" "$SKIP"
exit "$FAILS"
