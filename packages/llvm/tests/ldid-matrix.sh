#!/usr/bin/env bash
# Mayflower | packages/llvm/tests/ldid-matrix.sh
# Serial on-device matrix for clang-19 / lld ldid + env branches.
#   export PATH="/var/jb/usr/lib/llvm-19/bin:$PATH"   # or smoke tree bin
#   bash packages/llvm/tests/ldid-matrix.sh
# Optional: CLANG CXX LLD AR NM RANLIB SDKROOT KEEP=1
# Workdir is under $HOME/tmp (not /tmp — SIGKILL on some jb setups).
# Exit: number of failures

set -u
CLANG="${CLANG:-clang-19}"
CXX="${CXX:-clang++-19}"
LLD="${LLD:-lld}"   # -fuse-ld flavor; clang resolves ld64.lld
AR="${AR:-llvm-ar}"
NM="${NM:-llvm-nm}"
RANLIB="${RANLIB:-llvm-ranlib}"

if [ -z "${SDKROOT:-}" ]; then
  for d in /var/jb/usr/share/SDKs/iPhoneOS.sdk; do
    [ -d "$d" ] || continue
    SDKROOT="$d"
    break
  done
fi
# shellcheck disable=SC2206
CLANG_FLAGS=()
if [ -n "${SDKROOT:-}" ]; then
  CLANG_FLAGS+=(-isysroot "$SDKROOT")
fi

# /tmp 上の Mach-O は jb 環境で SIGKILL されることがある。$HOME 配下を使う。
if [ -z "${TMPDIR:-}" ] || [ "$TMPDIR" = /tmp ] || [ "$TMPDIR" = /private/tmp ]; then
  TMPDIR="${HOME}/tmp"
fi
mkdir -p "$TMPDIR"
WORK="${TMPDIR}/mayflower-ldid-matrix.$$"
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
clear_env() { unset CLANG_NO_LDID LLD_NO_LDID CLANG_LDID_ENTITLEMENTS || true; }

cc_link() { local o="$1"; shift; "$CLANG" "${CLANG_FLAGS[@]}" -fuse-ld="$LLD" -o "$o" "$@"; }
cxx_link() { local o="$1"; shift; "$CXX" "${CLANG_FLAGS[@]}" -fuse-ld="$LLD" -o "$o" "$@"; }
cc_c() { "$CLANG" "${CLANG_FLAGS[@]}" -c "$@"; }
cc_link_ld() { local ld="$1" o="$2"; shift 2; "$CLANG" "${CLANG_FLAGS[@]}" -fuse-ld="$ld" -o "$o" "$@"; }

is_signed() {
  local f="$1"
  if have otool; then
    otool -l "$f" 2>/dev/null | grep -q LC_CODE_SIGNATURE && return 0
  fi
  if have llvm-objdump; then
    llvm-objdump --macho --private-headers "$f" 2>/dev/null | grep -q LC_CODE_SIGNATURE && return 0
  fi
  if have ldid; then
    ldid -e "$f" >/dev/null 2>&1 && return 0
  fi
  return 1
}
assert_signed() {
  local f="$1" label="$2"
  if is_signed "$f"; then ok "$label (signed)"
  else fail "$label (expected signed)" "$f"; fi
}
assert_unsigned() {
  local f="$1" label="$2"
  if is_signed "$f"; then fail "$label (expected unsigned)" "$f still has signature"
  else ok "$label (unsigned)"; fi
}
can_exec() { local f="$1"; [ -x "$f" ] || return 1; "$f" >/dev/null 2>&1; }
assert_runs() {
  local f="$1" label="$2"
  if can_exec "$f"; then ok "$label (runs)"
  else fail "$label (expected run)" "$f"; fi
}
assert_ents_contain() {
  local f="$1" needle="$2" label="$3" out
  out="$(ldid -e "$f" 2>/dev/null || true)"
  if printf '%s' "$out" | grep -q "$needle"; then ok "$label (ents contain $needle)"
  elif is_signed "$f"; then skip "$label ents check" "signed but ldid -e lacked '$needle'"
  else fail "$label ents" "not signed / no '$needle'"; fi
}

ENT_CUSTOM="$WORK/custom.plist"
cat >"$ENT_CUSTOM" <<'P'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.mayflower.ldid-matrix</key><true/>
</dict></plist>
P

