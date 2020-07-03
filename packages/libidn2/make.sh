pkgname=libidn2
pkgver=2.3.0
pkgrel=1

# URL of source archive
source="https://ftp.gnu.org/gnu/libidn/${pkgname}-${pkgver}.tar.gz"

ARCH="${ARCH-$(arch)}"

build() {
  cd "${pkgname}-${pkgver}"

  ./configure \
    --build=aarch64-apple-darwin \
    --prefix=/usr/local \
    --disable-dependency-tracking \
    --disable-silent-rules \
    --disable-static \
    --with-libunistring-prefix=/usr/local \
    --with-libintl-prefix=/usr/local \
    --with-packager=Khronos
  make
}

package() {
  cd "${pkgname}-${pkgver}"
  make DESTDIR="${pkgdir}" install
}
