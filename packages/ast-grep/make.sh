# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/ast-grep/make.sh
#
# ast-grep 0.45.3 — AST search/rewrite. Binaries: ast-grep, sg.
# Procursus に無し。端末 rustc + vendor.tar.gz --offline。

pkgname=ast-grep
pkgver=0.45.3
pkgrel=1
srcname="ast-grep-${pkgver}"
source="https://github.com/ast-grep/ast-grep/archive/refs/tags/${pkgver}.tar.gz"
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
  export CARGO_TARGET_DIR="${BUILDROOT}/ag-target"
  export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}"
  export CARGO_INCREMENTAL=0
  export CARGO_PROFILE_RELEASE_DEBUG=0
  export CC="${CC:-clang}"
  export CXX="${CXX:-clang++}"
  export TMPDIR="${TMPDIR:-${HOME}/tmp}"
  mkdir -p "${CARGO_HOME}" "${TMPDIR}"
  cargo build --release --offline --locked -p ast-grep
}

check() {
  # sg 上流は PATH 上の ast-grep を再実行する薄いラッパ（未インストールだと NotFound）。
  # チェックは本体だけ。パッケージでは sg を symlink にする。
  local ag="${BUILDROOT}/ag-target/release/ast-grep"
  ldid -S"${ENTFILE}" "${ag}"
  "${ag}" --version
}

package() {
  local ag="${BUILDROOT}/ag-target/release/ast-grep"
  ldid -S"${ENTFILE}" "${ag}"
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/ast-grep" \
    "${pkgdir}${JB}/usr/share/licenses/ast-grep"
  install -m755 "${ag}" "${pkgdir}${JB}/usr/bin/ast-grep"
  # 上流 sg ラッパはインストール前チェックで落ちるので、同名エイリアスにする
  ln -sf ast-grep "${pkgdir}${JB}/usr/bin/sg"
  cd "${srcdir}" || return 1
  install -m644 README.md "${pkgdir}${JB}/usr/share/doc/ast-grep/"
  if [ -f LICENSE ]; then
    install -m644 LICENSE "${pkgdir}${JB}/usr/share/licenses/ast-grep/"
  fi
}