cat >"$WORK/hello.c" <<'C'
#include <stdio.h>
int main(void) { puts("hello"); return 0; }
C
cat >"$WORK/lib.c" <<'C'
int add(int a, int b) { return a + b; }
C
cat >"$WORK/use.c" <<'C'
int add(int, int);
#include <stdio.h>
int main(void) { printf("%d\n", add(2, 3)); return 0; }
C

cd "$WORK" || exit 1

section "prereq"
for c in "$CLANG" "$CXX" ldid; do
  if have "$c"; then ok "found $c ($(command -v "$c"))"
  else fail "missing $c" "install clang-19 / ldid first"; fi
done
# LLD is a flavor; ensure ld64.lld exists on PATH
if have ld64.lld || have lld; then ok "found lld/ld64.lld"
else fail "missing lld" "need ld64.lld on PATH"; fi
if [ -n "${SDKROOT:-}" ]; then ok "SDKROOT=$SDKROOT"
else fail "SDKROOT" "set SDKROOT to iPhoneOS.sdk"; fi
have otool && ok "found otool" || skip "otool" "weaker signing checks"
have "$AR" && ok "found $AR" || skip "$AR" "archive cases"

section "C1/C2/C3 paths"
clear_env
rm -f hello hi hello-g
if cc_link hello hello.c 2>"$WORK/c1.err"; then assert_signed ./hello "C1 hello signed"; assert_runs ./hello "C1 hello"
else fail "C1 compile" "$(head -c 400 "$WORK/c1.err")"; fi

cat >hi.cpp <<'C'
#include <iostream>
int main() { std::cout << "hi\n"; return 0; }
C
if cxx_link hi hi.cpp 2>"$WORK/c2.err"; then assert_signed ./hi "C2 hi signed"; assert_runs ./hi "C2 hi"
else fail "C2 compile" "$(head -c 400 "$WORK/c2.err")"; fi

if cc_link hello-g -g hello.c 2>"$WORK/c3.err"; then assert_signed ./hello-g "C3 -g signed"; assert_runs ./hello-g "C3 -g"
else fail "C3 compile" "$(head -c 400 "$WORK/c3.err")"; fi

section "env matrix E1-E6 (clang→lld)"
clear_env
rm -f e1
if cc_link e1 hello.c 2>"$WORK/e1.err"; then assert_signed ./e1 "E1 default"; assert_runs ./e1 "E1"
else fail "E1 compile" "$(head -c 300 "$WORK/e1.err")"; fi

clear_env; export CLANG_NO_LDID=1
rm -f e2
if cc_link e2 hello.c 2>"$WORK/e2.err"; then assert_unsigned ./e2 "E2 CLANG_NO_LDID"
else fail "E2 compile" "$(head -c 300 "$WORK/e2.err")"; fi

clear_env; export LLD_NO_LDID=1
rm -f e3
if cc_link e3 hello.c 2>"$WORK/e3.err"; then assert_unsigned ./e3 "E3 LLD_NO_LDID"
else fail "E3 compile" "$(head -c 300 "$WORK/e3.err")"; fi

clear_env; export CLANG_NO_LDID=1 LLD_NO_LDID=1
rm -f e4
if cc_link e4 hello.c 2>"$WORK/e4.err"; then assert_unsigned ./e4 "E4 both NO_LDID"
else fail "E4 compile" "$(head -c 300 "$WORK/e4.err")"; fi

clear_env; export CLANG_LDID_ENTITLEMENTS="$ENT_CUSTOM"
rm -f e5
if cc_link e5 hello.c 2>"$WORK/e5.err"; then
  assert_signed ./e5 "E5 ents"; assert_runs ./e5 "E5"
  assert_ents_contain ./e5 "com.mayflower.ldid-matrix" "E5"
else fail "E5 compile" "$(head -c 300 "$WORK/e5.err")"; fi

clear_env
export CLANG_NO_LDID=1 LLD_NO_LDID=1 CLANG_LDID_ENTITLEMENTS="$ENT_CUSTOM"
rm -f e6
if cc_link e6 hello.c 2>"$WORK/e6.err"; then assert_unsigned ./e6 "E6 ents+NO_LDID"
else fail "E6 compile" "$(head -c 300 "$WORK/e6.err")"; fi

