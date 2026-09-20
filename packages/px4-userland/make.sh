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
# ファームウェアは同梱しない。PC/SC IFD は libpcsclite-dev のヘッダで建て、
# dylib を pcscd が dlopen する（macOS bundle は使わない）。
#
# se3 実機: 薄い entitlements の libusb 列挙はデバイス有りでも 0 件。
# px4-usb-probe を同じ USB entitlements で入れてシリアルを出す。
# iOS に XDG_RUNTIME_DIR が無く、runtime-dir は 0700・同一 uid 必須。
# PATH の px4d/px4-ts/px4ctl はラッパーで ${JB}/var/run/px4-userland を足す。

pkgname=px4-userland
pkgver=0.1.3
pkgrel=4
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
  "${CXX}" ${CXXFLAGS} -std=c++17 -fno-exceptions -fno-rtti -fPIC \
    -c "${PROJECTROOT}/files/libcpp_verbose_abort.cpp" -o "${abort_o}"

  export PKG_CONFIG_PATH="${JB}/usr/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"

  cmake -S . -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_MAKE_PROGRAM="${ROOTDIR}/bin/make" \
    -DCMAKE_CXX_COMPILER="${CXX}" \
    -DCMAKE_PREFIX_PATH="${JB}/usr" \
    -DPX4_LIBUSB_INCLUDE_DIR="${JB}/usr/include/libusb-1.0" \
    -DPX4_LIBUSB_LIBRARY="${JB}/usr/lib/libusb-1.0.dylib" \
    -DPX4_BUILD_TESTS=OFF \
    -DPX4_BUILD_TOOLS=ON \
    -DPX4_BUILD_PCSC_IFD=ON \
    -DPX4_REQUIRE_PCSC_IFD=ON \
    -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS} ${abort_o} -lobjc -Wl,-framework,IOKit -Wl,-framework,CoreFoundation -Wl,-framework,Security -Wl,-stack_size,0x800000" \
    -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS} ${abort_o}"

  cmake --build build --target px4d px4-ts px4ctl px4_ifdhandler px4-usb-probe
}

check() {
  cd "${srcdir}/build" || return 1
  _set_ent
  ./px4d --help >/dev/null
  ./px4-ts --help >/dev/null
  ./px4ctl --help >/dev/null
  ./px4-usb-probe --help >/dev/null
  test -f ./libpx4-userland-ifd.dylib
}

package() {
  cd "${srcdir}" || return 1
  _set_ent

  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/lib/px4-userland" \
    "${pkgdir}${JB}/usr/share/px4-userland"
  install -m755 build/px4d "${pkgdir}${JB}/usr/lib/px4-userland/px4d"
  install -m755 build/px4-ts "${pkgdir}${JB}/usr/lib/px4-userland/px4-ts"
  install -m755 build/px4ctl "${pkgdir}${JB}/usr/lib/px4-userland/px4ctl"
  local b
  for b in px4d px4-ts px4ctl; do
    ldid -S"${ENTFILE}" "${pkgdir}${JB}/usr/lib/px4-userland/${b}"
  done
  mayflower_wrapper_compile "${pkgdir}${JB}/usr/bin/px4d" \
    "${ROOTDIR}/files/mayflower-px4.c" -DTOOL='"px4d"' -DPX4_INJECT_FIRMWARE=1
  mayflower_wrapper_compile "${pkgdir}${JB}/usr/bin/px4-ts" \
    "${ROOTDIR}/files/mayflower-px4.c" -DTOOL='"px4-ts"'
  mayflower_wrapper_compile "${pkgdir}${JB}/usr/bin/px4ctl" \
    "${ROOTDIR}/files/mayflower-px4.c" -DTOOL='"px4ctl"'
  install -m755 build/px4-usb-probe "${pkgdir}${JB}/usr/bin/px4-usb-probe"
  ldid -S"${ENTFILE}" "${pkgdir}${JB}/usr/bin/px4-usb-probe"
  install -m755 build/libpx4-userland-ifd.dylib \
    "${pkgdir}${JB}/usr/lib/px4-userland/libpx4-userland-ifd.dylib"
  ldid -S"${ENTFILE}" "${pkgdir}${JB}/usr/lib/px4-userland/libpx4-userland-ifd.dylib"
  install -m644 packaging/pcsc/reader.conf.d/px4-userland.conf.in \
    "${pkgdir}${JB}/usr/share/px4-userland/px4-userland.conf.in"
  mayflower_wrapper_compile "${pkgdir}${JB}/usr/bin/px4-pcsc-register" \
    "${ROOTDIR}/files/mayflower-px4-pcsc-register.c" -DJB="\"${JB}\""

  install -d "${pkgdir}${JB}/usr/share/licenses/px4-userland"
  install -m644 LICENSE "${pkgdir}${JB}/usr/share/licenses/px4-userland/"

  install -d "${pkgdir}${JB}/usr/share/doc/px4-userland"
  install -m644 "${PROJECTROOT}/copyright" "${pkgdir}${JB}/usr/share/doc/px4-userland/copyright"
}
