pkgname=gettext
pkgver=0.20.2
pkgrel=1

# URL of source archive
source="https://ftp.gnu.org/pub/gnu/gettext/${pkgname}-${pkgver}.tar.gz"

ARCH="${ARCH-$(arch)}"

build() {
  cd "${pkgname}-${pkgver}"

  ./configure \
    --build=aarch64-apple-darwin \
    --prefix=/usr/local \
    --disable-dependency-tracking \
    --disable-silent-rules \
    --disable-debug \
    --with-included-gettext \
    --with-included-glib \
    --with-included-libcroco \
    --with-included-libunistring \
    --disable-java \
    --disable-csharp \
    --without-git \
    --without-cvs \
    --with-xz
  make
}

package() {
  cd "${pkgname}-${pkgver}"
  make DESTDIR="${pkgdir}" install
}
