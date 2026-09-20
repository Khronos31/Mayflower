# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/swift/make.sh
#
# Swift is separate from packages/llvm (Procursus-style), but install names
# from the Mac cross build point at /var/jb/usr/lib/llvm-19/{bin,lib}.
# So this package drops files into the llvm-19 prefix and only adds
# versioned PATH links (swift-6.1 / swiftc-6.1).
#
# Split (each .deb xz < 100MB; measured 2026-09-13 on dist):
#   libswift-6.1   ~3MB   runtime dylibs (iphoneos)
#   swift-6.1      ~56MB  frontend + small tools + host plugins + mayflower-swift-ld
#   swift-6.1-dev  ~6MB   modules / headers / shims (no dylibs)
#   swift-default  meta   unversioned swift/swiftc → *-6.1
#
# Fat IDE/test tools (swift-ide-test, swift-refactor, …) are NOT shipped.

pkgname=swift
pkgver=6.1.1
pkgrel=6
llvmver=19.1.4
srcname=dist
source=""
subpkgs=(libswift61 swift61 swift61dev swiftdefault)
export compress="${compress:-xz}"

swift_series=6.1
llvm_major=19

# Binaries included in swift-6.1 (not the ~100MB+ *-test / refactor suite).
SWIFT_BIN_KEEP=(
  swift-frontend
  swift-plugin-server
  swift-demangle
  swift-demangle-yamldump
  swift-compatibility-symbols
  swift-def-to-strings-converter
  swift-serialize-diagnostics
  swift-scan-test
  swift-reflection-dump
  swift-api-checker.py
  swift-api-dump.py
)
SWIFT_BIN_LINKS=(
  swift
  swiftc
  swift-autolink-extract
  swift-cache-tool
  swift-api-digester
  swift-symbolgraph-extract
  swift-synthesize-interface
)

tree_candidates() {
  echo "swift-${pkgver}-aarch64-apple-ios"
  echo "llvm-${llvmver}-swift-${pkgver}-aarch64-apple-ios"
}

llvm_pref() {
  echo "${JB}/usr/lib/llvm-${llvm_major}"
}

find_tree() {
  local cand
  for cand in $(tree_candidates); do
    if [ -d "${cand}" ]; then
      echo "${cand}"
      return 0
    fi
  done
  return 1
}

prepare() {
  : "${SWIFT_DIST_DIR:=${LLVM_DIST_DIR:?SWIFT_DIST_DIR か LLVM_DIST_DIR を渡すこと}}"
  mkdir -p "${srcdir}"
  cd "${srcdir}" || return 1
  local cand
  for cand in $(tree_candidates); do
    if [ -d "${cand}" ]; then
      return 0
    fi
    if [ -r "${SWIFT_DIST_DIR}/${cand}.tar.xz" ]; then
      tar xf "${SWIFT_DIST_DIR}/${cand}.tar.xz"
      return 0
    fi
  done
  echo "prepare: Swift dist tarball が無い" >&2
  return 1
}

build() {
  :
}

check() {
  cd "${srcdir}" || return 1
  local t bin
  for t in $(tree_candidates); do
    for bin in "${t}/bin/swift" "${t}/bin/swiftc" "${t}/bin/swift-frontend"; do
      if [ -e "${bin}" ]; then
        file -b "${bin}" | head -1 || true
        return 0
      fi
    done
  done
  echo "check: swift バイナリ無し" >&2
  return 1
}

sign_machos_under() {
  # $1 = root dir to walk (optional globs as remaining args unused — scan common paths)
  local root="$1"
  [ -d "${root}" ] || return 0
  command -v ldid >/dev/null 2>&1 || return 0
  local f
  while IFS= read -r f; do
    [ -f "${f}" ] && [ ! -L "${f}" ] || continue
    case "$(file -b "${f}" 2>/dev/null)" in
      *Mach-O*) ldid -S"${ENTFILE}" "${f}" || true ;;
    esac
  done < <(find "${root}" -type f \( -name '*.dylib' -o -perm -111 \) 2>/dev/null)
}


strip_appledouble() {
  find "${pkgdir}" -name '._*' -delete 2>/dev/null || true
  find "${pkgdir}" -name '.DS_Store' -delete 2>/dev/null || true
}

install_mayflower_ld_tools() {
  # Into an already-created ${pkgdir}${pref}
  local pref tools files_dir
  pref="$(llvm_pref)"
  tools="${pkgdir}${pref}/libexec/mayflower-swift-tools"
  files_dir="${PROJECTROOT}/files"
  install -d "${tools}" "${pkgdir}${pref}/bin" "${pkgdir}${pref}/libexec"
  mayflower_compile_swift_tool "${tools}/ld" mayflower-swift-ld.c
  mayflower_compile_swift_tool "${tools}/dsymutil" mayflower-swift-dsymutil.c
  install -m755 "${tools}/ld" "${pkgdir}${pref}/bin/mayflower-swift-ld"
  install -m755 "${tools}/dsymutil" "${pkgdir}${pref}/bin/mayflower-swift-dsymutil"
  # clang-19 owns ${pref}/entitlements.plist — only ship under libexec/.
  if [ -f "${files_dir}/entitlements.plist" ]; then
    install -m644 "${files_dir}/entitlements.plist" \
      "${pkgdir}${pref}/libexec/entitlements.plist"
  fi
}