if [ -f e4 ]; then
  if ldid -S ./e4 && can_exec ./e4; then ok "E19 manual ldid recovers e4"
  else fail "E19 recover" "ldid -S e4"; fi
fi

section "env matrix E7-E10 (-g / dsymutil)"
clear_env
rm -f e7
if cc_link e7 -g hello.c 2>"$WORK/e7.err"; then assert_signed ./e7 "E7 -g default"; assert_runs ./e7 "E7"
else fail "E7 compile" "$(head -c 300 "$WORK/e7.err")"; fi

clear_env; export CLANG_NO_LDID=1 LLD_NO_LDID=1
rm -f e8
if cc_link e8 -g hello.c 2>"$WORK/e8.err"; then assert_unsigned ./e8 "E8 -g both NO_LDID"
else fail "E8 compile" "$(head -c 300 "$WORK/e8.err")"; fi

clear_env; export LLD_NO_LDID=1
rm -f e9
if cc_link e9 -g hello.c 2>"$WORK/e9.err"; then
  assert_signed ./e9 "E9 -g LLD_NO_LDID (clang dsymutil resign)"
  assert_runs ./e9 "E9"
else fail "E9 compile" "$(head -c 300 "$WORK/e9.err")"; fi

clear_env; export CLANG_LDID_ENTITLEMENTS="$ENT_CUSTOM"
rm -f e10
if cc_link e10 -g hello.c 2>"$WORK/e10.err"; then
  assert_signed ./e10 "E10 -g ents"
  assert_ents_contain ./e10 "com.mayflower.ldid-matrix" "E10"
else fail "E10 compile" "$(head -c 300 "$WORK/e10.err")"; fi

section "env matrix E11-E14 (non-lld)"
SYS_LD=""
for cand in /var/jb/usr/bin/ld /usr/bin/ld; do
  [ -x "$cand" ] || continue
  if "$cand" -v 2>&1 | grep -qi lld; then continue; fi
  if "$cand" --version 2>&1 | grep -qi lld; then continue; fi
  SYS_LD="$cand"
  break
done
if [ -n "$SYS_LD" ]; then
  clear_env
  rm -f e11
  if cc_link_ld "$SYS_LD" e11 hello.c 2>"$WORK/e11.err"; then
    assert_signed ./e11 "E11 non-lld default"; assert_runs ./e11 "E11"
  else fail "E11 compile" "$(head -c 300 "$WORK/e11.err")"; fi

  clear_env; export CLANG_NO_LDID=1
  rm -f e12
  if cc_link_ld "$SYS_LD" e12 hello.c 2>"$WORK/e12.err"; then
    # Apple/Procursus ld64 still writes LC_CODE_SIGNATURE (ad-hoc). We only
    # assert clang did NOT apply Mayflower entitlements via ldid.
    if ldid -e ./e12 2>/dev/null | grep -q platform-application; then
      fail "E12 non-lld CLANG_NO_LDID" "clang still applied entitlements.plist"
    else
      ok "E12 non-lld CLANG_NO_LDID (clang skipped ldid; ld64 ad-hoc ok)"
    fi
  else fail "E12 compile" "$(head -c 300 "$WORK/e12.err")"; fi

  clear_env; export LLD_NO_LDID=1
  rm -f e13
  if cc_link_ld "$SYS_LD" e13 hello.c 2>"$WORK/e13.err"; then
    assert_signed ./e13 "E13 non-lld LLD_NO_LDID (clang still signs)"
    assert_runs ./e13 "E13"
  else fail "E13 compile" "$(head -c 300 "$WORK/e13.err")"; fi

  clear_env; export CLANG_LDID_ENTITLEMENTS="$ENT_CUSTOM"
  rm -f e14
  if cc_link_ld "$SYS_LD" e14 hello.c 2>"$WORK/e14.err"; then
    assert_signed ./e14 "E14 non-lld ents"
    assert_ents_contain ./e14 "com.mayflower.ldid-matrix" "E14"
  else fail "E14 compile" "$(head -c 300 "$WORK/e14.err")"; fi
else
  skip "E11-E14" "no non-lld ld found"
fi

