# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034  # 変数は ../../make.sh が読む/export する
#
# Mayflower | example/make.sh
#
# 新しいパッケージの雛形。packages/<名前>/ にコピーして使う。
# 枝の切り方と PR の題名は docs/adding.md。
#
# 使える変数（../../make.sh が export する）:
#   JB        脱獄の接頭辞（/var/jb）
#   ARCH      arm64
#   DEB_ARCH  iphoneos-arm64
#   ENTFILE   entitlements.plist の絶対パス
#   ROOTDIR   リポジトリのルート
#   PROJECTROOT このパッケージのディレクトリ
#   BUILDROOT ビルド作業場（packages/<名前>/arm64）
#   srcdir    展開されたソース（$BUILDROOT/$pkgname-$pkgver）
#   pkgdir    パッケージの中身を置く場所（$BUILDROOT/build）
#   CC / CXX  ldid 署名付きの clang ラッパー

pkgname=
pkgver=
pkgrel=1

# ソース書庫の URL。空にすると download を飛ばす。
source=""

# 展開直後・パッチ適用前に走る。省略可。
prepare() {
  cd "${srcdir}" || return 1
}

build() {
  cd "${srcdir}" || return 1

  ./configure \
    --build=aarch64-apple-darwin \
    --prefix="${JB}/usr"
  make
}

# 省略可。定義してあれば build と package の間で走る。
check() {
  cd "${srcdir}" || return 1
  make check
}

package() {
  cd "${srcdir}" || return 1
  make DESTDIR="${pkgdir}" install
}
