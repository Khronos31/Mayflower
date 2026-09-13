# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/ruff/make.sh
#
# astral-sh/ruff — 超高速 Python linter / formatter。
# Procursus に無し。端末 rustc 1.98 + vendor.tar.gz --offline。
# ソースは crates.io の ruff crate（モノレポ全体ではない）。
# jemalloc は iOS 向けにパッチで無効化。

pkgname=ruff
pkgver=0.16.7
pkgrel=1
srcname="ruff-${pkgver}"
source="https://static.crates.io/crates/ruff/ruff-${pkgver}.crate"
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
  export CARGO_TARGET_DIR="${BUILDROOT}/ruff-target"
  export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}"
  export CARGO_INCREMENTAL=0
  export CARGO_PROFILE_RELEASE_DEBUG=0
  export CC="${CC:-clang}"
  export CXX="${CXX:-clang++}"
  export TMPDIR="${TMPDIR:-${HOME}/tmp}"
  mkdir -p "${CARGO_HOME}" "${TMPDIR}"
  cargo build --release --offline --locked
}

check() {
  local bin="${BUILDROOT}/ruff-target/release/ruff"
  ldid -S"${ENTFILE}" "${bin}"
  "${bin}" --version
  local smoke="${BUILDROOT}/ruff-smoke.py"
  printf 'import os,sys\nprint( 1+2 )\n' > "${smoke}"
  "${bin}" check "${smoke}" || true
  "${bin}" format "${smoke}"
  grep -q 'print(1 + 2)' "${smoke}"
}

package() {
  local bin="${BUILDROOT}/ruff-target/release/ruff"
  ldid -S"${ENTFILE}" "${bin}"
  install -d \
    "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/ruff" \
    "${pkgdir}${JB}/usr/share/licenses/ruff"
  install -m755 "${bin}" "${pkgdir}${JB}/usr/bin/ruff"
  if [ -f "${srcdir}/README.md" ]; then
    install -m644 "${srcdir}/README.md" "${pkgdir}${JB}/usr/share/doc/ruff/"
  fi
  install -m644 "${PROJECTROOT}/files/LICENSE" \
    "${pkgdir}${JB}/usr/share/licenses/ruff/LICENSE"
  printf 'astral ruff %s — Python linter and formatter.\nBuilt on-device with Mayflower rustc (crates.io source + vendor, jemalloc off on iOS).\n' \
    "${pkgver}" > "${pkgdir}${JB}/usr/share/doc/ruff/README.mayflower"
}
