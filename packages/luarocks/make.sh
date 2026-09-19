# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/luarocks/make.sh
#
# LuaRocks 3.13.0。Lua 5.5 向け。C はほぼ無く、configure + スクリプトの
# インストール。端末に lua5.5 / liblua5.5-dev が要る。
#
# 上流の bin/luarocks は `#!/usr/bin/env lua` の shebang スクリプト。
# Dopamine では PATH 入り口の shebang が posix_spawn EPERM になるので、
# スクリプトは libexec に置き、usr/bin には Mach-O ラッパーを置く（npm と同じ）。
#
# Procursus に luarocks は無い。

pkgname=luarocks
pkgver=3.13.0
pkgrel=3
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

  # shebang スクリプトを libexec へ移し、PATH 入り口を Mach-O にする。
  local libexec="${pkgdir}${JB}/usr/libexec/luarocks"
  local bindir="${pkgdir}${JB}/usr/bin"
  install -d "${libexec}"
  local b
  for b in luarocks luarocks-admin; do
    [ -f "${bindir}/${b}" ] || { echo "package: bin/${b} が無い" >&2; return 1; }
    # インタプリタを絶対パスに（/usr/bin/env は rootless に無い）
    {
      printf '%s\n' "#!${JB}/usr/bin/lua5.5"
      tail -n +2 "${bindir}/${b}"
    } > "${bindir}/${b}.new"
    mv "${bindir}/${b}.new" "${bindir}/${b}"
    chmod 755 "${bindir}/${b}"
    mv "${bindir}/${b}" "${libexec}/${b}"
  done

  . "${ROOTDIR}/files/mayflower-exec.sh"
  for b in luarocks luarocks-admin; do
    mayflower_install_exec "${bindir}/${b}" \
      "${JB}/usr/bin/lua5.5" -- "${JB}/usr/libexec/luarocks/${b}"
  done
}
