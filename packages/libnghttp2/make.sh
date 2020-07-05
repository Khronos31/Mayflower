pkgname=libnghttp2
pkgver=1.41.0
pkgrel=2

# URL of source archive
source="https://github.com/nghttp2/nghttp2/releases/download/v${pkgver}/nghttp2-${pkgver}.tar.gz"

ARCH="${ARCH-$(arch)}"

build() {
  cd "nghttp2-${pkgver}"

  ./configure \
    --build=aarch64-apple-darwin \
    --prefix=/usr/local \
    --disable-silent-rules \
    --disable-python-bindings \
    --enable-lib-only
  make
}

package() {
  cd "nghttp2-${pkgver}/lib"

  make DESTDIR="${pkgdir}" install
  install -Dm644 ../COPYING "${pkgdir}/usr/share/licenses/${pkgname}/COPYING"
}
