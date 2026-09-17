#!/var/jb/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/claude-code/make.sh
#
# Unofficial Anthropic Claude Code for jailbroken iOS (iphoneos-arm64).
# Downloads official darwin-arm64 Mach-O from npm, patches for iOS, installs:
#   /var/jb/usr/bin/claude                      (wrapper; Bun cache + updater disables)
#   /var/jb/usr/libexec/claude-code/claude.bin  (patched binary)
#   /var/jb/usr/libexec/claude-code/libsystemshim.dylib
#
# Patching requires macOS host tools: vtool, install_name_tool, clang, ldid.
# Optional: CLAUDE_CODE_DARWIN_BIN=/path/to/claude to skip npm download.

pkgname=claude-code
pkgver=2.1.274
pkgrel=1
srcname="claude-code-darwin-arm64-${pkgver}"
source="https://registry.npmjs.org/@anthropic-ai/claude-code-darwin-arm64/-/claude-code-darwin-arm64-${pkgver}.tgz"
export compress=xz

# npm の tarball は package/ に展開されるので、common.sh の download() は使わない。
download() {
  local tarball
  tarball="$(basename "${source}")"
  if [ ! -r "${PROJECTROOT}/${tarball}" ]; then
    curl -fsSL -o "${PROJECTROOT}/${tarball}" "${source}"
  fi
  # prepare() が srcdir へ取り出す
}


prepare() {
  cd "${BUILDROOT}" || return 1
  rm -rf "${srcdir}"
  mkdir -p "${srcdir}"

  if [ -n "${CLAUDE_CODE_DARWIN_BIN:-}" ]; then
    cp -f "${CLAUDE_CODE_DARWIN_BIN}" "${srcdir}/claude"
    chmod 755 "${srcdir}/claude"
  else
    local tarball="${PROJECTROOT}/$(basename "${source}")"
    if [ ! -f "${tarball}" ]; then
      echo "prepare: missing ${tarball}" >&2
      return 1
    fi
    local tmp="${BUILDROOT}/npm-extract"
    rm -rf "${tmp}"
    mkdir -p "${tmp}"
    tar -xzf "${tarball}" -C "${tmp}"
    if [ -f "${tmp}/package/claude" ]; then
      cp -f "${tmp}/package/claude" "${srcdir}/claude"
      cp -f "${tmp}/package/LICENSE.md" "${srcdir}/LICENSE.md" 2>/dev/null || true
      cp -f "${tmp}/package/README.md" "${srcdir}/README.md" 2>/dev/null || true
    else
      echo "prepare: package/claude not in npm tarball" >&2
      return 1
    fi
    chmod 755 "${srcdir}/claude"
  fi

  cp -f "${PROJECTROOT}/files/claude" "${srcdir}/claude.wrapper"
  chmod 755 "${srcdir}/claude.wrapper"
}

build() {
  cd "${srcdir}" || return 1
  case "$(uname -s)" in
    Darwin) ;;
    *)
      echo "build: patching requires macOS (vtool/install_name_tool/clang/ldid)" >&2
      return 1
      ;;
  esac
  export ENTFILE="${ENTFILE:-${PROJECTROOT}/entitlements-jit.plist}"
  "${PROJECTROOT}/scripts/patch-ios.sh" "${srcdir}/claude" "${srcdir}"
}

check() {
  cd "${srcdir}" || return 1
  file "${srcdir}/claude" | grep -qi 'arm64' || return 1
  vtool -show-build "${srcdir}/claude" 2>/dev/null | grep -qi ios || {
    echo "check: expected ios build version in Mach-O" >&2
    return 1
  }
  test -f "${srcdir}/libsystemshim.dylib"
  otool -L "${srcdir}/claude" | grep -q 'libsystemshim.dylib'
  python3 -c "import pathlib; d=pathlib.Path(r'${srcdir}/claude').read_bytes(); assert b'return R/*T*/' in d; assert b'dt=0;function mt(t){for(var e=Date.now()' in d; assert b'/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation' in d; assert b'/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation' not in d"
  # shim minos should be ios 15.x-aligned, not host SDK 18.x
  vtool -show-build "${srcdir}/libsystemshim.dylib" 2>/dev/null | grep -E 'minos|sdk' | head -5 || true
  if vtool -show-build "${srcdir}/libsystemshim.dylib" 2>/dev/null | grep -q 'minos 18\.'; then
    echo "check: libsystemshim minos still looks like host SDK 18.x" >&2
    return 1
  fi
  echo "check: OK (structural)"
}

package() {
  local libexec="${pkgdir}${JB}/usr/libexec/claude-code"
  install -d "${pkgdir}${JB}/usr/bin" \
    "${libexec}" \
    "${pkgdir}${JB}/usr/share/doc/claude-code" \
    "${pkgdir}${JB}/usr/share/licenses/claude-code"

  install -m755 "${srcdir}/claude" "${libexec}/claude.bin"
  install -m755 "${srcdir}/libsystemshim.dylib" "${libexec}/libsystemshim.dylib"
  install -m755 "${srcdir}/claude.wrapper" "${pkgdir}${JB}/usr/bin/claude"

  install -m644 "${PROJECTROOT}/files/usr/share/doc/claude-code/README.md" \
    "${pkgdir}${JB}/usr/share/doc/claude-code/"
  install -m644 "${PROJECTROOT}/files/usr/share/licenses/claude-code/NOTICE" \
    "${pkgdir}${JB}/usr/share/licenses/claude-code/"
  install -m644 "${PROJECTROOT}/files/usr/share/licenses/claude-code/Mayflower-LICENSE" \
    "${pkgdir}${JB}/usr/share/licenses/claude-code/"
  if [ -f "${srcdir}/LICENSE.md" ]; then
    install -m644 "${srcdir}/LICENSE.md" \
      "${pkgdir}${JB}/usr/share/licenses/claude-code/Anthropic-LICENSE.md"
  fi
  if [ -f "${srcdir}/README.md" ]; then
    install -m644 "${srcdir}/README.md" \
      "${pkgdir}${JB}/usr/share/doc/claude-code/Upstream-README.md"
  fi
}
