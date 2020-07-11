pkgname=go
pkgver=1.14.4
pkgrel=2

# URL of source archive
source="https://dl.google.com/go/go${pkgver}.src.tar.gz"

ARCH="${ARCH-$(arch)}"
CC=clang
CXX=clang++
COMMON_FLAGS=""
export compress=xz

build() {
  cd "${pkgname}"

  export GOOS=darwin
  export GOARCH
  export GOROOT
  export CGO_ENABLED=1

GOROOT="${BUILDROOT}/go"
  cd "${GOROOT}/src"

  if [ "${ARCH}" = armv7 ]; then
    GOARCH=arm
  else
    GOARCH="${ARCH}"
  fi

  bash make.bash -v  ||
  go install -v -i cmd/asm cmd/cgo cmd/compile cmd/link
  rm -rf "${GOROOT}/pkg/tool"
  bash make.bash -v --no-clean
}

package() {
  cd "${pkgname}"

  local bindir="${pkgdir}/usr/bin"
  install -d "${bindir}"
  ln -s /usr/lib/go/bin/go "${bindir}/go"
  ln -s /usr/lib/go/bin/gofmt "${bindir}/gofmt"

  local libdir="${pkgdir}/usr/lib/go"
  install -d "${libdir}"
  cp -R VERSION api bin lib misc pkg  src test "${libdir}"

  local docdir="${pkgdir}/usr/share/doc/go"
  ln -s /usr/share/doc/go "${libdir}/doc"
  install -d "${docdir}"
  cp -R doc/. "${docdir}"

  install -d "${pkgdir}/usr/share/licenses/${pkgname}"
  install -m644 LICENSE "${pkgdir}/usr/share/licenses/${pkgname}"
}