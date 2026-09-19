# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/mirakc/make.sh
#
# mirakc 3.4.86 — Mirakurun-compatible PVR backend. Binary: mirakc.
# Build -p mirakc only (skip mirakc-timeshift-fs / FUSE).
# Not in Procursus. On-device rustc + vendor.tar.gz --offline.
# Tarball has no .git → set VERGEN_DEFAULT_ON_ERROR for vergen-gitcl.

pkgname=mirakc
pkgver=3.4.86
pkgrel=1
srcname="mirakc-${pkgver}"
source="https://github.com/mirakc/mirakc/archive/refs/tags/${pkgver}.tar.gz"
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
  export CARGO_TARGET_DIR="${BUILDROOT}/mirakc-target"
  export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}"
  export CARGO_INCREMENTAL=0
  export CARGO_PROFILE_RELEASE_DEBUG=0
  export CC="${CC:-clang}"
  export CXX="${CXX:-clang++}"
  export TMPDIR="${TMPDIR:-${HOME}/tmp}"
  # Source tarball has no .git; without this env!("VERGEN_GIT_SHA") fails.
  export VERGEN_DEFAULT_ON_ERROR=1
  # /var/jb/usr/bin/{cargo,rustc} are sh wrappers; cargo cannot posix_spawn
  # those scripts (EPERM). Prefer the real Mach-O under lib/rust-1.98.
  local rustbin="${RUST_LIB_BIN:-/var/jb/usr/lib/rust-1.98/bin}"
  if [ -x "${rustbin}/cargo" ] && [ -x "${rustbin}/rustc" ]; then
    export PATH="${rustbin}:${PATH}"
    export RUSTC="${rustbin}/rustc"
    export CARGO="${rustbin}/cargo"
  fi
  export SDKROOT="${SDKROOT:-/var/jb/usr/share/SDKs/iPhoneOS.sdk}"
  mkdir -p "${CARGO_HOME}" "${TMPDIR}"
  "${CARGO:-cargo}" build --release --offline --locked -p mirakc
}

check() {
  local bin="${BUILDROOT}/mirakc-target/release/mirakc"
  ldid -S"${ENTFILE}" "${bin}"
  "${bin}" --version
  "${bin}" --help >/dev/null
}

package() {
  local bin="${BUILDROOT}/mirakc-target/release/mirakc"
  ldid -S"${ENTFILE}" "${bin}"
  install -d \
    "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/mirakc" \
    "${pkgdir}${JB}/usr/share/licenses/mirakc"
  install -m755 "${bin}" "${pkgdir}${JB}/usr/bin/mirakc"
  cd "${srcdir}" || return 1
  install -m644 README.md "${pkgdir}${JB}/usr/share/doc/mirakc/"
  install -m644 LICENSE-MIT LICENSE-APACHE \
    "${pkgdir}${JB}/usr/share/licenses/mirakc/"
  printf 'mirakc %s — Mirakurun-compatible PVR backend.\nBuilt on-device with Mayflower rustc (-p mirakc only; timeshift-fs/FUSE omitted).\nTuner helpers (recpt1 etc.) are not packaged.\n' \
    "${pkgver}" > "${pkgdir}${JB}/usr/share/doc/mirakc/README.mayflower"
}
