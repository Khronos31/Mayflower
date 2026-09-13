# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/git-delta/make.sh
#
# dandavison/delta 0.19.2 を端末の rustc 1.98 / cargo で建てる。
# バイナリ名は delta。Procursus に同名は無いのでパッケージ名は git-delta。
# crates.io 403 対策で vendor.tar.gz を同梱し --offline で建てる。
# 要: libonig-dev（bat/regex-onig）。libgit2 は libgit2-sys がソース同梱。

pkgname=git-delta
pkgver=0.19.2
pkgrel=1
srcname="delta-${pkgver}"
source="https://github.com/dandavison/delta/archive/refs/tags/${pkgver}.tar.gz"
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
  export CARGO_TARGET_DIR="${BUILDROOT}/delta-target"
  export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}"
  export CARGO_INCREMENTAL=0
  export CARGO_PROFILE_RELEASE_DEBUG=0
  export CC="${CC:-clang}"
  export CXX="${CXX:-clang++}"
  export TMPDIR="${TMPDIR:-${HOME}/tmp}"
  mkdir -p "${CARGO_HOME}" "${TMPDIR}"

  if ! pkg-config --exists oniguruma 2>/dev/null; then
    echo "build: oniguruma が無い（libonig-dev）" >&2
    return 1
  fi

  cargo build --release --offline --locked
}

check() {
  local bin="${BUILDROOT}/delta-target/release/delta"
  ldid -S"${ENTFILE}" "${bin}"
  "${bin}" --version
  printf 'diff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -1 +1 @@\n-old\n+new\n' | "${bin}" || true
}

package() {
  local bin="${BUILDROOT}/delta-target/release/delta"
  ldid -S"${ENTFILE}" "${bin}"
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/git-delta" \
    "${pkgdir}${JB}/usr/share/licenses/git-delta"
  install -m755 "${bin}" "${pkgdir}${JB}/usr/bin/delta"
  cd "${srcdir}" || return 1
  install -m644 README.md "${pkgdir}${JB}/usr/share/doc/git-delta/"
  if [ -f LICENSE ]; then
    install -m644 LICENSE "${pkgdir}${JB}/usr/share/licenses/git-delta/"
  fi
}
