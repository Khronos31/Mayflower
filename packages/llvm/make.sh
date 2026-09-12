# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/llvm/make.sh
#
# **これだけは端末で建てない。** LLVM + Swift の bootstrap は iPhone 8 では
# 成立しない。Mac で Swift 6.1.x / Clang 19 をクロスし、出来た prefix を
# ここへ渡して梱包する。建て方は tools/mac/llvm-swift/build.sh。
#
# 出来上がるのは2つ（当面 default メタは作らない = Procursus clang-16 /
# swift 5.9.2 を置換しない）:
#   clang-19   /var/jb/usr/lib/llvm-19 と clang-19 / clang++-19 など
#              （lld が主で ldid。clang は非 lld / dsymutil。patches-host/）
#   swift-6.1  swiftc-6.1 と Swift ランタイム（llvm-19 ツリー内）

pkgname=llvm
# Apple llvm-project @ swift-6.1.1-RELEASE → LLVM 19.1.4
pkgver=19.1.4
pkgrel=3
# Debian 風に Swift を版に載せる（表示・依存用）。実体の tarball 名は dist。
swiftver=6.1.1
srcname=dist
source=""
subpkgs=(clang swift)
export compress=xz

llvm_major=19
swift_series=6.1

llvm_prefix() {
  echo "${JB}/usr/lib/llvm-${llvm_major}"
}

prepare() {
  : "${LLVM_DIST_DIR:?Mac で建てた dist のあるディレクトリを渡すこと（tools/mac/llvm-swift/build.sh）}"
  mkdir -p "${srcdir}"
  cd "${srcdir}" || return 1
  local t="llvm-${pkgver}-swift-${swiftver}-aarch64-apple-ios"
  if [ ! -d "${t}" ]; then
    [ -r "${LLVM_DIST_DIR}/${t}.tar.xz" ] || {
      echo "prepare: ${LLVM_DIST_DIR}/${t}.tar.xz が無い" >&2
      return 1
    }
    tar xf "${LLVM_DIST_DIR}/${t}.tar.xz"
  fi
}

build() {
  : # 母艦で建ててある
}

check() {
  cd "${srcdir}" || return 1
  local tree="llvm-${pkgver}-swift-${swiftver}-aarch64-apple-ios"
  local clang="${tree}/bin/clang"
  [ -x "${clang}" ] || {
    echo "check: ${clang} が無い" >&2
    return 1
  }
  # 母艦では未署名。ここでは --version だけ（端末の ldid 前提）。
  if command -v ldid >/dev/null 2>&1; then
    ldid -S"${ENTFILE}" "${clang}"
  fi
  "${clang}" --version
}

package_clang() {
  cd "${srcdir}" || return 1
  local tree="llvm-${pkgver}-swift-${swiftver}-aarch64-apple-ios"
  local pref
  pref="$(llvm_prefix)"

  install -d "${pkgdir}${pref}" \
    "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/clang-${llvm_major}" \
    "${pkgdir}${JB}/usr/share/licenses/clang-${llvm_major}"

  # prefix 丸ごとでは Swift も入るので、clang 側は bin/lib の Clang/LLVM 系を中心に。
  # 実配布の切り方は dist の中身を見て調整する。初期はツリーを共有し、
  # swift パッケージが同じ pref を Depends する前提で clang が本体を持つ。
  cp -a "${tree}/." "${pkgdir}${pref}/"

  # entitlements（ドライバが $PREFIX/entitlements.plist を探す）
  install -m644 "${PROJECTROOT}/files/entitlements.plist" \
    "${pkgdir}${pref}/entitlements.plist"

  # 版付き symlink（実体は llvm-19/bin）
  local t
  for t in clang clang++ clang-cpp lld llvm-ar llvm-ranlib llvm-nm llvm-config; do
    if [ -e "${pkgdir}${pref}/bin/${t}" ]; then
      ln -sf "../lib/llvm-${llvm_major}/bin/${t}" \
        "${pkgdir}${JB}/usr/bin/${t}-${llvm_major}"
    fi
  done
  # Darwin / ELF 風の lld フロントも版付きで残す（lld-19 とは別名）
  for t in ld64.lld ld.lld; do
    if [ -e "${pkgdir}${pref}/bin/${t}" ]; then
      ln -sf "../lib/llvm-${llvm_major}/bin/${t}" \
        "${pkgdir}${JB}/usr/bin/${t}-${llvm_major}"
    fi
  done

  if [ -r "${tree}/LICENSE.TXT" ]; then
    install -m644 "${tree}/LICENSE.TXT" \
      "${pkgdir}${JB}/usr/share/licenses/clang-${llvm_major}/"
  fi
}

package_swift() {
  # Swift の実体は clang パッケージが入れた llvm-19 ツリー内。
  # ここでは版付きコマンドの symlink と doc だけ置く。
  local pref
  pref="$(llvm_prefix)"
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/swift-${swift_series}" \
    "${pkgdir}${JB}/usr/share/licenses/swift-${swift_series}"

  local t
  for t in swift swiftc; do
    ln -sf "../lib/llvm-${llvm_major}/bin/${t}" \
      "${pkgdir}${JB}/usr/bin/${t}-${swift_series}"
  done

  # 空でも deb ができるようにプレースホルダ
  printf 'Swift %s (packaged with Mayflower llvm %s)\n' \
    "${swiftver}" "${pkgver}" \
    > "${pkgdir}${JB}/usr/share/doc/swift-${swift_series}/README.Mayflower"
}

