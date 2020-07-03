pkgname=ncurses
pkgver=6.2
pkgrel=2

source="https://ftp.gnu.org/gnu/ncurses/${pkgname}-${pkgver}.tar.gz"

ARCH="${ARCH-$(arch)}"

build() {
  cd "${pkgname}-${pkgver}"

  LDFLAGS= \
  ./configure \
    --build=aarch64-apple-darwin \
    --prefix=/usr/local \
    --libdir='${exec_prefix}/lib/ncurses' \
    --enable-pc-files \
    --with-pkg-config-libdir=/usr/local/lib/pkgconfig \
    --enable-sigwinch \
    --enable-symlinks \
    --enable-widec \
    --enable-overwrite \
    --with-shared \
    --with-normal \
    --without-debug \
    --without-ada \
    --without-cxx \
    --without-cxx-binding \
    --with-cxx-shared=no \
    --with-gpm=no \
    --with-manpage-format=normal
  make
}

package() {
  cd "${pkgname}-${pkgver}"
  make DESTDIR="${pkgdir}" install
  install -Dm644 COPYING "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"

  major="${pkgver/%.*}"

  for lib in ncurses form panel menu; do
    ln -s "lib${lib}w.${major}.dylib" "${pkgdir}/usr/local/lib/ncurses/lib${lib}.dylib"
    ln -s "lib${lib}w.${major}.dylib" "${pkgdir}/usr/local/lib/ncurses/lib${lib}.${major}.dylib"
    ln -s ${lib}w.pc "${pkgdir}/usr/local/lib/pkgconfig/${lib}.pc"
  done

  for lib in tic tinfo; do
    ln -s "libncursesw.${major}.dylib" "${pkgdir}/usr/local/lib/ncurses/lib${lib}.dylib"
    ln -s "libncursesw.${major}.dylib" "${pkgdir}/usr/local/lib/ncurses/lib${lib}.${major}.dylib"
    ln -s ncursesw.pc "${pkgdir}/usr/local/lib/pkgconfig/${lib}.pc"
  done

  ln -s libncursesw.dylib "${pkgdir}/usr/local/lib/ncurses/libcursesw.dylib"
  ln -s libncurses.dylib "${pkgdir}/usr/local/lib/ncurses/libcurses.dylib"

  ln -s "ncursesw${major}-config" "${pkgdir}/usr/local/bin/ncurses${major}-config"
}
