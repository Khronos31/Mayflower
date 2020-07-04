pkgname=libssh2
pkgver=1.9.0
pkgrel=1

# URL of source archive
source="https://www.libssh2.org/download/${pkgname}-${pkgver}.tar.gz"

ARCH="${ARCH-$(arch)}"

build() {
  cd "${pkgname}-${pkgver}"

  ./configure \
    --build=aarch64-apple-darwin \
    --prefix=/usr \
    --disable-debug \
    --disable-dependency-tracking \
    --disable-silent-rules \
    --disable-examples-build \
    --with-openssl \
    --with-libz \
    --with-libssl-prefix=/usr/local
  make
}

package() {
  cd "${pkgname}-${pkgver}"
  make DESTDIR="${pkgdir}" install
  install -Dm644 COPYING "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
}
