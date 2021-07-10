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
    curl -sSL -o "${PROJECTROOT}/${tarball}" "${source}"
  fi
  tar xvf "${tarball}" -C "${BUILDROOT}"
}

applyPatch() {
  find "${PROJECTROOT}/patches" -name "*.patch" |
  while read p; do
    patch -u -p0 -d "${BUILDROOT}" -i "$p"
  done
}

makedeb() {
  cp -R "${PROJECTROOT}/deb/." "${BUILDROOT}/build"
  local os_ver
  os_ver=">=11.0"
  mv "${BUILDROOT}/build/DEBIAN/control" "${BUILDROOT}/build/DEBIAN/control_"
  sed -e "/^Version:/s/@VERSION@/${pkgver}-${pkgrel}/" \
      -e "/^Depends:/s/@FIRMWARE_VERSION@/${os_ver}/" \
      "${BUILDROOT}/build/DEBIAN/control_" >"${BUILDROOT}/build/DEBIAN/control"
  rm "${BUILDROOT}/build/DEBIAN/control_"
  dpkg-deb -Z${compress-gzip} --root-owner-group --build "${BUILDROOT}/build" "${BUILDROOT}"
}
