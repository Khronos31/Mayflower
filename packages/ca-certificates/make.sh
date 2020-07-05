pkgname=ca-certificates
_ver=2020-06-24
pkgver="${_ver//-}"
pkgrel=1

# URL of source archive
source=""

ARCH="${ARCH-$(arch)}"

build() {
  curl "https://curl.haxx.se/ca/cacert-${_ver}.pem" -o cacert.pem
  cat <<'E' >cacerts.bootstrap.sh
## git ##
git config --global http.sslCAInfo /etc/ssl/certs/cacert.pem &> /dev/null
E
  chmod +x cacerts.bootstrap.sh
}

package() {
  install -D -m644 cacert.pem "${pkgdir}/etc/ssl/certs/cacert.pem"
  install -D -m755 cacerts.bootstrap.sh "${pkgdir}/etc/profile.d/cacerts.bootstrap.sh"
  local openssldir="${pkgdir}/usr/lib/ssl"
  mkdir -p "${openssldir}"
  cd "${openssldir}"
  ln -s ../../../etc/ssl/certs certs
  ln -s certs/cacert.pem cert.pem
}
