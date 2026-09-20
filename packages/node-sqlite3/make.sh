# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/node-sqlite3/make.sh
#
# npm の sqlite3 5.1.7（N-API の node_sqlite3.node）を梱包する。
# Procursus の sqlite3 / libsqlite3-1 とは別物。EPGStation が require("sqlite3")
# する拡張で、コマンドも共有ライブラリも使わない。
#
# **端末では建てない。** prebuild-install は darwin-arm64 を macOS と取り、
# node-gyp は MACOSX_DEPLOYMENT_TARGET を焼く。Mac から ios-clang でクロスし、
# 出来た tarball をここへ渡す。建て方は tools/mac/node-sqlite3/build.sh。
#
# パッチは packages/node-sqlite3/patches-host/。母艦で当てるので
# applyPatch の対象にしない。
#
# 入れる先は node 実体の隣:
#   /var/jb/usr/lib/nodejs-24/node_modules/sqlite3
# PATH にコマンドは出さない（ラッパー不要）。

pkgname=node-sqlite3
pkgver=5.1.7
pkgrel=1
srcname=dist
source=""
export compress=xz

nodeseries=24
sqlite3_libdir() {
  echo "${JB}/usr/lib/nodejs-${nodeseries}/node_modules/sqlite3"
}

prepare() {
  : "${SQLITE3_DIST_DIR:?Mac で建てた dist tarball のあるディレクトリを渡すこと（tools/mac/node-sqlite3/build.sh）}"
  mkdir -p "${srcdir}"
  cd "${srcdir}" || return 1
  local t="sqlite3-${pkgver}-aarch64-apple-ios"
  if [ ! -d "${t}" ]; then
    [ -r "${SQLITE3_DIST_DIR}/${t}.tar.xz" ] || {
      echo "prepare: ${SQLITE3_DIST_DIR}/${t}.tar.xz が無い" >&2
      return 1
    }
    tar xf "${SQLITE3_DIST_DIR}/${t}.tar.xz"
  fi
}

build() {
  : # 母艦で建ててある
}

check() {
  cd "${srcdir}" || return 1
  local tree="sqlite3-${pkgver}-aarch64-apple-ios"
  local addon="${tree}/build/Release/node_sqlite3.node"
  local nodebin="${JB}/usr/lib/nodejs-${nodeseries}/node-bin"
  [ -f "${addon}" ] || { echo "check: ${addon} が無い" >&2; return 1; }
  [ -x "${nodebin}" ] || { echo "check: ${nodebin} が無い。nodejs-24 を入れること" >&2; return 1; }
  ldid -S"${ENTFILE}" "${addon}"
  # require("sqlite3") は NODE_PATH 上の sqlite3/ を見る。globalPaths は
  # node-bin が nodejs-24/ 直下にある都合で /usr/lib/lib/node になっており、
  # ここには入らない。
  ln -sfn "${tree}" sqlite3
  NODE_PATH="${PWD}" "${nodebin}" --jitless "${PROJECTROOT}/test/t.js"
}

package() {
  cd "${srcdir}" || return 1
  local tree="sqlite3-${pkgver}-aarch64-apple-ios"
  local dest
  dest="$(sqlite3_libdir)"

  install -d "${pkgdir}${dest}" \
    "${pkgdir}${JB}/usr/share/licenses/nodejs-sqlite3"

  cp -R "${tree}/." "${pkgdir}${dest}/"
  # 署名は tidy_resign でも掛かるが、.node はここで先に付ける
  ldid -S"${ENTFILE}" "${pkgdir}${dest}/build/Release/node_sqlite3.node"

  if [ -f "${tree}/LICENSE" ]; then
    install -m644 "${tree}/LICENSE" \
      "${pkgdir}${JB}/usr/share/licenses/nodejs-sqlite3/LICENSE"
  fi
}
