pkgname=pkg-config
pkgver=0.29.2
pkgrel=1

# URL of source archive
source="https://pkg-config.freedesktop.org/releases/${pkgname}-${pkgver}.tar.gz"

ARCH="${ARCH-$(arch)}"

build() {
  cd "${pkgname}-${pkgver}"

  local pc_path="/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"
  ./configure \
    --build=aarch64-apple-darwin \
    --prefix=/usr/local \
    --disable-debug \
    --disable-host-tool \
    --with-internal-glib \
    --with-pc-path="${pc_path}"

  make
}

package() {
  cd "${pkgname}-${pkgver}"
  make DESTDIR="${pkgdir}" install
}
