# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/px4-userland/make.sh
#
# px4-userland v0.1.3 → Package: px4-userland / Name: PX4 Driver
# バイナリ: px4d / px4-ts / px4ctl
#
# USB のため packages/px4-userland/entitlements.plist（IOKit USB）を使う。
# ルートの薄い entitlements.plist では libusb がデバイスを開けない（siano と同じ）。
#
# ファームウェアは同梱しない。PC/SC IFD は iOS 初回は建てない。

pkgname=px4-userland
pkgver=0.1.3
pkgrel=1
srcname="px4-userland-${pkgver}"
source="https://github.com/Khronos31/px4-userland/archive/refs/tags/v${pkgver}.tar.gz"

_set_ent() {
  export ENTFILE="${PROJECTROOT}/entitlements.plist"
  [ -f "${ENTFILE}" ] || { echo "$0: missing ${ENTFILE}" >&2; return 1; }
}

prepare() {
  cd "${srcdir}" || return 1
  _set_ent
}

build() {
  cd "${srcdir}" || return 1
  _set_ent

  # iOS 16 の libc++ に __libcpp_verbose_abort が無い。Clang 19 のヘッダは
  # -fno-exceptions 時にこのシンボルを呼ぶ。オブジェクトを直接渡す
  # （-l の .a だと未定義が出る前に捨てられる）。
  local abort_o
  abort_o="${BUILDROOT}/libcpp_verbose_abort.o"
  "${CXX}" ${CXXFLAGS} -std=c++17 -fno-exceptions -fno-rtti \
    -c "${PROJECTROOT}/files/libcpp_verbose_abort.cpp" -o "${abort_o}"

  export PKG_CONFIG_PATH="${JB}/usr/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"

  cmake -S . -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_COMPILER="${CXX}" \
    -DPX4_BUILD_TESTS=OFF \
    -DPX4_BUILD_TOOLS=OFF \
    -DPX4_BUILD_PCSC_IFD=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS} ${abort_o} -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,Security -Wl,-stack_size,0x800000"

  cmake --build build --target px4d px4-ts px4ctl
}

check() {
  cd "${srcdir}/build" || return 1
  _set_ent
  ./px4d --help >/dev/null
  ./px4-ts --help >/dev/null
  ./px4ctl --help >/dev/null
}

package() {
  cd "${srcdir}" || return 1
  _set_ent

  install -d "${pkgdir}${JB}/usr/bin"
  install -m755 build/px4d "${pkgdir}${JB}/usr/bin/px4d"
  install -m755 build/px4-ts "${pkgdir}${JB}/usr/bin/px4-ts"
  install -m755 build/px4ctl "${pkgdir}${JB}/usr/bin/px4ctl"

  install -d "${pkgdir}${JB}/usr/share/licenses/px4-userland"
  install -m644 LICENSE "${pkgdir}${JB}/usr/share/licenses/px4-userland/"

  install -d "${pkgdir}${JB}/usr/share/doc/px4-userland"
  install -m644 "${PROJECTROOT}/copyright" "${pkgdir}${JB}/usr/share/doc/px4-userland/copyright"
}
