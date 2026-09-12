# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034  # 変数は ../../make.sh が読む/export する
#
# Mayflower | packages/lua/make.sh
#
# Lua 5.5.1 を rootless 脱獄 iOS 上でセルフビルドする。
# 上流 Makefile に ios ターゲットがある（LUA_USE_IOS。os.execute は
# system(3) を呼ばず常に失敗するスタブ）。共有ライブラリは上流が静的
# liblua.a しか出さないので、同じ .o から dylib を足す。
#
# Procursus は lua5.4 / liblua5.4-0 / liblua5.4-dev まで。5.5 は無いので
# 同名を避けなくてよい。版なしの lua は alternatives で 5.4 を指したまま。
#
#   liblua5.5-0    liblua5.5.0.dylib
#   lua5.5         lua5.5 / luac5.5
#   liblua5.5-dev  ヘッダ・liblua5.5.dylib・liblua5.5.a・lua5.5.pc

pkgname=lua
pkgver=5.5.1
pkgrel=1
srcname="lua-${pkgver}"
source="https://www.lua.org/ftp/lua-${pkgver}.tar.gz"
subpkgs=(lib lua dev)

COMMON_FLAGS="-target arm64-apple-ios16.0"

LIBLUA_O=(
  lapi.o lcode.o lctype.o ldebug.o ldo.o ldump.o lfunc.o lgc.o llex.o
  lmem.o lobject.o lopcodes.o lparser.o lstate.o lstring.o ltable.o ltm.o
  lundump.o lvm.o lzio.o
  lauxlib.o lbaselib.o lcorolib.o ldblib.o liolib.o lmathlib.o loadlib.o
  loslib.o lstrlib.o ltablib.o lutf8lib.o linit.o
)

prepare() {
  cd "${srcdir}" || return 1
}

build() {
  cd "${srcdir}" || return 1

  make ios \
    CC="${CC} -std=gnu99" \
    MYCFLAGS="${COMMON_FLAGS}" \
    MYLDFLAGS="-Wl,-rpath,${JB}/usr/lib"

  cd src || return 1
  # 上流は liblua.a だけ。同じオブジェクトから dylib を出す。
  "${CC}" -std=gnu99 -dynamiclib -o liblua5.5.0.dylib \
    "${LIBLUA_O[@]}" \
    ${COMMON_FLAGS} \
    -install_name @rpath/liblua5.5.0.dylib \
    -compatibility_version 5.5 -current_version 5.5.1 \
    -Wl,-rpath,${JB}/usr/lib -lm

  # lua は dylib へ。luac は luaU_dump など内部記号を使うので liblua.a のまま。
  "${CC}" -std=gnu99 -o lua ${COMMON_FLAGS} lua.o liblua5.5.0.dylib -lm \
    -Wl,-rpath,${JB}/usr/lib
}

check() {
  cd "${srcdir}/src" || return 1
  DYLD_LIBRARY_PATH="$(pwd)" ./lua -v
  DYLD_LIBRARY_PATH="$(pwd)" ./lua -e 'assert(_VERSION == "Lua 5.5"); print("ok", _VERSION)'
}

package_lib() {
  install -d "${pkgdir}${JB}/usr/lib"
  install -m755 "${srcdir}/src/liblua5.5.0.dylib" "${pkgdir}${JB}/usr/lib/"
}

package_lua() {
  install -d "${pkgdir}${JB}/usr/bin" "${pkgdir}${JB}/usr/share/man/man1"
  install -m755 "${srcdir}/src/lua" "${pkgdir}${JB}/usr/bin/lua5.5"
  install -m755 "${srcdir}/src/luac" "${pkgdir}${JB}/usr/bin/luac5.5"
  install -m644 "${srcdir}/doc/lua.1" "${pkgdir}${JB}/usr/share/man/man1/lua5.5.1"
  install -m644 "${srcdir}/doc/luac.1" "${pkgdir}${JB}/usr/share/man/man1/luac5.5.1"

  install -d "${pkgdir}${JB}/usr/share/licenses/lua5.5"
  # Lua は doc/readme.html に MIT 相当。COPYRIGHT はヘッダ。
  sed -n '/Copyright/,/SOFTWARE\./p' "${srcdir}/src/lua.h" \
    > "${pkgdir}${JB}/usr/share/licenses/lua5.5/COPYRIGHT"
}

package_dev() {
  local inc="${pkgdir}${JB}/usr/include/lua5.5"
  install -d "${inc}" "${pkgdir}${JB}/usr/lib/pkgconfig"
  install -m644 "${srcdir}/src/lua.h" "${inc}/"
  install -m644 "${srcdir}/src/luaconf.h" "${inc}/"
  install -m644 "${srcdir}/src/lualib.h" "${inc}/"
  install -m644 "${srcdir}/src/lauxlib.h" "${inc}/"
  install -m644 "${srcdir}/src/lua.hpp" "${inc}/"
  install -m644 "${srcdir}/src/liblua.a" "${pkgdir}${JB}/usr/lib/liblua5.5.a"
  ln -s liblua5.5.0.dylib "${pkgdir}${JB}/usr/lib/liblua5.5.dylib"

  cat > "${pkgdir}${JB}/usr/lib/pkgconfig/lua5.5.pc" <<EOF
prefix=${JB}/usr
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include/lua5.5

Name: Lua
Description: Lua 5.5 language engine
Version: ${pkgver}
Libs: -L\${libdir} -llua5.5
Cflags: -I\${includedir}
EOF
}
