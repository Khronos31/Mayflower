. "${ROOTDIR}/util/options.sh"
. "${ROOTDIR}/util/tidy.sh"

DEFAULT_CC() {
  echo "${ROOTDIR}/bin/cc"
}

DEFAULT_CXX() {
  echo "${ROOTDIR}/bin/c++"
}

clean() {
  if [ -e "${BUILDROOT}" ]; then
    rm -rf "${BUILDROOT}"
  fi
  mkdir -p "${BUILDROOT}"
}

download() {
  local tarball
  tarball="$(basename "${source}")"
  if [ ! -r "${PROJECTROOT}/${tarball}" ]; then
    curl -o "${PROJECTROOT}/${tarball}" "${source}"
  fi
  tar xvf "${tarball}" -C "${BUILDROOT}"
}

applyPatch() {
  find "${PROJECTROOT}/patches" -name "*.patch" |
  while read p; do
    patch -u -p0 -d "${BUILDROOT}" -i "$p"
  done
}

merge() {
  mkdir -p "${PROJECTROOT}/fat/build"
  cp -nR "${PROJECTROOT}/arm64/build/."
  cp -nR "${PROJECTROOT}/armv7/build/." "${PROJECTROOT}/fat/build"

  cd "${PROJECTROOT}"

  find "fat/build" -type f |
  while read x; do
    if lipo -info "$x" >/dev/null 2>&1; then
      rm "$x"
      lipo -create "${x/fat/arm64}" "${x/fat/armv7}" -output "$x"
      if test -x "$x"; then
        ldid -S/usr/share/SDKs/entitlements.xml "$x"
      fi
    fi
  done
}

makedeb() {
  cp -R "${PROJECTROOT}/deb/." "${BUILDROOT}/build"
  local os_ver
  case "${ARCH}" in
    armv7) os_ver="<<11.0";;
    arm64) os_ver=">=11.0";;
    *) echo "Unknown architecture" >&2; exit 1;;
  esac
  sed -e "/^Version:/s/@VERSION@/${pkgver}-${pkgrel}/" \
      -e "/^Depends:/s/@FIRMWARE_VERSION@/${os_ver}/" \
      -i -- "${BUILDROOT}/build/DEBIAN/control"
  if dpkg --compare-versions "$(dpkg-query -f '${Version}' -W dpkg)" ge 1.19.0; then
    dpkg-deb -Z${compress-gzip} --root-owner-group --build "${BUILDROOT}/build" "${BUILDROOT}"
  else
    su <<<"chown -R 0:0 \"${BUILDROOT}/build\""
    dpkg-deb -Z${compress-gzip} --build "${BUILDROOT}/build" "${BUILDROOT}"
  fi
}
