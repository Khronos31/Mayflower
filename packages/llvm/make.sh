# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/llvm/make.sh
#
# Mac で建てた dist を梱包。端末ではソースビルドしない。
# Swift は別パッケージ（ここには含めない）。
#
# 分割:
#   clang-19, llvm-19-linker-tools, llvm-19
# 置換メタ（Procursus の clang / llvm を Provides + Conflicts/Replaces）:
#   clang-default, llvm-default

pkgname=llvm
pkgver=19.1.4
pkgrel=5
# dist tarball 名に残っているだけ（Swift 同梱前の Mac 成果物）
swiftver=6.1.1
srcname=dist
source=""
subpkgs=(clang19 linkertools llvm19 clangdefault llvmdefault)
export compress=xz

llvm_major=19

llvm_prefix() {
  echo "${JB}/usr/lib/llvm-${llvm_major}"
}

tree_name() {
  echo "llvm-${pkgver}-swift-${swiftver}-aarch64-apple-ios"
}

prepare() {
  : "${LLVM_DIST_DIR:?Mac で建てた dist のあるディレクトリを渡すこと（tools/mac/llvm-swift/build.sh）}"
  mkdir -p "${srcdir}"
  cd "${srcdir}" || return 1
  local t
  t="$(tree_name)"
  if [ ! -d "${t}" ]; then
    [ -r "${LLVM_DIST_DIR}/${t}.tar.xz" ] || {
      echo "prepare: ${LLVM_DIST_DIR}/${t}.tar.xz が無い" >&2
      return 1
    }
    tar xf "${LLVM_DIST_DIR}/${t}.tar.xz"
  fi
}

build() {
  :
}

check() {
  cd "${srcdir}" || return 1
  local clang
  clang="$(tree_name)/bin/clang"
  [ -x "${clang}" ] || {
    echo "check: ${clang} が無い" >&2
    return 1
  }
  if command -v ldid >/dev/null 2>&1; then
    ldid -S"${ENTFILE}" "${clang}"
  fi
  "${clang}" --version
}

install_tool() {
  local src="$1" dest="$2"
  install -d "$(dirname "${dest}")"
  if [ -L "${src}" ]; then
    cp -a "${src}" "${dest}"
  else
    install -m755 "${src}" "${dest}"
    ldid -S"${ENTFILE}" "${dest}" || true
  fi
}

install_clang_wrapper() {
  local outname="$1" toolname="$2" pref="$3"
  local real="${pref}/bin/${toolname}"
  [ -e "${pkgdir}${real}" ] || [ -L "${pkgdir}${real}" ] || return 0
  "${CC}" -O2 -o "${pkgdir}${JB}/usr/bin/${outname}" \
    "${PROJECTROOT}/files/toolchain-wrapper.c" \
    -DTOOL="\"${real}\"" \
    -DDEFAULT_SYSROOT="\"${JB}/usr/share/SDKs/iPhoneOS.sdk\"" \
    -DEXTRA_CPATH="\"${JB}/usr/include\"" \
    -DEXTRA_LIBRARY_PATH="\"${JB}/usr/lib\""
  ldid -S"${ENTFILE}" "${pkgdir}${JB}/usr/bin/${outname}"
}

package_clang19() {
  cd "${srcdir}" || return 1
  local tree pref
  tree="$(tree_name)"
  pref="$(llvm_prefix)"

  install -d "${pkgdir}${pref}/bin" "${pkgdir}${pref}/lib" \
    "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/clang-${llvm_major}" \
    "${pkgdir}${JB}/usr/share/licenses/clang-${llvm_major}"

  install_tool "${tree}/bin/clang-19" "${pkgdir}${pref}/bin/clang-19"
  ln -sf clang-19 "${pkgdir}${pref}/bin/clang"
  ln -sf clang-19 "${pkgdir}${pref}/bin/clang++"
  ln -sf clang-19 "${pkgdir}${pref}/bin/clang-cpp"

  if [ -d "${tree}/lib/clang" ]; then
    cp -a "${tree}/lib/clang" "${pkgdir}${pref}/lib/"
  fi

  install -m644 "${PROJECTROOT}/files/entitlements.plist" \
    "${pkgdir}${pref}/entitlements.plist"

  install_clang_wrapper "clang-${llvm_major}" "clang-19" "${pref}"
  install_clang_wrapper "clang++-${llvm_major}" "clang++" "${pref}"
  install_clang_wrapper "clang-cpp-${llvm_major}" "clang-cpp" "${pref}"

  if [ -r "${tree}/LICENSE.TXT" ]; then
    install -m644 "${tree}/LICENSE.TXT" \
      "${pkgdir}${JB}/usr/share/licenses/clang-${llvm_major}/"
  fi
}

