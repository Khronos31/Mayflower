pkgname=nim
pkgver=1.4.8
pkgrel=1

# URL of source archive
source="https://nim-lang.org/download/${pkgname}-${pkgver}.tar.xz"

ARCH="${ARCH-$(arch)}"

prepare() {
  cd "${pkgname}-${pkgver}"
  cp $(which nim) ./bin/nim
}

build() {
  cd "${pkgname}-${pkgver}"

  local cpu
  if [ "${ARCH}" = armv7 ]; then
    cpu=arm
  else
    cpu="${ARCH}"
  fi

  cp $(which nim) ./bin/nim

  ./bin/nim compile --os:ios --cpu:"${cpu}" -d:release --opt:size koch
  ./koch boot --os:ios --cpu:"${cpu}" -d:release --opt:size -d:useLinenoise
  ./bin/nim compile --os:ios --cpu:"${cpu}" -d:release --opt:size koch
  ./koch tools --os:ios --cpu:"${cpu}" -d:release --opt:size
}

package() {
  cd "${pkgname}-${pkgver}" 

  local bindir="${pkgdir}/usr/bin"
  install -d "${bindir}"
  install -m755 bin/* "${bindir}"

  local configdir="${pkgdir}/etc/nim"
  install -d "${configdir}"
  install -m644 config/* "${configdir}"

  local libdir="${pkgdir}/usr/lib/nim"
  install -d "${libdir}"
  cp -R lib/. "${libdir}"

  local docdir="${pkgdir}/usr/share/nim/doc"
  install -d "${docdir}"
  cp -R doc/. "${docdir}"
  rm -rf "${docdir}/html"
  cp -R examples "${docdir}"

  install -d "${pkgdir}/usr/share/bash-completion/completions"
  install -m644 tools/nim.bash-completion "${pkgdir}/usr/share/bash-completion/completions/nim"
  install -m644 dist/nimble/nimble.bash-completion "${pkgdir}/usr/share/bash-completion/completions/nimble"

  install -d "${pkgdir}/usr/share/zsh/vendor-completions"
  install -m644 tools/nim.zsh-completion "${pkgdir}/usr/share/zsh/vendor-completions/_nim"
  install -m644 dist/nimble/nimble.zsh-completion "${pkgdir}/usr/share/zsh/vendor-completions/_nimble"

  install -d "${pkgdir}/usr/share/licenses/${pkgname}"
  install -m644 copying.txt "${pkgdir}/usr/share/licenses/${pkgname}"
  install -d "${pkgdir}/usr/share/licenses/nimble"
  install -m644 dist/nimble/license.txt "${pkgdir}/usr/share/licenses/nimble"
}
