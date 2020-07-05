pkgname=libidn2
pkgver=2.3.0
pkgrel=2

# URL of source archive
source="https://ftp.gnu.org/gnu/libidn/${pkgname}-${pkgver}.tar.gz"

ARCH="${ARCH-$(arch)}"

build() {
  cd "${pkgname}-${pkgver}"

  CC_FOR_BUILD="${CC}" \
  ./configure \
    --build=aarch64-apple-darwin \
    --prefix=/usr/local \
    --disable-dependency-tracking \
    --disable-silent-rules \
    --disable-static \
    --with-libunistring-prefix=/usr/local \
    --with-libintl-prefix=/usr/local 
  make
}

package() {
  cd "${pkgname}-${pkgver}"
  make DESTDIR="${pkgdir}" install
}
