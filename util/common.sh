# shellcheck shell=bash
# shellcheck disable=SC2154  # 変数は make.sh が export する
#
# Mayflower | util/common.sh
#
# make.sh から読まれる共通処理。パッケージ側の make.sh はここの関数を
# 上書きしてよい（例: 独自の download）。

. "${ROOTDIR}/util/options.sh"
. "${ROOTDIR}/util/tidy.sh"

# リンク後に ldid で署名する clang ラッパー。脱獄 iOS では entitlements を
# 持たない Mach-O は起動時に SIGKILL される（素の clang 出力も、entitlements
# なしの `ldid -S` も rc=137）。
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
    curl -fsSL -o "${PROJECTROOT}/${tarball}" "${source}"
  fi
  tar xf "${PROJECTROOT}/${tarball}" -C "${BUILDROOT}"
}

# patches/*.patch を srcdir へ当てる。パッチは
# `diff -u --label a/<path> --label b/<path>` 形式で書くこと（-p1 で当てる）。
applyPatch() {
  local p
  for p in "${PROJECTROOT}"/patches/*.patch; do
    [ -e "$p" ] || continue
    echo "==> patch: $(basename "$p")"
    patch -p1 -d "${srcdir}" -i "$p"
  done
}

makedeb() {
  cp -R "${PROJECTROOT}/deb/." "${pkgdir}"

  find "${pkgdir}" -type d -exec chmod 755 {} +
  find "${pkgdir}/DEBIAN" -type f -exec chmod 755 {} +

  local size
  size="$(du -sk "${pkgdir}${JB}" | cut -f1)"

  local control="${pkgdir}/DEBIAN/control"
  sed -e "s/@VERSION@/${pkgver}-${pkgrel}/" \
      -e "s/@ARCH@/${DEB_ARCH}/" \
      -e "s/@INSTALLED_SIZE@/${size}/" \
      "${control}" > "${control}.new"
  mv "${control}.new" "${control}"
  chmod 644 "${control}"

  dpkg-deb "-Z${compress:-xz}" --root-owner-group --build "${pkgdir}" "${BUILDROOT}"
}
