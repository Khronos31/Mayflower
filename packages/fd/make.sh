# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/fd/make.sh
#
# fd 10.5.0 を端末の rustc 1.98 / cargo で建てる。
# Procursus の fd は 8.6.0（Package: fd）。同名は Pin-Priority 1001 で
# 負けるので、本体は fd-10、版なし fd は fd-default が
# Provides/Conflicts/Replaces: fd する。
#
# crates.io は端末から 403 になることがある。vendor.tar.gz を同梱し
# --offline で建てる。

pkgname=fd
pkgver=10.5.0
pkgrel=1
srcname="fd-${pkgver}"
source="https://github.com/sharkdp/fd/archive/refs/tags/v${pkgver}.tar.gz"
subpkgs=(fd default)
export compress="${compress:-xz}"

prepare() {
  cd "${srcdir}" || return 1
  local v="${PROJECTROOT}/vendor.tar.gz"
  [ -r "${v}" ] || {
    echo "prepare: ${v} が無い。Mac で cargo vendor して置くこと" >&2
    return 1
  }
  tar -xzf "${v}"
  mkdir -p .cargo
  cat >> .cargo/config.toml <<'EOFCFG'

[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
EOFCFG
}

build() {
  cd "${srcdir}" || return 1
  export CARGO_HOME="${BUILDROOT}/cargo-home"
  export CARGO_TARGET_DIR="${BUILDROOT}/fd-target"
  export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}"
  export CARGO_INCREMENTAL=0
  export CARGO_PROFILE_RELEASE_DEBUG=0
  export CC="${CC:-clang}"
  export CXX="${CXX:-clang++}"
  # Prefer $HOME for temps on jb
  export TMPDIR="${TMPDIR:-${HOME}/tmp}"
  mkdir -p "${CARGO_HOME}" "${TMPDIR}"
  # default features = completions only (no jemalloc)
  cargo build --release --offline --locked
}

check() {
  local bin="${BUILDROOT}/fd-target/release/fd"
  ldid -S"${ENTFILE}" "${bin}"
  "${bin}" --version
  mkdir -p "${BUILDROOT}/fd-smoke"
  touch "${BUILDROOT}/fd-smoke/hello.txt"
  "${bin}" -t f hello "${BUILDROOT}/fd-smoke"
}

package_fd() {
  local bin="${BUILDROOT}/fd-target/release/fd"
  ldid -S"${ENTFILE}" "${bin}"
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/fd-10" \
    "${pkgdir}${JB}/usr/share/licenses/fd-10"
  install -m755 "${bin}" "${pkgdir}${JB}/usr/bin/fd-10"
  cd "${srcdir}" || return 1
  install -m644 README.md CHANGELOG.md \
    "${pkgdir}${JB}/usr/share/doc/fd-10/" 2>/dev/null || \
    install -m644 README.md "${pkgdir}${JB}/usr/share/doc/fd-10/"
  if [ -f LICENSE-MIT ]; then
    install -m644 LICENSE-MIT "${pkgdir}${JB}/usr/share/licenses/fd-10/"
  fi
  if [ -f LICENSE-APACHE ]; then
    install -m644 LICENSE-APACHE "${pkgdir}${JB}/usr/share/licenses/fd-10/"
  fi
}

package_default() {
  install -d "${pkgdir}${JB}/usr/bin"
  ln -s fd-10 "${pkgdir}${JB}/usr/bin/fd"
}
