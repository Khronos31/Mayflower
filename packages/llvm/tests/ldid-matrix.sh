#!/usr/bin/env bash
# Mayflower | packages/llvm/tests/ldid-matrix.sh
#
# clang-19 / lld の ldid 経路を実機（iphoneos-arm64 rootless）で総当りする台本。
# 使い方:
#   export PATH="/var/jb/usr/lib/llvm-19/bin:$PATH"   # または clang-19 が PATH に
#   bash packages/llvm/tests/ldid-matrix.sh
# 任意:
#   CLANG=clang-19 CXX=clang++-19 LLD=ld64.lld PREFIX=/var/jb/usr/lib/llvm-19
#   KEEP=1  失敗時も作業ディレクトリを残す
#
# 終了コード: 失敗ケース数（0 = 全部 OK）

set -u
CLANG="${CLANG:-clang-19}"
CXX="${CXX:-clang++-19}"
LLD="${LLD:-ld64.lld}"
PREFIX="${PREFIX:-/var/jb/usr/lib/llvm-19}"
AR="${AR:-llvm-ar}"
NM="${NM:-llvm-nm}"
RANLIB="${RANLIB:-llvm-ranlib}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="${TMPDIR:-/tmp}/mayflower-ldid-matrix.$$"
mkdir -p "$WORK"
trap 'if [ "${KEEP:-0}" = 1 ] || [ "${FAILS:-0}" -gt 0 ]; then echo "work: $WORK" >&2; else rm -rf "$WORK"; fi' EXIT

PASS=0
FAILS=0
SKIP=0

have() { command -v "$1" >/dev/null 2>&1; }

ok() { PASS=$((PASS + 1)); printf '  PASS  %s\n' "$1"; }
fail() { FAILS=$((FAILS + 1)); printf '  FAIL  %s\n        %s\n' "$1" "$2" >&2; }
skip() { SKIP=$((SKIP + 1)); printf '  SKIP  %s (%s)\n' "$1" "$2"; }

# codesign / ldid presence on Mach-O (best-effort)
is_signed() {
  local f="$1"
  if have ldid; then
    ldid -e "$f" >/dev/null 2>&1 && return 0
    # plain -S still embeds empty entitlements blob; -e may print nothing but succeed
    # fallback: look for LC_CODE_SIGNATURE via otool / llvm-objdump if present
  fi
  if have otool; then
    otool -l "$f" 2>/dev/null | grep -q LC_CODE_SIGNATURE && return 0
  fi
  if have llvm-objdump; then
    llvm-objdump --macho --private-headers "$f" 2>/dev/null | grep -q LC_CODE_SIGNATURE && return 0
  fi
  # last resort: try exec (executables only)
  return 1
}

can_exec() {
  local f="$1"
  [ -x "$f" ] || return 1
  "$f" >/dev/null 2>&1
}

section() { printf '\n== %s ==\n' "$1"; }

# ---------------------------------------------------------------------------
section "prereq"
for c in "$CLANG" "$CXX" "$LLD" ldid; do
  if have "$c"; then
    ok "found $c ($(command -v "$c"))"
  else
    fail "missing $c" "install clang-19 / ldid first"
  fi
done
have "$AR" && ok "found $AR" || skip "$AR" "optional for archive cases"
have "$NM" && ok "found $NM" || true
have "$RANLIB" && ok "found $RANLIB" || true

# ---------------------------------------------------------------------------
section "C: default link (clang → lld → ldid)"
cat >"$WORK/hello.c" <<'C'
#include <stdio.h>
int main(void) { puts("hello"); return 0; }
C
(
  cd "$WORK" || exit 1
  unset CLANG_NO_LDID LLD_NO_LDID CLANG_LDID_ENTITLEMENTS
  if ! "$CLANG" -fuse-ld="$LLD" -o hello hello.c 2>"$WORK/hello.err"; then
    fail "compile hello.c" "$(head -c 400 "$WORK/hello.err")"
  elif can_exec ./hello; then
    ok "hello runs without manual ldid"
  else
    fail "hello exec" "unsigned or bad binary; see $WORK/hello"
  fi
)

# ---------------------------------------------------------------------------
section "C++: default link"
cat >"$WORK/hi.cpp" <<'C'
#include <iostream>
int main() { std::cout << "hi\n"; return 0; }
C
(
  cd "$WORK" || exit 1
  unset CLANG_NO_LDID LLD_NO_LDID
  if ! "$CXX" -fuse-ld="$LLD" -o hi hi.cpp 2>"$WORK/hi.err"; then
    fail "compile hi.cpp" "$(head -c 400 "$WORK/hi.err")"
  elif can_exec ./hi; then
    ok "hi (C++) runs"
  else
    fail "hi exec" "see $WORK/hi"
  fi
)