package_linkertools() {
  cd "${srcdir}" || return 1
  local tree pref
  tree="$(tree_name)"
  pref="$(llvm_prefix)"

  install -d "${pkgdir}${pref}/bin" "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/llvm-${llvm_major}-linker-tools"

  install_tool "${tree}/bin/lld" "${pkgdir}${pref}/bin/lld"
  ln -sf lld "${pkgdir}${pref}/bin/ld64.lld"
  ln -sf lld "${pkgdir}${pref}/bin/ld.lld"

  local t
  for t in lld ld64.lld ld.lld; do
    ln -sf "../lib/llvm-${llvm_major}/bin/${t}" \
      "${pkgdir}${JB}/usr/bin/${t}-${llvm_major}"
  done
}

package_llvm19() {
  cd "${srcdir}" || return 1
  local tree pref
  tree="$(tree_name)"
  pref="$(llvm_prefix)"

  install -d "${pkgdir}${pref}/bin" "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/llvm-${llvm_major}"

  local t
  for t in llvm-ar llvm-nm llvm-config; do
    [ -e "${tree}/bin/${t}" ] || continue
    install_tool "${tree}/bin/${t}" "${pkgdir}${pref}/bin/${t}"
  done
  if [ -e "${tree}/bin/llvm-ranlib" ]; then
    cp -a "${tree}/bin/llvm-ranlib" "${pkgdir}${pref}/bin/llvm-ranlib"
  else
    ln -sf llvm-ar "${pkgdir}${pref}/bin/llvm-ranlib"
  fi

  for t in llvm-ar llvm-nm llvm-ranlib llvm-config; do
    [ -e "${pkgdir}${pref}/bin/${t}" ] || continue
    ln -sf "../lib/llvm-${llvm_major}/bin/${t}" \
      "${pkgdir}${JB}/usr/bin/${t}-${llvm_major}"
  done
}

package_clangdefault() {
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/clang-default"

  ln -sf "clang-${llvm_major}" "${pkgdir}${JB}/usr/bin/clang"
  ln -sf "clang++-${llvm_major}" "${pkgdir}${JB}/usr/bin/clang++"
  ln -sf "clang-cpp-${llvm_major}" "${pkgdir}${JB}/usr/bin/clang-cpp"
  ln -sf "clang-${llvm_major}" "${pkgdir}${JB}/usr/bin/cc"
  ln -sf "clang++-${llvm_major}" "${pkgdir}${JB}/usr/bin/c++"

  printf 'clang-default → clang-%s\n' "${llvm_major}" \
    > "${pkgdir}${JB}/usr/share/doc/clang-default/README"
}

package_llvmdefault() {
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/llvm-default"

  local t
  for t in llvm-ar llvm-nm llvm-ranlib llvm-config lld; do
    ln -sf "${t}-${llvm_major}" "${pkgdir}${JB}/usr/bin/${t}"
  done
  ln -sf "ld64.lld-${llvm_major}" "${pkgdir}${JB}/usr/bin/ld64.lld"
  ln -sf "ld.lld-${llvm_major}" "${pkgdir}${JB}/usr/bin/ld.lld"

  printf 'llvm-default → llvm-%s tools\n' "${llvm_major}" \
    > "${pkgdir}${JB}/usr/share/doc/llvm-default/README"
}
