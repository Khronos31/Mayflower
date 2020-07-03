pkgname=libunistring
pkgver=0.9.10
pkgrel=1

# URL of source archive
source="https://ftp.gnu.org/gnu/${pkgname}/${pkgname}-${pkgver}.tar.gz"

ARCH="${ARCH-$(arch)}"

build() {
  cd "${pkgname}-${pkgver}"

  ./configure \
    --build=aarch64-apple-darwin \
    --prefix=/usr \
    --disable-dependency-tracking \
    --disable-silent-rules
  make
}

package() {
  cd "${pkgname}-${pkgver}"
  make DESTDIR="${pkgdir}" install
}
