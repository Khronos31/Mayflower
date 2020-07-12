pkgname=gmp
pkgver=6.2.0
pkgrel=1

# URL of source archive
source="https://gmplib.org/download/gmp/gmp-${pkgver}.tar.xz"

ARCH="${ARCH-$(arch)}"

build() {
  cd "${pkgname}-${pkgver}"

  curl -sS "https://raw.githubusercontent.com/Homebrew/formula-patches/c53834b4/gmp/6.2.0-arm.patch"|patch -p1
  autoreconf -fiv
  ./configure \
    --build=aarch64-apple-darwin \
    --prefix=/usr/local \
    --enable-static=no \
    --enable-cxx \
    --with-pic
  make

  make check
}

package() {
  cd "${pkgname}-${pkgver}"
  make DESTDIR="${pkgdir}" install
}