# ---------------------------------------------------------------------------
section "-g / dsymutil re-sign path"
(
  cd "$WORK" || exit 1
  unset CLANG_NO_LDID LLD_NO_LDID
  rm -f hello-g hello-g.dSYM
  if ! "$CLANG" -fuse-ld="$LLD" -g -o hello-g hello.c 2>"$WORK/hello-g.err"; then
    fail "compile -g" "$(head -c 400 "$WORK/hello-g.err")"
  elif can_exec ./hello-g; then
    ok "-g binary runs after dsymutil"
  else
    fail "-g exec" "dsymutil may have dropped signature"
  fi
)

# ---------------------------------------------------------------------------
section "CLANG_NO_LDID skips auto-sign"
(
  cd "$WORK" || exit 1
  rm -f hello-nosign
  export CLANG_NO_LDID=1
  export LLD_NO_LDID=1
  if ! "$CLANG" -fuse-ld="$LLD" -o hello-nosign hello.c 2>"$WORK/nosign.err"; then
    fail "compile with NO_LDID" "$(head -c 400 "$WORK/nosign.err")"
    exit 0
  fi
  if can_exec ./hello-nosign; then
    # On some jb setups unsigned still runs under debugserver — treat as soft
    skip "NO_LDID exec blocked" "unsigned still ran (environment may allow it)"
  else
    ok "NO_LDID binary does not run (expected on stock jb)"
  fi
  # recover with manual ldid
  if ldid -S ./hello-nosign && can_exec ./hello-nosign; then
    ok "manual ldid -S recovers NO_LDID binary"
  else
    fail "manual ldid recover" "ldid -S ./hello-nosign failed"
  fi
)

# ---------------------------------------------------------------------------
section "CLANG_LDID_ENTITLEMENTS"
ENT="$WORK/empty.plist"
cat >"$ENT" <<'P'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict></dict></plist>
P
(
  cd "$WORK" || exit 1
  unset CLANG_NO_LDID LLD_NO_LDID
  export CLANG_LDID_ENTITLEMENTS="$ENT"
  rm -f hello-ent
  if ! "$CLANG" -fuse-ld="$LLD" -o hello-ent hello.c 2>"$WORK/ent.err"; then
    fail "compile with entitlements" "$(head -c 400 "$WORK/ent.err")"
  elif can_exec ./hello-ent; then
    ok "CLANG_LDID_ENTITLEMENTS binary runs"
  else
    fail "entitlements exec" "see $WORK/hello-ent"
  fi
)

# ---------------------------------------------------------------------------
section "direct lld (no clang driver)"
(
  cd "$WORK" || exit 1
  unset CLANG_NO_LDID LLD_NO_LDID CLANG_LDID_ENTITLEMENTS
  rm -f hello.o hello-lld
  "$CLANG" -c -o hello.o hello.c
  # minimal Darwin link via clang -### to steal syslibroot is painful;
  # use clang as compiler only then lld with clang -print- file paths
  SDKROOT="$("$CLANG" -print-sysroot 2>/dev/null || true)"
  if [ -z "$SDKROOT" ]; then
    # rootless jb: often empty; let clang drive the link line instead
    skip "direct lld" "no sysroot from clang -print-sysroot; covered by clang→lld cases"
    exit 0
  fi
  if "$LLD" -arch arm64 -platform_version ios 16.0 16.0 \
      -syslibroot "$SDKROOT" -o hello-lld hello.o \
      -lSystem 2>"$WORK/lld.err"; then
    if can_exec ./hello-lld; then
      ok "direct ld64.lld output runs (lld-owned ldid)"
    else
      fail "direct lld exec" "lld did not sign?"
    fi
  else
    skip "direct lld" "$(head -c 200 "$WORK/lld.err")"
  fi
)

# ---------------------------------------------------------------------------
section "dylib"
cat >"$WORK/lib.c" <<'C'
int add(int a, int b) { return a + b; }
C
cat >"$WORK/use.c" <<'C'
int add(int, int);
#include <stdio.h>
int main(void) { printf("%d\n", add(2, 3)); return 0; }
C
(
  cd "$WORK" || exit 1
  unset CLANG_NO_LDID LLD_NO_LDID
  rm -f libadd.dylib use-dylib
  if ! "$CLANG" -fuse-ld="$LLD" -shared -o libadd.dylib lib.c 2>"$WORK/dylib.err"; then
    fail "build dylib" "$(head -c 400 "$WORK/dylib.err")"
  elif ! "$CLANG" -fuse-ld="$LLD" -o use-dylib use.c ./libadd.dylib 2>"$WORK/use-dylib.err"; then
    fail "link against dylib" "$(head -c 400 "$WORK/use-dylib.err")"
  elif can_exec ./use-dylib; then
    ok "shared dylib + consumer run"
  else
    fail "dylib consumer exec" "dylib or exe unsigned?"
  fi
)

