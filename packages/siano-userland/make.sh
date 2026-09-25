# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/siano-userland/make.sh
#
# siano-userland v0.1.6 → Package: siano-userland / Name: Siano Driver / バイナリ: siano-ts
# USB 受信のため packages/siano-userland/entitlements.plist（IOKit USB）を使う。
# ルートの薄い entitlements.plist では libusb が開けない。
#
# ファームウェア isdbt_rio.inp はソースに含まれない。git にも載せない。
# ${PROJECTROOT}/firmware/isdbt_rio.inp があればそれを使い、無ければ
# linux-firmware の固定 revision から取得して SHA-256 を検証する。

pkgname=siano-userland
pkgver=0.1.6
pkgrel=1
srcname="siano-userland-${pkgver}"
source="https://github.com/Khronos31/siano-userland/archive/refs/tags/v${pkgver}.tar.gz"

# linux-firmware の固定 blob（上流 release.yml と同じ）
_FIRMWARE_URL='https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/isdbt_rio.inp?id=e981caea6ed33c48d25b7dbf473327dbd01df163'
_FIRMWARE_SHA256='054520642d5d09cb7ab7d08dbd6fd9ba9365de56adf2e7d7d06927f9845ff818'

_ensure_firmware() {
  local dest="${PROJECTROOT}/firmware/isdbt_rio.inp"
  local tmp sum
  mkdir -p "${PROJECTROOT}/firmware"
  if [ -f "${dest}" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      sum="$(sha256sum "${dest}" | awk '{print $1}')"
    else
      sum="$(shasum -a 256 "${dest}" | awk '{print $1}')"
    fi
    if [ "${sum}" = "${_FIRMWARE_SHA256}" ]; then
      echo "${dest}"
      return 0
    fi
    echo "$0: ${dest} の SHA-256 が一致しない（${sum}）。取り直す" >&2
    rm -f "${dest}"
  fi
  tmp="$(mktemp)"
  curl -fsSL -o "${tmp}" "${_FIRMWARE_URL}"
  if command -v sha256sum >/dev/null 2>&1; then
    echo "${_FIRMWARE_SHA256}  ${tmp}" | sha256sum -c - >&2
  else
    echo "${_FIRMWARE_SHA256}  ${tmp}" | shasum -a 256 -c - >&2
  fi
  mv "${tmp}" "${dest}"
  echo "${dest}"
}

prepare() {
  cd "${srcdir}" || return 1
  # ルート make.sh は ENTFILE を薄いリポジトリルートへ上書きするので、ここで戻す。
  export ENTFILE="${PROJECTROOT}/entitlements.plist"
  [ -f "${ENTFILE}" ] || { echo "$0: missing ${ENTFILE}" >&2; return 1; }
}

build() {
  cd "${srcdir}" || return 1
  export ENTFILE="${PROJECTROOT}/entitlements.plist"

  # libusb.h は include/libusb-1.0/ 配下。pkg-config が無い環境向けに JB パスも足す。
  local usb_cflags usb_libs
  usb_cflags="$(pkg-config --cflags libusb-1.0 2>/dev/null || echo "-I${JB}/usr/include/libusb-1.0")"
  usb_libs="$(pkg-config --libs libusb-1.0 2>/dev/null || echo "-L${JB}/usr/lib -lusb-1.0")"

  # Theos 実機 Makefile 相当: IOKit/CF/Security + 大きめスタック
  "${CC}" ${CFLAGS} ${CPPFLAGS} ${usb_cflags} \
    -std=c11 -Wall -Wextra -Wpedantic \
    -D_POSIX_C_SOURCE=200809L -D_FILE_OFFSET_BITS=64 \
    -c siano-ts.c protocol.c stream-state.c control-parse.c

  "${CC}" ${CFLAGS} ${LDFLAGS} ${usb_cflags} \
    -o siano-ts siano-ts.o protocol.o stream-state.o control-parse.o \
    ${usb_libs} \
    -framework IOKit -framework CoreFoundation -framework Security \
    -Wl,-stack_size,0x800000
}

check() {
  cd "${srcdir}" || return 1
  export ENTFILE="${PROJECTROOT}/entitlements.plist"
  # チューナー未接続でも --list / --help は動く想定
  ./siano-ts --help >/dev/null
  ./siano-ts --list || true
}

package() {
  cd "${srcdir}" || return 1
  export ENTFILE="${PROJECTROOT}/entitlements.plist"

  local fw
  fw="$(_ensure_firmware)"

  install -d "${pkgdir}${JB}/usr/bin"
  install -m755 siano-ts "${pkgdir}${JB}/usr/bin/siano-ts"

  install -d "${pkgdir}${JB}/usr/share/siano-ts"
  install -m644 "${fw}" "${pkgdir}${JB}/usr/share/siano-ts/isdbt_rio.inp"
  # LICENCE.siano 要求: 再配布物に著作権表示と許諾文を添える
  install -m644 LICENCE.siano "${pkgdir}${JB}/usr/share/siano-ts/LICENCE.siano"
  install -m644 "${PROJECTROOT}/firmware/NOTICE" "${pkgdir}${JB}/usr/share/siano-ts/NOTICE"

  # 任意の探索パス（パッチで追加）にも置く
  install -d "${pkgdir}${JB}/lib/firmware"
  install -m644 "${fw}" "${pkgdir}${JB}/lib/firmware/isdbt_rio.inp"

  install -d "${pkgdir}${JB}/usr/share/licenses/siano-ts"
  install -m644 COPYING "${pkgdir}${JB}/usr/share/licenses/siano-ts/"
  install -m644 LICENCE.siano "${pkgdir}${JB}/usr/share/licenses/siano-ts/"

  install -d "${pkgdir}${JB}/usr/share/doc/siano-ts"
  install -m644 "${PROJECTROOT}/copyright" "${pkgdir}${JB}/usr/share/doc/siano-ts/copyright"
}
