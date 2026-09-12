# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/luarocks/make.sh
#
# LuaRocks 3.13.0。Lua 5.5 向け。C はほぼ無く、configure + スクリプトの
# インストール。端末に lua5.5 / liblua5.5-dev が要る。
#
# Procursus に luarocks は無い。

pkgname=luarocks
pkgver=3.13.0
pkgrel=2
srcname="luarocks-${pkgver}"
source="https://luarocks.github.io/luarocks/releases/luarocks-${pkgver}.tar.gz"

prepare() {
  cd "${srcdir}" || return 1
}

build() {
  cd "${srcdir}" || return 1

  "${CONFIG_SHELL}" configure \
    --prefix="${JB}/usr" \
    --sysconfdir="${JB}/usr/etc" \
    --rocks-tree="${JB}/usr/local" \
    --lua-version=5.5 \
    --with-lua="${JB}/usr" \
    --with-lua-include="${JB}/usr/include/lua5.5" \
    --with-lua-interpreter=lua5.5

  make
}

check() {
  cd "${srcdir}" || return 1
  # build/luarocks はインストール後の prefix を焼き込む。未 install では src を LUA_PATH に。
  LUA_PATH="${srcdir}/src/?.lua;;" lua5.5 "${srcdir}/src/bin/luarocks" --version
}

package() {
  cd "${srcdir}" || return 1
  make DESTDIR="${pkgdir}" install

  install -d "${pkgdir}${JB}/usr/share/licenses/luarocks"
  install -m644 COPYING "${pkgdir}${JB}/usr/share/licenses/luarocks/"
}