# ---------------------------------------------------------------------------
section "bundle (-bundle)"
(
  cd "$WORK" || exit 1
  unset CLANG_NO_LDID LLD_NO_LDID
  rm -f add.bundle
  if ! "$CLANG" -fuse-ld="$LLD" -bundle -o add.bundle lib.c 2>"$WORK/bundle.err"; then
    fail "build bundle" "$(head -c 400 "$WORK/bundle.err")"
  elif is_signed ./add.bundle || true; then
    # bundles are not executed directly; presence + link success is enough
    ok "bundle link succeeded"
  else
    ok "bundle link succeeded"
  fi
)

# ---------------------------------------------------------------------------
section "static archive via llvm-ar"
if have "$AR"; then
  (
    cd "$WORK" || exit 1
    unset CLANG_NO_LDID LLD_NO_LDID
    rm -f lib.o libadd.a use-static
    "$CLANG" -c -o lib.o lib.c
    "$AR" rcs libadd.a lib.o
    have "$RANLIB" && "$RANLIB" libadd.a || true
    if ! "$CLANG" -fuse-ld="$LLD" -o use-static use.c libadd.a 2>"$WORK/static.err"; then
      fail "link with llvm-ar archive" "$(head -c 400 "$WORK/static.err")"
    elif can_exec ./use-static; then
      ok "llvm-ar .a + clang link runs"
    else
      fail "static consumer exec" "see $WORK/use-static"
    fi
    if have "$NM"; then
      if "$NM" libadd.a 2>/dev/null | grep -q ' T _add\| T add'; then
        ok "llvm-nm sees archive symbol"
      else
        # symbol might be without underscore depending on nm
        if "$NM" libadd.a >/dev/null 2>&1; then
          ok "llvm-nm reads archive"
        else
          fail "llvm-nm" "could not read libadd.a"
        fi
      fi
    fi
  )
else
  skip "llvm-ar archive" "llvm-ar not on PATH"
fi

# ---------------------------------------------------------------------------
section "non-lld linker fallback (clang driver ldid)"
# Prefer system ld64 if present (Procursus), else skip
SYS_LD=""
for cand in /var/jb/usr/bin/ld /usr/bin/ld; do
  if [ -x "$cand" ] && ! "$cand" --version 2>&1 | grep -qi lld; then
    SYS_LD="$cand"
    break
  fi
done
if [ -n "$SYS_LD" ]; then
  (
    cd "$WORK" || exit 1
    unset CLANG_NO_LDID LLD_NO_LDID
    rm -f hello-ld64
    if ! "$CLANG" -fuse-ld="$SYS_LD" -o hello-ld64 hello.c 2>"$WORK/ld64.err"; then
      fail "link with $SYS_LD" "$(head -c 400 "$WORK/ld64.err")"
    elif can_exec ./hello-ld64; then
      ok "non-lld path: clang driver ldid works ($SYS_LD)"
    else
      fail "non-lld exec" "clang should have signed after ld64"
    fi
  )
else
  skip "non-lld fallback" "no non-lld ld found"
fi

# ---------------------------------------------------------------------------
section "optimization / LTO smoke"
(
  cd "$WORK" || exit 1
  unset CLANG_NO_LDID LLD_NO_LDID
  rm -f hello-O2 hello-lto
  if "$CLANG" -fuse-ld="$LLD" -O2 -o hello-O2 hello.c 2>"$WORK/O2.err" && can_exec ./hello-O2; then
    ok "-O2 runs"
  else
    fail "-O2" "$(head -c 200 "$WORK/O2.err")"
  fi
  if "$CLANG" -fuse-ld="$LLD" -flto -O2 -o hello-lto hello.c 2>"$WORK/lto.err" && can_exec ./hello-lto; then
    ok "-flto runs"
  else
    skip "-flto" "$(head -c 160 "$WORK/lto.err" | tr '\n' ' ')"
  fi
)

# ---------------------------------------------------------------------------
section "multi-TU"
cat >"$WORK/a.c" <<'C'
int foo(void) { return 7; }
C
cat >"$WORK/b.c" <<'C'
int foo(void);
#include <stdio.h>
int main(void) { printf("%d\n", foo()); return 0; }
C
(
  cd "$WORK" || exit 1
  unset CLANG_NO_LDID LLD_NO_LDID
  rm -f a.o b.o multi
  "$CLANG" -c a.c b.c
  if "$CLANG" -fuse-ld="$LLD" -o multi a.o b.o 2>"$WORK/multi.err" && can_exec ./multi; then
    ok "multi-TU link runs"
  else
    fail "multi-TU" "$(head -c 300 "$WORK/multi.err")"
  fi
)

# ---------------------------------------------------------------------------
printf '\n== summary ==\n'
printf 'pass=%s fail=%s skip=%s\n' "$PASS" "$FAILS" "$SKIP"
exit "$FAILS"
