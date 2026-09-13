# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/sd/make.sh
#
# chmln/sd 1.1.0 — intuitive find & replace. Binary: sd.
# 上流タグ v1.1.0（workspace Cargo.toml の version 欄は 1.0.0 のまま）。
# Procursus に無し。端末 rustc + vendor.tar.gz --offline。

pkgname=sd
pkgver=1.1.0
pkgrel=1
srcname="sd-${pkgver}"
source="https://github.com/chmln/sd/archive/refs/tags/v${pkgver}.tar.gz"
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
  export CARGO_TARGET_DIR="${BUILDROOT}/sd-target"
  export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}"
  export CARGO_INCREMENTAL=0
  export CARGO_PROFILE_RELEASE_DEBUG=0
  export CC="${CC:-clang}"
  export CXX="${CXX:-clang++}"
  export TMPDIR="${TMPDIR:-${HOME}/tmp}"
  mkdir -p "${CARGO_HOME}" "${TMPDIR}"
  cargo build --release --offline --locked -p sd-cli
}

check() {
  local bin="${BUILDROOT}/sd-target/release/sd"
  local out
  ldid -S"${ENTFILE}" "${bin}"
  "${bin}" --version
  out="$(printf 'hello world\n' | "${bin}" world moon)"
  [ "${out}" = "hello moon" ]
}

package() {
  local bin="${BUILDROOT}/sd-target/release/sd"
  ldid -S"${ENTFILE}" "${bin}"
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/sd" \
    "${pkgdir}${JB}/usr/share/licenses/sd"
  install -m755 "${bin}" "${pkgdir}${JB}/usr/bin/sd"
  cd "${srcdir}" || return 1
  install -m644 README.md "${pkgdir}${JB}/usr/share/doc/sd/"
  if [ -f LICENSE ]; then
    install -m644 LICENSE "${pkgdir}${JB}/usr/share/licenses/sd/"
  fi
}
