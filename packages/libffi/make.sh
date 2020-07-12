pkgname=libffi
pkgver=3.3
pkgrel=1

# URL of source archive
source="https://sourceware.org/pub/libffi/libffi-${pkgver}.tar.gz"

ARCH="${ARCH-$(arch)}"

build() {
  cd "${pkgname}-${pkgver}"

  ./configure \
    --build=aarch64-apple-darwin \
    --prefix=/usr/local \
    --disable-debug \
    --disable-dependency-tracking \
    --disable-static
  make
}

package() {
  cd "${pkgname}-${pkgver}"
  make DESTDIR="${pkgdir}" install
  install -d "${pkgdir}/usr/share/licenses/${pkgname}"
  install -m644 LICENSE "${pkgdir}/usr/share/licenses/${pkgname}"
}
