# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/pcsc-lite/make.sh
#
# pcsc-lite 2.5.1 を端末の Clang 19 + meson で建てる。
# Procursus に同名は無い。Debian と同じ libpcsclite1 / pcscd / libpcsclite-dev。
#
# USB ホットプラグ（libudev / libusb）は切る。シリアル reader.conf.d で
# px4-userland IFD を載せる前提。Darwin なので meson は IOKit/Foundation を
# リンクするが、pcscd --version には IOKit entitlements は不要。

pkgname=pcsc-lite
pkgver=2.5.1
pkgrel=4
srcname="pcsc-lite-${pkgver}"
source="https://pcsclite.apdu.fr/files/pcsc-lite-${pkgver}.tar.xz"
subpkgs=(libpcsclite pcscd dev)
export compress="${compress:-xz}"

_pydeps() {
  echo "${BUILDROOT}/pydeps"
}

prepare() {
  cd "${srcdir}" || return 1
  python3 -m pip install --isolated --disable-pip-version-check \
    --no-warn-script-location --target="$(_pydeps)" 'meson>=1.3'
  # iOS SDK の IOKit に IOCFPlugIn.h が無い。macOS USB ホットプラグは使わず
  # dyn_macosx.c（IFD の dlopen）だけ足す。
  python3 - "${srcdir}/meson.build" <<'PY'
from pathlib import Path
import re
import sys
p = Path(sys.argv[1])
t = p.read_text()
if "MAYFLOWER_NO_MACOS_HOTPLUG" in t:
    sys.exit(0)
pat = re.compile(
    r"if pcsc_arch == 'Darwin'\n"
    r".*?pcscd_src \+= files\(\['src/hotplug_macosx.c', 'src/dyn_macosx.c'\]\)\n"
    r"endif",
    re.S,
)
new = (
    "if pcsc_arch == 'Darwin'\n"
    "  pcsc_arch = 'MacOS'\n"
    "  # MAYFLOWER_NO_MACOS_HOTPLUG: IFD は dlopen（dyn_unix.c）\n"
    "endif"
)
t2, n = pat.subn(new, t, count=1)
if n != 1:
    raise SystemExit(f"prepare: Darwin block match count {n}")
p.write_text(t2)
PY
  python3 - "${srcdir}/src/hotplug_generic.c" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
t = p.read_text()
old = "#if !defined(__APPLE__) && !defined(HAVE_LIBUSB) && !defined(HAVE_LIBUDEV)"
new = "#if !defined(HAVE_LIBUSB) && !defined(HAVE_LIBUDEV) /* MAYFLOWER_GENERIC_HOTPLUG */"
if "MAYFLOWER_GENERIC_HOTPLUG" in t:
    sys.exit(0)
if old not in t:
    raise SystemExit("prepare: hotplug_generic ifdef not found")
p.write_text(t.replace(old, new, 1))
PY
  python3 - "${srcdir}/src/dyn_unix.c" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
t = p.read_text()
if "MAYFLOWER_DLOPEN" in t:
    sys.exit(0)
if "#ifndef __APPLE__" not in t:
    raise SystemExit("prepare: dyn_unix.c ifndef APPLE not found")
t = t.replace("#ifndef __APPLE__", "#if 1 /* MAYFLOWER_DLOPEN */", 1)
p.write_text(t)
PY
  python3 "${PROJECTROOT}/files/skip-pod2man.py" "${srcdir}/meson.build"
}

build() {
  cd "${srcdir}" || return 1
  export PYTHONPATH="$(_pydeps)${PYTHONPATH:+:${PYTHONPATH}}"
  export PATH="$(_pydeps)/bin:${PATH}"
  export PKG_CONFIG_PATH="${JB}/usr/lib:${JB}/usr/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
  command -v meson >/dev/null || {
    echo "build: meson が無い" >&2
    return 1
  }
  command -v flex >/dev/null || {
    echo "build: flex が無い（Procursus の flex）" >&2
    return 1
  }
  meson setup build \
    --prefix="${JB}/usr" \
    --sysconfdir="${JB}/etc" \
    --sbindir="${JB}/usr/sbin" \
    --buildtype=release \
    -Ddefault_library=shared \
    -Dlibsystemd=false \
    -Dlibudev=false \
    -Dlibusb=false \
    -Dpolkit=false \
    -Dusb=true \
    -Dserial=true \
    -Dipcdir="${JB}/var/run/pcscd" \
    -Dusbdropdir="${JB}/usr/lib/pcsc/drivers" \
    -Dserialconfdir="${JB}/etc/reader.conf.d"
  # Procursus の ninja は posix_spawn("/bin/sh") する。rootless に /bin/sh は無い。
  # 同じ長さの /tmp/sh へ差し替えて ldid し直す。
  local nj
  nj="${BUILDROOT}/ninja"
  cp /var/jb/usr/bin/ninja "${nj}"
  python3 - "${nj}" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
b = p.read_bytes()
old, new = b"/bin/sh", b"/tmp/sh"
if old not in b:
    raise SystemExit("build: /bin/sh not found in ninja")
p.write_bytes(b.replace(old, new))
PY
  ldid -S"${ENTFILE}" "${nj}"
  chmod +x "${nj}"
  ln -sf "${JB}/bin/sh" /tmp/sh
  export PATH="${BUILDROOT}:${PATH}"
  meson compile -C build
}

