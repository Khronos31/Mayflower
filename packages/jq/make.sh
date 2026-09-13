# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/jq/make.sh
#
# jq 1.8.2 を rootless 脱獄 iOS 上でセルフビルドする。
# Procursus の jq は 1.6（Package: jq）。同名は Pin-Priority 1001 で負けるので
# CLI は jq-1.8、PATH の jq は jq-default が Provides/Conflicts/Replaces: jq。
# 共有ライブラリは Debian と同じ libjq1 / libjq-dev。

pkgname=jq
pkgver=1.8.2
pkgrel=1
srcname="jq-${pkgver}"
source="https://github.com/jqlang/jq/releases/download/jq-${pkgver}/jq-${pkgver}.tar.gz"
subpkgs=(libjq jq dev default)
export compress=xz

prepare() {
  cd "${srcdir}" || return 1
}

build() {
  cd "${srcdir}" || return 1
  ./configure \
    --prefix="${JB}/usr" \
    --disable-docs \
    --disable-nls \
    --enable-shared \
    --disable-static \
    --with-oniguruma="${JB}/usr" \
    CC="${CC}" \
    CFLAGS="${CFLAGS}" \
    LDFLAGS="${LDFLAGS}"
  make -j"${MAKE_JOBS:-1}"
}

check() {
  cd "${srcdir}" || return 1
  local bin="${srcdir}/.libs/jq"
  ldid -S"${ENTFILE}" "${bin}"
  ldid -S"${ENTFILE}" "${srcdir}/.libs/libjq.1.dylib"
  DYLD_LIBRARY_PATH="${srcdir}/.libs" "${bin}" --version
  printf '%s\n' '{"a":1}' | DYLD_LIBRARY_PATH="${srcdir}/.libs" "${bin}" -e .a | grep -qx 1
}

package_libjq() {
  install -d "${pkgdir}${JB}/usr/lib"
  install -m755 "${srcdir}/.libs/libjq.1.dylib" "${pkgdir}${JB}/usr/lib/"
}

package_jq() {
  install -d "${pkgdir}${JB}/usr/bin" "${pkgdir}${JB}/usr/share/man/man1"
  install -m755 "${srcdir}/.libs/jq" "${pkgdir}${JB}/usr/bin/jq-1.8"
  if [ -f "${srcdir}/jq.1" ]; then
    install -m644 "${srcdir}/jq.1" "${pkgdir}${JB}/usr/share/man/man1/jq-1.8.1"
  fi
}

package_dev() {
  install -d "${pkgdir}${JB}/usr/include" "${pkgdir}${JB}/usr/lib/pkgconfig"
  install -m644 "${srcdir}/src/jv.h" "${pkgdir}${JB}/usr/include/"
  # jq.h は src/ か include
  if [ -f "${srcdir}/src/jq.h" ]; then
    install -m644 "${srcdir}/src/jq.h" "${pkgdir}${JB}/usr/include/"
  elif [ -f "${srcdir}/jq.h" ]; then
    install -m644 "${srcdir}/jq.h" "${pkgdir}${JB}/usr/include/"
  fi
  ln -s libjq.1.dylib "${pkgdir}${JB}/usr/lib/libjq.dylib"
  if [ -f "${srcdir}/libjq.pc" ]; then
    install -m644 "${srcdir}/libjq.pc" "${pkgdir}${JB}/usr/lib/pkgconfig/libjq.pc"
  fi
}

package_default() {
  install -d "${pkgdir}${JB}/usr/bin"
  ln -s jq-1.8 "${pkgdir}${JB}/usr/bin/jq"
}
