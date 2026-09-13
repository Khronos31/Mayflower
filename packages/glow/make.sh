# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/glow/make.sh
#
# Charmbracelet glow — terminal Markdown reader.
# Build on-device with Mayflower Go (golang-default / 1.26+).
# ios/arm64 needs cgo + libiosexec-dev (provides libiosexec.dylib).
# Procursus に同名は無い。

pkgname=glow
pkgver=3.0.0
pkgrel=1
srcname="glow-${pkgver}"
source="https://github.com/charmbracelet/glow/archive/refs/tags/v${pkgver}.tar.gz"
export compress="${compress:-xz}"

prepare() {
  cd "${srcdir}" || return 1
}

build() {
  cd "${srcdir}" || return 1
  export GOTOOLCHAIN=local
  export CGO_ENABLED=1
  export CC="${CC:-clang}"
  export GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}"
  export GOSUMDB="${GOSUMDB:-sum.golang.org}"
  # Prefer $HOME for go link temps (jb /tmp can SIGKILL)
  export TMPDIR="${TMPDIR:-${HOME}/tmp}"
  mkdir -p "${TMPDIR}"

  command -v go >/dev/null || {
    echo "build: go が無い（golang-default を入れること）" >&2
    return 1
  }
  if [ ! -e "${JB}/usr/lib/libiosexec.dylib" ]; then
    echo "build: ${JB}/usr/lib/libiosexec.dylib が無い（libiosexec-dev）" >&2
    return 1
  fi

  go version
  local ver="${pkgver}"
  go build -trimpath -ldflags="-s -w -X main.Version=${ver}" -o glow .
}

check() {
  cd "${srcdir}" || return 1
  [ -x ./glow ] || return 1
  # Unsigned until package(); may still run under some jb setups — best-effort
  ./glow --version || true
}

package() {
  cd "${srcdir}" || return 1
  install -d \
    "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/glow" \
    "${pkgdir}${JB}/usr/share/licenses/glow"
  install -m755 glow "${pkgdir}${JB}/usr/bin/glow"
  if command -v ldid >/dev/null 2>&1; then
    ldid -S"${ENTFILE}" "${pkgdir}${JB}/usr/bin/glow" || true
  fi
  if [ -f LICENSE ]; then
    install -m644 LICENSE "${pkgdir}${JB}/usr/share/licenses/glow/LICENSE"
  fi
  printf 'Charmbracelet glow %s — render Markdown in the terminal.\nBuilt with Mayflower Go on ios/arm64 (cgo + libiosexec).\n' \
    "${pkgver}" > "${pkgdir}${JB}/usr/share/doc/glow/README"
}