# --- libswift-6.1: device runtime dylibs ---
package_libswift61() {
  cd "${srcdir}" || return 1
  local tree pref
  tree="$(find_tree)" || { echo "package_libswift61: tree missing" >&2; return 1; }
  pref="$(llvm_pref)"

  install -d "${pkgdir}${pref}/lib/swift/iphoneos" \
    "${pkgdir}${pref}/lib" \
    "${pkgdir}${JB}/usr/share/doc/libswift-${swift_series}"

  # Runtime dylibs (+ tiny compatibility .a used at link time with the runtime)
  local f
  for f in "${tree}/lib/swift/iphoneos"/*.dylib; do
    [ -e "${f}" ] || continue
    install -m755 "${f}" "${pkgdir}${pref}/lib/swift/iphoneos/"
  done
  for f in "${tree}/lib/swift/iphoneos"/libswiftCompatibility*.a; do
    [ -e "${f}" ] || continue
    install -m644 "${f}" "${pkgdir}${pref}/lib/swift/iphoneos/"
  done
  if [ -f "${tree}/lib/libswiftDemangle.dylib" ]; then
    install -m755 "${tree}/lib/libswiftDemangle.dylib" "${pkgdir}${pref}/lib/"
  fi

  # Theos derives -resource-dir / -L from dirname(swiftc)/../lib/swift, and
  # dylib install_name is /usr/lib/swift/libswift*.dylib (flat). Point both
  # at the llvm-N tree we actually ship.
  install -d "${pkgdir}${JB}/usr/lib"
  ln -sfn "llvm-${llvm_major}/lib/swift" "${pkgdir}${JB}/usr/lib/swift"
  for f in "${pkgdir}${pref}/lib/swift/iphoneos"/*.dylib; do
    [ -e "${f}" ] || continue
    base="$(basename "${f}")"
    ln -sfn "iphoneos/${base}" "${pkgdir}${pref}/lib/swift/${base}"
  done

  sign_machos_under "${pkgdir}${pref}"

  printf 'libswift-%s: iOS Swift runtime dylibs under llvm-%s.\n' \
    "${swift_series}" "${llvm_major}" \
    > "${pkgdir}${JB}/usr/share/doc/libswift-${swift_series}/README"
  strip_appledouble
}

# --- swift-6.1: compiler + host plugins + mayflower-swift-ld ---
package_swift61() {
  cd "${srcdir}" || return 1
  local tree pref
  tree="$(find_tree)" || { echo "package_swift61: tree missing" >&2; return 1; }
  pref="$(llvm_pref)"

  [ -e "${tree}/bin/swift-frontend" ] || {
    echo "package_swift61: no swift-frontend in ${tree}" >&2
    return 1
  }

  install -d "${pkgdir}${pref}/bin" \
    "${pkgdir}${pref}/lib/swift" \
    "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/swift-${swift_series}" \
    "${pkgdir}${JB}/usr/share/licenses/swift-${swift_series}"

  local b
  for b in "${SWIFT_BIN_KEEP[@]}"; do
    [ -e "${tree}/bin/${b}" ] || continue
    cp -a "${tree}/bin/${b}" "${pkgdir}${pref}/bin/"
  done
  for b in "${SWIFT_BIN_LINKS[@]}"; do
    [ -e "${tree}/bin/${b}" ] || [ -L "${tree}/bin/${b}" ] || continue
    cp -a "${tree}/bin/${b}" "${pkgdir}${pref}/bin/"
  done

  # Host plugins / compiler support dylibs (needed to run swift-frontend)
  if [ -d "${tree}/lib/swift/host" ]; then
    cp -a "${tree}/lib/swift/host" "${pkgdir}${pref}/lib/swift/"
    # Drop bulky build leftovers if present
    find "${pkgdir}${pref}/lib/swift/host" -type f \( \
      -name '*.abi.json' -o -name '*.d' -o -name '*.swiftsourceinfo' \
    \) -delete 2>/dev/null || true
  fi

  # lib_Compiler*.dylib install-name path at lib/
  local hostc="${pkgdir}${pref}/lib/swift/host/compiler"
  if [ -d "${hostc}" ]; then
    local f base
    for f in "${hostc}"/lib_Compiler*.dylib; do
      [ -e "${f}" ] || continue
      base="$(basename "${f}")"
      if [ ! -e "${pkgdir}${pref}/lib/${base}" ]; then
        ln -sfn "swift/host/compiler/${base}" "${pkgdir}${pref}/lib/${base}"
      fi
    done
  fi

  # share/swift bits used by the driver (features.json, diagnostics db)
  if [ -d "${tree}/share/swift" ]; then
    install -d "${pkgdir}${pref}/share"
    cp -a "${tree}/share/swift" "${pkgdir}${pref}/share/"
  fi

  install_mayflower_ld_tools

  # Login shells: mute legacy-driver warning (see files/mayflower-swift.sh).
  install -d "${pkgdir}${JB}/etc/profile.d"
  install -m644 "${PROJECTROOT}/files/mayflower-swift.sh" \
    "${pkgdir}${JB}/etc/profile.d/mayflower-swift.sh"

  # Versioned PATH wrappers. Only swiftc gets -tools-directory (link via
  # mayflower-swift-ld). Plain `swift` rejects that flag (REPL / --version).
  if [ -e "${pkgdir}${pref}/bin/swift" ] || [ -L "${pkgdir}${pref}/bin/swift" ]; then
    mayflower_install_exec "${pkgdir}${JB}/usr/bin/swift-${swift_series}" \
      "${pref}/bin/swift"
  fi
  if [ -e "${pkgdir}${pref}/bin/swiftc" ] || [ -L "${pkgdir}${pref}/bin/swiftc" ]; then
    mayflower_install_exec "${pkgdir}${JB}/usr/bin/swiftc-${swift_series}" \
      "${pref}/bin/swiftc" -- "-tools-directory" "${pref}/libexec/mayflower-swift-tools"
  fi

  sign_machos_under "${pkgdir}${pref}"

  printf 'Swift %s compiler for Mayflower (llvm-%s prefix). PATH: swift-%s / swiftc-%s.\nFat IDE/test tools are not included.\n' \
    "${pkgver}" "${llvm_major}" "${swift_series}" "${swift_series}" \
    > "${pkgdir}${JB}/usr/share/doc/swift-${swift_series}/README"
  strip_appledouble
}

# --- swift-6.1-dev: modules / headers (no runtime dylibs) ---
package_swift61dev() {
  cd "${srcdir}" || return 1
  local tree pref
  tree="$(find_tree)" || { echo "package_swift61dev: tree missing" >&2; return 1; }
  pref="$(llvm_pref)"

  install -d "${pkgdir}${pref}/lib/swift/iphoneos" \
    "${pkgdir}${JB}/usr/share/doc/swift-${swift_series}-dev"

  # iphoneos: everything except .dylib (modules, .a already in libswift — skip .a too to avoid overlap)
  if [ -d "${tree}/lib/swift/iphoneos" ]; then
    local f
    for f in "${tree}/lib/swift/iphoneos"/*; do
      [ -e "${f}" ] || continue
      case "$(basename "${f}")" in
        *.dylib|libswiftCompatibility*.a) continue ;;
      esac
      cp -a "${f}" "${pkgdir}${pref}/lib/swift/iphoneos/"
    done
  fi

  local d
  for d in shims clang apinotes swiftToCxx migrator _InternalSwiftScan _InternalSwiftStaticMirror; do
    [ -d "${tree}/lib/swift/${d}" ] || continue
    cp -a "${tree}/lib/swift/${d}" "${pkgdir}${pref}/lib/swift/"
  done
  if [ -f "${tree}/lib/swift/module.modulemap" ]; then
    install -m644 "${tree}/lib/swift/module.modulemap" "${pkgdir}${pref}/lib/swift/"
  fi

  # Drop abi.json / sourceinfo noise
  find "${pkgdir}${pref}/lib/swift" -type f \( \
    -name '*.abi.json' -o -name '*.swiftsourceinfo' \
  \) -delete 2>/dev/null || true

  if [ -d "${tree}/include" ]; then
    install -d "${pkgdir}${pref}/include"
    # Only swift-related headers if present
    if [ -d "${tree}/include/swift" ]; then
      cp -a "${tree}/include/swift" "${pkgdir}${pref}/include/"
    fi
  fi

  printf 'swift-%s-dev: Swift modules / headers for compiling against the Mayflower stdlib.\n' \
    "${swift_series}" \
    > "${pkgdir}${JB}/usr/share/doc/swift-${swift_series}-dev/README"
  strip_appledouble
}

# --- swift-default: unversioned PATH → 6.1 ---
package_swiftdefault() {
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/swift-default"

  ln -sf "swift-${swift_series}" "${pkgdir}${JB}/usr/bin/swift"
  ln -sf "swiftc-${swift_series}" "${pkgdir}${JB}/usr/bin/swiftc"

  printf 'swift-default → swift-%s / swiftc-%s\n' \
    "${swift_series}" "${swift_series}" \
    > "${pkgdir}${JB}/usr/share/doc/swift-default/README"
  strip_appledouble
}
