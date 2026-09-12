# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/ripgrep/make.sh
#
# ripgrep 15.2.0 を端末の rustc 1.98 / cargo で建てる。
# Procursus の ripgrep は 12.1.1（Package: ripgrep、/usr/bin/rg）。同名は
# Pin-Priority 1001 で負けるので、本体は ripgrep-15、版なし rg は
# ripgrep-default が Provides/Conflicts/Replaces: ripgrep する。
#
# crates.io は端末から 403 になることがある。vendor.tar.gz を同梱し
# --offline で建てる。PCRE2 は使わない（libpcre2-dev が無い）。

pkgname=ripgrep
pkgver=15.2.0
pkgrel=1
srcname="ripgrep-${pkgver}"
source="https://github.com/BurntSushi/ripgrep/archive/refs/tags/${pkgver}.tar.gz"
subpkgs=(ripgrep default)
export compress=xz

prepare() {
  cd "${srcdir}" || return 1
  local v="${PROJECTROOT}/vendor.tar.gz"
  [ -r "${v}" ] || {
    echo "prepare: ${v} が無い。HAOS で cargo vendor して置くこと" >&2
    return 1
  }
  tar -xzf "${v}"
  # cargo vendor の出力ディレクトリ名は rg-vendor ではなく vendor にする
  if [ -d rg-vendor ] && [ ! -d vendor ]; then
    mv rg-vendor vendor
  fi
  mkdir -p .cargo
  cat >> .cargo/config.toml <<'EOF'

[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
EOF
}

build() {
  cd "${srcdir}" || return 1
  export CARGO_HOME="${BUILDROOT}/cargo-home"
  export CARGO_TARGET_DIR="${BUILDROOT}/rg-target"
  export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}"
  export CARGO_INCREMENTAL=0
  export CARGO_PROFILE_RELEASE_DEBUG=0
  export CC="${CC:-clang}"
  export CXX="${CXX:-clang++}"
  mkdir -p "${CARGO_HOME}"
  cargo build --release --offline --locked
}

check() {
  local bin="${BUILDROOT}/rg-target/release/rg"
  ldid -S"${ENTFILE}" "${bin}"
  "${bin}" --version
  printf 'hello ripgrep\n' | "${bin}" -n ripgrep -
}

package_ripgrep() {
  local bin="${BUILDROOT}/rg-target/release/rg"
  ldid -S"${ENTFILE}" "${bin}"
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/ripgrep-15" \
    "${pkgdir}${JB}/usr/share/licenses/ripgrep-15"
  install -m755 "${bin}" "${pkgdir}${JB}/usr/bin/rg-15"
  cd "${srcdir}" || return 1
  install -m644 README.md CHANGELOG.md \
    "${pkgdir}${JB}/usr/share/doc/ripgrep-15/"
  install -m644 COPYING LICENSE-MIT UNLICENSE \
    "${pkgdir}${JB}/usr/share/licenses/ripgrep-15/"
}

package_default() {
  install -d "${pkgdir}${JB}/usr/bin"
  ln -s rg-15 "${pkgdir}${JB}/usr/bin/rg"
}
