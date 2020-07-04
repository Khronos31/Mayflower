pkgname=curl
pkgver=7.71.1
pkgrel=1

# URL of source archive
source="https://curl.haxx.se/download/${pkgname}-${pkgver}.tar.gz"

ARCH="${ARCH-$(arch)}"

build() {
  cd "${pkgname}-${pkgver}"

  ./configure \
    --build=aarch64-apple-darwin \
    --prefix=/usr \
    --disable-debug \
    --disable-dependency-tracking \
    --disable-silent-rules \
    --with-secure-transport \
    --with-ssl=/usr/local \
    --with-libssh2=/usr \
    --with-libidn2=/usr/local \
    --with-nghttp2=/usr \
    --with-ca-bundle=/usr/local/ssl/cert.pem \
    --with-ca-path=/usr/local/ssl/certs

  make
}

package() {
  cd "${pkgname}-${pkgver}"

  make DESTDIR="${pkgdir}" install
  make DESTDIR="${pkgdir}" install -C scripts

  install -Dm755 lib/mk-ca-bundle.pl "${pkgdir}/usr/libexec/mk-ca-bundle.pl"

  install -Dm644 COPYING "${pkgdir}/usr/share/licenses/${pkgname}/COPYING"
}
