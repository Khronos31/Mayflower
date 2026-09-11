# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034  # 変数は ../../make.sh が読む/export する
#
# Mayflower | packages/python/make.sh
#
# CPython を rootless 脱獄 iOS 上でセルフビルドする。
#
# **darwin として建てる。** CPython 3.13 以降は PEP 730 で iOS を公式に
# サポートしているが、あれは App Store の制約を前提にした構成で、プロセス生成を
# 落とす方向に寄っている。脱獄機では subprocess が使えてこそ意味があるので、
# 2020 年の python-jailbroken-ios と同じく host/build を darwin と名乗らせる。
#
# `uname -m` が iPhone10,1 を返すので config.guess は当てにならない。
# --build を明示する。

pkgname=python
pkgver=3.14.7
pkgrel=1
srcname="Python-${pkgver}"
source="https://www.python.org/ftp/python/${pkgver}/Python-${pkgver}.tar.xz"

pyseries=3.14

prepare() {
  cd "${srcdir}" || return 1
}

build() {
  cd "${srcdir}" || return 1

  # 共通層が -L/-rpath/-I を入れてくれるので、ここでは CPython 固有のものだけ。
  sh configure \
    --build=aarch64-apple-darwin \
    --prefix="${JB}/usr" \
    --enable-shared \
    --with-system-expat \
    --with-ensurepip=install \
    --disable-test-modules \
    --without-static-libpython

  make -j"$(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || echo 4)"
}

check() {
  cd "${srcdir}" || return 1
  # 建てた python が動き、脱獄機で効いてほしいものが揃っているかを見る。
  DYLD_LIBRARY_PATH="${srcdir}" ./python.exe -c '
import sys, sysconfig, subprocess, ssl, sqlite3, lzma, bz2, zlib, ctypes, readline
print("version ", sys.version.split()[0])
print("platform", sys.platform, sysconfig.get_platform())
print("ssl     ", ssl.OPENSSL_VERSION)
print("sqlite3 ", sqlite3.sqlite_version)
print("lzma    ", lzma.__name__, "ok")
print("subprocess", subprocess.run(["uname","-m"], capture_output=True, text=True).stdout.strip())
print("shell   ", subprocess.run("echo shell-ok", shell=True, capture_output=True, text=True).stdout.strip() or "FAILED")
'
}

package() {
  cd "${srcdir}" || return 1
  make DESTDIR="${pkgdir}" install
  # 配布に要らないもの
  rm -rf "${pkgdir}${JB}/usr/lib/python${pyseries}/test"
  rm -rf "${pkgdir}${JB}/usr/lib/python${pyseries}/idlelib"
  rm -rf "${pkgdir}${JB}/usr/lib/python${pyseries}/tkinter"
  find "${pkgdir}" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
  install -d "${pkgdir}${JB}/usr/share/licenses/python"
  install -m644 LICENSE "${pkgdir}${JB}/usr/share/licenses/python/LICENSE"
}
