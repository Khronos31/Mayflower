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

# **-target を明示しないと macOS モードで建ってしまう。**
# --build=...darwin と名乗ると configure の Darwin 判定が走り、OS の版を読んで
# MACOSX_DEPLOYMENT_TARGET=16.7（iOS の版）を採用する。これは環境変数として
# clang に渡るため、iPhoneOS の sysroot を macOS 向けに読む状態になり
# （clang が "using sysroot for 'iPhoneOS' but targeting 'MacOSX'" と警告する）、
# 可用性マクロが噛み合わず getentropy が未宣言になって落ちる。
# -target は環境変数より優先されるので、これで押さえる。
COMMON_FLAGS="-target arm64-apple-ios16.0"

# os.system を使えるようにする。SDK は system(3) を iOS で塞いでおり、
# 塞ぎを外しても実行時に /bin/sh を探して失敗するため、共通層の差し替えを使う。
ios_compat=1

prepare() {
  cd "${srcdir}" || return 1
}

build() {
  cd "${srcdir}" || return 1

  # 共通層が -L/-rpath/-I を入れてくれるので、ここでは CPython 固有のものだけ。
  # iOS SDK は宣言を出さないが libSystem にシンボルはある、という関数がある。
  # configure はリンクで見つけて HAVE_* を立てるが、コンパイルは
  # -Werror=implicit-function-declaration で落ちる。該当するものは
  # ac_cv_func_*=no にして CPython の代替経路へ逃がす。
  #   getentropy … iOS の sys/random.h に宣言が無い。CPython は /dev/urandom へ落ちる
  #
  # SDK が iOS で塞いでいる関数のうち、使えるようにする価値のないものも落とす。
  #   clock_settime … 時計の設定。root が要るうえ iOS では意味がない。
  #                   system(3) と違って差し替える値打ちがないので time モジュールから外す
  ac_cv_func_getentropy=no \
  ac_cv_func_clock_settime=no \
  "${CONFIG_SHELL}" configure \
    --build=aarch64-apple-darwin \
    --prefix="${JB}/usr" \
    --enable-shared \
    `# --with-system-expat は使わない。pyexpat.c が expat_config.h を無条件に` \
    `# include するのに、システムの expat はそれを配布せず、include パスにも` \
    `# Modules/expat が入らないため成立しない。上流にも同じ include が残って` \
    `# いるので、こちらの見落としがある余地はある（未確認）。同梱の expat を使う` \
    --with-ensurepip=install \
    --disable-test-modules \
    --without-static-libpython

  # make は $ROOTDIR/bin のラッパー（SHELL を与える）が PATH 先頭で拾われる
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
