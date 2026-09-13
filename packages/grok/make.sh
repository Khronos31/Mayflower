# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/grok/make.sh
#
# xAI Grok Build TUI (xai-grok-pager) 1.0.24 を端末の rustc で建てる。
# 上流: https://github.com/xai-org/grok-build @ 37949780
# jemalloc は切る。sandbox-enforce は残す（iOS では no-op）。
# crates.io は端末から 403 になることがある。vendor は GROK_VENDOR_DIR か
# packages/grok/vendor.tar.xz（git 外、1.7G 級）を置く。

pkgname=grok
pkgver=1.0.24
pkgrel=1
GROK_REV=37949780c144e37df692e3d669051a21fec24f20
srcname="grok-build-${GROK_REV}"
source="https://github.com/xai-org/grok-build/archive/${GROK_REV}.tar.gz"
export compress=xz

prepare() {
  cd "${srcdir}" || return 1
  if [ -f rust-toolchain.toml ]; then
    mv rust-toolchain.toml rust-toolchain.toml.bak
  fi
  # 本体の patch は util/common.sh の applyPatch が当てる。ここでは二重に当てない。

  mkdir -p vendor
  if [ -n "${GROK_VENDOR_DIR:-}" ] && [ -d "${GROK_VENDOR_DIR}" ]; then
    # APFS なら hardlink コピーで 1.7G を実コピーしない
    if ! cp -al "${GROK_VENDOR_DIR}/." vendor/ 2>/dev/null; then
      cp -a "${GROK_VENDOR_DIR}/." vendor/
    fi
  elif [ -r "${PROJECTROOT}/vendor.tar.xz" ]; then
    tar -xJf "${PROJECTROOT}/vendor.tar.xz" -C vendor
  elif [ -r "${PROJECTROOT}/vendor.tar.gz" ]; then
    tar -xzf "${PROJECTROOT}/vendor.tar.gz" -C vendor
  else
    echo "prepare: GROK_VENDOR_DIR か vendor.tar.xz が必要" >&2
    return 1
  fi
  cp -a "${PROJECTROOT}/vendor-overlay/." vendor/
  python3 "${PROJECTROOT}/update-vendor-checksums.py" vendor "${PROJECTROOT}/vendor-overlay"

  mkdir -p .cargo
  cp "${PROJECTROOT}/cargo-config.toml" .cargo/config.toml
}

build() {
  cd "${srcdir}" || return 1
  export CARGO_HOME="${BUILDROOT}/cargo-home"
  export CARGO_TARGET_DIR="${BUILDROOT}/grok-target"
  export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}"
  export CARGO_INCREMENTAL=0
  export CARGO_PROFILE_RELEASE_STRIP=none
  export PROTOC="${PROTOC:-${JB}/usr/bin/protoc}"
  export AR="${AR:-llvm-ar}"
  export RANLIB="${RANLIB:-llvm-ranlib}"
  export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-1}"
  export CC="${CC:-clang}"
  export CXX="${CXX:-clang++}"
  mkdir -p "${CARGO_HOME}"
  cargo build -p xai-grok-pager-bin --release --offline --locked \
    --no-default-features --features sandbox-enforce
}

# cargo の rust-objcopy strip は A11 で SIGKILL したので使わない。
# リンク後に odcctools の strip を掛けてから ldid し直す。
strip_and_sign() {
  local bin="$1"
  strip -S "${bin}"
  ldid -S"${ENTFILE}" "${bin}"
}

check() {
  local bin="${BUILDROOT}/grok-target/release/xai-grok-pager"
  strip_and_sign "${bin}"
  "${bin}" --version
  "${bin}" --help >/dev/null
}

package() {
  local bin="${BUILDROOT}/grok-target/release/xai-grok-pager"
  strip_and_sign "${bin}"
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/grok" \
    "${pkgdir}${JB}/usr/share/licenses/grok"
  install -m755 "${bin}" "${pkgdir}${JB}/usr/bin/grok"
  ln -s grok "${pkgdir}${JB}/usr/bin/agent"
  cd "${srcdir}" || return 1
  install -m644 README.md "${pkgdir}${JB}/usr/share/doc/grok/"
  if [ -f LICENSE ]; then
    install -m644 LICENSE "${pkgdir}${JB}/usr/share/licenses/grok/"
  fi
}
