# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/mirakc-arib/make.sh
#
# mirakc-arib 0.9.1 — ARIB TS の scan-services / collect-eits / filter-*。
# tsduck-arib と aribb24 を静的リンクした Mach-O。PATH ラッパは不要。
#
# **端末では建てない。** Darwin ホストを macOS とみなす tsduck と、
# ExternalProject の bootstrap があるので Mac からクロスする。
# 建て方は tools/mac/mirakc-arib/build.sh。パッチは patches-host/
# （母艦で当てるので applyPatch の対象にしない）。

pkgname=mirakc-arib
pkgver=0.9.1
pkgrel=3
srcname=dist
source=""
export compress=xz

prepare() {
  : "${MIRAKC_ARIB_DIST_DIR:?Mac で建てた dist tarball のあるディレクトリを渡すこと（tools/mac/mirakc-arib/build.sh）}"
  mkdir -p "${srcdir}"
  cd "${srcdir}" || return 1
  local t="mirakc-arib-${pkgver}-aarch64-apple-ios"
  if [ ! -d "${t}" ]; then
    [ -r "${MIRAKC_ARIB_DIST_DIR}/${t}.tar.xz" ] || {
      echo "prepare: ${MIRAKC_ARIB_DIST_DIR}/${t}.tar.xz が無い" >&2
      return 1
    }
    tar xf "${MIRAKC_ARIB_DIST_DIR}/${t}.tar.xz"
  fi
}

build() {
  : # 母艦で建ててある
}

check() {
  cd "${srcdir}" || return 1
  local bin="mirakc-arib-${pkgver}-aarch64-apple-ios/bin/mirakc-arib"
  [ -f "${bin}" ] || { echo "check: ${bin} が無い" >&2; return 1; }
  ldid -S"${ENTFILE}" "${bin}"
  "${bin}" --version
  "${bin}" --help >/dev/null
}

package() {
  cd "${srcdir}" || return 1
  local tree="mirakc-arib-${pkgver}-aarch64-apple-ios"
  local bin="${tree}/bin/mirakc-arib"

  ldid -S"${ENTFILE}" "${bin}"
  install -d \
    "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/mirakc-arib" \
    "${pkgdir}${JB}/usr/share/licenses/mirakc-arib"
  install -m755 "${bin}" "${pkgdir}${JB}/usr/bin/mirakc-arib"
  if [ -f "${tree}/README.md" ]; then
    install -m644 "${tree}/README.md" \
      "${pkgdir}${JB}/usr/share/doc/mirakc-arib/"
  fi
  for lic in LICENSE-MIT LICENSE-APACHE; do
    if [ -f "${tree}/${lic}" ]; then
      install -m644 "${tree}/${lic}" \
        "${pkgdir}${JB}/usr/share/licenses/mirakc-arib/${lic}"
    fi
  done
  printf 'mirakc-arib %s — ARIB MPEG-TS utilities (scan-services, collect-eits, filter-service, filter-program).\nCross-built on Mac. tsduck-arib and aribb24 are statically linked.\n' \
    "${pkgver}" > "${pkgdir}${JB}/usr/share/doc/mirakc-arib/README.mayflower"
}
