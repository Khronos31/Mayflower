pkgname=openssl
pkgver=1.1.1g
pkgrel=2

# URL of source archive
source="https://www.openssl.org/source/openssl-1.1.1g.tar.gz"

ARCH="${ARCH-$(arch)}"

build() {
  cd "${pkgname}-${pkgver}"

  export CROSS_TOP=/usr/share
  export CROSS_SDK
  local arch_args
  case "${ARCH}" in
    armv7) arch_args=("ios-cross"); CROSS_SDK=iPhoneOS8.4.sdk;;
    arm64) arch_args=("ios64-cross" "enable-ec_nistp_64_gcc_128"); CROSS_SDK=iPhoneOS10.3.sdk;;
  esac

  perl ./Configure \
    --prefix=/usr/local \
    --openssldir=/usr/local/ssl \
    --libdir=lib \
    shared \
    no-ssl3 \
    no-ssl3-method \
    "${arch_args[@]}"
  make
}

package() {
  cd "${pkgname}-${pkgver}"

  make DESTDIR="${pkgdir}" MANDIR=/usr/local/share/man MANSUFFIX=ssl install_sw install_ssldirs install_man_docs

  install -D -m644 LICENSE "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"

  cd "${pkgdir}/usr/local/ssl"
  rm -rf certs cert.pem
  ln -s /etc/certs certs
  ln -s certs/cacert.pem cert.pem
}
