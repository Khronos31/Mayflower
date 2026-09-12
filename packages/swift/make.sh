# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/swift/make.sh
#
# Swift は llvm とは別パッケージ（Procursus と同様）。clang-19 に依存。
# ビルドは Mac（tools/mac/llvm-swift）。当面 dist に Swift が無ければ
# プレースホルダ deb のみ。

pkgname=swift
pkgver=6.1.1
pkgrel=1
# LLVM companion version for dist naming / docs
llvmver=19.1.4
srcname=dist
source=""
subpkgs=(swift61)
export compress=xz

swift_series=6.1
llvm_major=19

# Prefer a Swift-only tarball when present; else the llvm+swift combined dist
# (same as packages/llvm) and pick Swift bits out of it.
tree_candidates() {
  echo "swift-${pkgver}-aarch64-apple-ios"
  echo "llvm-${llvmver}-swift-${pkgver}-aarch64-apple-ios"
}

prepare() {
  : "${SWIFT_DIST_DIR:=${LLVM_DIST_DIR:?SWIFT_DIST_DIR か LLVM_DIST_DIR を渡すこと}}"
  mkdir -p "${srcdir}"
  cd "${srcdir}" || return 1
  local t cand
  for cand in $(tree_candidates); do
    if [ -d "${cand}" ]; then
      return 0
    fi
    if [ -r "${SWIFT_DIST_DIR}/${cand}.tar.xz" ]; then
      tar xf "${SWIFT_DIST_DIR}/${cand}.tar.xz"
      return 0
    fi
  done
  echo "prepare: Swift dist tarball が無い（プレースホルダ梱包のみ）" >&2
  mkdir -p "swift-${pkgver}-aarch64-apple-ios"
}

build() {
  :
}

check() {
  cd "${srcdir}" || return 1
  local t bin
  for t in $(tree_candidates); do
    for bin in "${t}/bin/swift" "${t}/bin/swiftc" "${t}/usr/bin/swift"; do
      if [ -x "${bin}" ]; then
        if command -v ldid >/dev/null 2>&1; then
          ldid -S"${ENTFILE}" "${bin}" || true
        fi
        "${bin}" --version || true
        return 0
      fi
    done
  done
  echo "check: swift バイナリ無し（プレースホルダ）"
}

package_swift61() {
  cd "${srcdir}" || return 1
  local pref="${JB}/usr/lib/swift-${swift_series}"
  # If bits live inside llvm-19 tree from combined dist, still expose
  # versioned PATH links into that tree when present; otherwise empty doc pkg.
  local tree="" cand
  for cand in $(tree_candidates); do
    if [ -d "${cand}" ]; then
      tree="${cand}"
      break
    fi
  done

  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/swift-${swift_series}" \
    "${pkgdir}${JB}/usr/share/licenses/swift-${swift_series}"

  if [ -n "${tree}" ] && [ -d "${tree}/bin" ]; then
    install -d "${pkgdir}${pref}"
    # Copy Swift-ish payloads if this is a swift-only tree; if combined llvm
    # tree, only link to clang-19's llvm-19 prefix when binaries exist there.
    if [ -x "${tree}/bin/swiftc" ] || [ -x "${tree}/bin/swift" ]; then
      # dedicated tree
      cp -a "${tree}/." "${pkgdir}${pref}/"
      local b
      for b in swift swiftc; do
        if [ -e "${pkgdir}${pref}/bin/${b}" ]; then
          ln -sf "../lib/swift-${swift_series}/bin/${b}" \
            "${pkgdir}${JB}/usr/bin/${b}-${swift_series}"
          if [ ! -L "${pkgdir}${pref}/bin/${b}" ]; then
            ldid -S"${ENTFILE}" "${pkgdir}${pref}/bin/${b}" || true
          fi
        fi
      done
    fi
  fi

  # Fallback: binaries already provided under llvm-19 from a combined install
  local llvm_pref="${JB}/usr/lib/llvm-${llvm_major}"
  for b in swift swiftc; do
    if [ ! -e "${pkgdir}${JB}/usr/bin/${b}-${swift_series}" ] && \
       [ -e "${llvm_pref}/bin/${b}" ]; then
      ln -sf "../lib/llvm-${llvm_major}/bin/${b}" \
        "${pkgdir}${JB}/usr/bin/${b}-${swift_series}"
    fi
  done

  printf 'Swift %s (Depends: clang-19). Separate from packages/llvm.\n' \
    "${pkgver}" > "${pkgdir}${JB}/usr/share/doc/swift-${swift_series}/README"
}