check() {
  cd "${srcdir}" || return 1
  local bin="${srcdir}/build/pcscd"
  ldid -S"${ENTFILE}" "${bin}"
  "${bin}" --version
}

_destdir() {
  echo "${BUILDROOT}/dest"
}

_stage_install() {
  local d
  d="$(_destdir)"
  if [ ! -x "${d}${JB}/usr/sbin/pcscd" ]; then
    cd "${srcdir}" || return 1
    export PYTHONPATH="$(_pydeps)${PYTHONPATH:+:${PYTHONPATH}}"
    export PATH="$(_pydeps)/bin:${PATH}"
    DESTDIR="${d}" meson install -C build --no-rebuild
  fi
}

package_libpcsclite() {
  _stage_install
  local d="$(_destdir)"
  install -d "${pkgdir}${JB}/usr/lib"
  install -m755 "${d}${JB}/usr/lib/libpcsclite.1.dylib" "${pkgdir}${JB}/usr/lib/"
  # Dopamine (se3) は未署名/不正ページの dylib を CODESIGNING Invalid Page で落とす。
  # tidy_resign の ldid 失敗は || true で握りつぶされるので、ここで明示署名する。
  ldid -S"${ENTFILE}" "${pkgdir}${JB}/usr/lib/libpcsclite.1.dylib"
  if [ -f "${d}${JB}/usr/lib/libpcsclite_real.1.dylib" ]; then
    install -m755 "${d}${JB}/usr/lib/libpcsclite_real.1.dylib" "${pkgdir}${JB}/usr/lib/"
    ldid -S"${ENTFILE}" "${pkgdir}${JB}/usr/lib/libpcsclite_real.1.dylib"
    ln -s libpcsclite_real.1.dylib "${pkgdir}${JB}/usr/lib/libpcsclite_real.dylib"
    ln -s libpcsclite_real.1.dylib "${pkgdir}${JB}/usr/lib/libpcsclite_real.so.1"
  fi
  ln -s libpcsclite.1.dylib "${pkgdir}${JB}/usr/lib/libpcsclite.so.1"
}

package_pcscd() {
  _stage_install
  local d="$(_destdir)"
  install -d "${pkgdir}${JB}/usr/sbin" \
    "${pkgdir}${JB}/etc/reader.conf.d" \
    "${pkgdir}${JB}/usr/lib/pcsc/drivers" \
    "${pkgdir}${JB}/var/run/pcscd" \
    "${pkgdir}${JB}/var/log" \
    "${pkgdir}${JB}/Library/LaunchDaemons" \
    "${pkgdir}${JB}/usr/share/man/man8" \
    "${pkgdir}${JB}/usr/share/man/man5"
  install -m755 "${d}${JB}/usr/sbin/pcscd" "${pkgdir}${JB}/usr/sbin/pcscd"
  ldid -S"${ENTFILE}" "${pkgdir}${JB}/usr/sbin/pcscd"
  install -m644 "${PROJECTROOT}/files/fr.apdu.pcscd.plist" \
    "${pkgdir}${JB}/Library/LaunchDaemons/fr.apdu.pcscd.plist"
  if [ -f "${d}${JB}/usr/share/man/man8/pcscd.8" ]; then
    install -m644 "${d}${JB}/usr/share/man/man8/pcscd.8" \
      "${pkgdir}${JB}/usr/share/man/man8/"
  fi
  if [ -f "${d}${JB}/usr/share/man/man5/reader.conf.5" ]; then
    install -m644 "${d}${JB}/usr/share/man/man5/reader.conf.5" \
      "${pkgdir}${JB}/usr/share/man/man5/"
  fi
}

package_dev() {
  _stage_install
  local d="$(_destdir)"
  install -d "${pkgdir}${JB}/usr/include/PCSC" \
    "${pkgdir}${JB}/usr/lib/pkgconfig" \
    "${pkgdir}${JB}/usr/lib"
  install -m644 "${d}${JB}/usr/include/PCSC/"*.h "${pkgdir}${JB}/usr/include/PCSC/"
  ln -s libpcsclite.1.dylib "${pkgdir}${JB}/usr/lib/libpcsclite.dylib"
  if [ -f "${d}${JB}/usr/lib/pkgconfig/libpcsclite.pc" ]; then
    install -m644 "${d}${JB}/usr/lib/pkgconfig/libpcsclite.pc" \
      "${pkgdir}${JB}/usr/lib/pkgconfig/"
  elif [ -f "${d}${JB}/usr/lib/libpcsclite.pc" ]; then
    install -d "${pkgdir}${JB}/usr/lib/pkgconfig"
    install -m644 "${d}${JB}/usr/lib/libpcsclite.pc" \
      "${pkgdir}${JB}/usr/lib/pkgconfig/"
  fi
}
