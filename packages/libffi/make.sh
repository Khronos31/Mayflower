pkgname=libffi
pkgver=3.3
pkgrel=2

# URL of source archive
source="https://sourceware.org/pub/libffi/libffi-${pkgver}.tar.gz"

ARCH="${ARCH-$(arch)}"

build() {
  cd "${pkgname}-${pkgver}"

  local build_arch host_arch
  case "$(arch)" in
    arm64*) build_arch=aarch64;;
    arm) build_arch=arm;;
  esac
  case "${ARCH}" in
    arm64) host_arch=aarch64;;
    armv7) host_arch=arm;;
  esac

  ./configure \
    --build=${build_arch}-apple-darwin \
    --host=${host_arch}-apple-darwin \
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