section "D1/D2 + E15/E16 dylib"
clear_env
rm -f libadd.dylib use-dylib add.bundle e16.dylib
if cc_link libadd.dylib -shared lib.c 2>"$WORK/d1.err"; then
  assert_signed ./libadd.dylib "D1/E15 dylib signed"
  if cc_link use-dylib use.c ./libadd.dylib 2>"$WORK/d1u.err"; then assert_runs ./use-dylib "D1 consumer"
  else fail "D1 consumer link" "$(head -c 300 "$WORK/d1u.err")"; fi
else fail "D1 dylib" "$(head -c 300 "$WORK/d1.err")"; fi

if cc_link add.bundle -bundle lib.c 2>"$WORK/d2.err"; then assert_signed ./add.bundle "D2 bundle signed"
else fail "D2 bundle" "$(head -c 300 "$WORK/d2.err")"; fi

clear_env; export CLANG_NO_LDID=1 LLD_NO_LDID=1
if cc_link e16.dylib -shared lib.c 2>"$WORK/e16.err"; then assert_unsigned ./e16.dylib "E16 dylib NO_LDID"
else fail "E16 dylib" "$(head -c 300 "$WORK/e16.err")"; fi

section "E17/E18 direct lld"
clear_env
rm -f hello.o e17 e18
if cc_c -o hello.o hello.c 2>"$WORK/e17c.err"; then
  if [ -z "${SDKROOT:-}" ]; then skip "E17/E18" "no SDKROOT"
  elif ld64.lld -arch arm64 -platform_version ios 16.0 16.0 \
      -syslibroot "$SDKROOT" -o e17 hello.o -lSystem 2>"$WORK/e17.err"; then
    assert_signed ./e17 "E17 direct lld"; assert_runs ./e17 "E17"
  else skip "E17" "$(head -c 160 "$WORK/e17.err" | tr '\n' ' ')"; fi

  clear_env; export LLD_NO_LDID=1
  if ld64.lld -arch arm64 -platform_version ios 16.0 16.0 \
      -syslibroot "$SDKROOT" -o e18 hello.o -lSystem 2>"$WORK/e18.err"; then
    assert_unsigned ./e18 "E18 direct LLD_NO_LDID"
  else skip "E18" "$(head -c 160 "$WORK/e18.err" | tr '\n' ' ')"; fi
else
  fail "E17 compile .o" "$(head -c 200 "$WORK/e17c.err")"
fi

section "A1/A2 archives"
if have "$AR"; then
  clear_env
  rm -f lib.o libadd.a use-static
  cc_c -o lib.o lib.c
  "$AR" rcs libadd.a lib.o
  have "$RANLIB" && "$RANLIB" libadd.a || true
  if cc_link use-static use.c libadd.a 2>"$WORK/a1.err"; then
    assert_signed ./use-static "A1 static signed"; assert_runs ./use-static "A1"
  else fail "A1" "$(head -c 300 "$WORK/a1.err")"; fi
  if have "$NM" && "$NM" libadd.a >/dev/null 2>&1; then ok "A2 llvm-nm"
  else skip "A2 llvm-nm" "nm missing or failed"; fi
else
  skip "A1/A2" "no llvm-ar"
fi

section "O1/O2/M1"
clear_env
rm -f hello-O2 hello-lto a.o b.o multi
if cc_link hello-O2 -O2 hello.c 2>"$WORK/o1.err" && can_exec ./hello-O2; then assert_signed ./hello-O2 "O1 -O2"
else fail "O1" "$(head -c 200 "$WORK/o1.err")"; fi

if cc_link hello-lto -flto -O2 hello.c 2>"$WORK/o2.err" && can_exec ./hello-lto; then assert_signed ./hello-lto "O2 -flto"
else skip "O2 -flto" "$(head -c 120 "$WORK/o2.err" | tr '\n' ' ')"; fi

cat >a.c <<'C'
int foo(void) { return 7; }
C
cat >b.c <<'C'
int foo(void);
#include <stdio.h>
int main(void) { printf("%d\n", foo()); return 0; }
C
cc_c a.c b.c
if cc_link multi a.o b.o 2>"$WORK/m1.err" && can_exec ./multi; then assert_signed ./multi "M1 multi-TU"
else fail "M1" "$(head -c 300 "$WORK/m1.err")"; fi

printf '\n== summary ==\npass=%s fail=%s skip=%s\n' "$PASS" "$FAILS" "$SKIP"
printf 'SDKROOT=%s LLD=%s\n' "${SDKROOT:-}" "$LLD"
exit "$FAILS"
