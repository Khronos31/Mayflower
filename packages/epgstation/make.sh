# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/epgstation/make.sh
#
# EPGStation 2.10.0。JS のコンパイルは Mac（tools/mac/epgstation/build.sh）。
# native の sqlite3 は同梱せず、nodejs-sqlite3 へシンボリックリンクする。
#
# PATH の epgstation は Mach-O（node-24 経由）。shebang は Dopamine で EPERM。

pkgname=epgstation
pkgver=2.10.0
pkgrel=1
srcname=dist
source=""
export compress=xz

epg_libdir() {
  echo "${JB}/usr/lib/epgstation"
}

epg_vardir() {
  echo "${JB}/var/lib/epgstation"
}

prepare() {
  : "${EPGSTATION_DIST_DIR:?Mac で建てた dist tarball のあるディレクトリを渡すこと（tools/mac/epgstation/build.sh）}"
  mkdir -p "${srcdir}"
  cd "${srcdir}" || return 1
  local t="epgstation-${pkgver}-aarch64-apple-ios"
  if [ ! -d "${t}" ]; then
    [ -r "${EPGSTATION_DIST_DIR}/${t}.tar.xz" ] || {
      echo "prepare: ${EPGSTATION_DIST_DIR}/${t}.tar.xz が無い" >&2
      return 1
    }
    tar xf "${EPGSTATION_DIST_DIR}/${t}.tar.xz"
  fi
}

build() {
  : # 母艦で建ててある
}

check() {
  cd "${srcdir}" || return 1
  local tree="epgstation-${pkgver}-aarch64-apple-ios"
  local nodebin="${JB}/usr/lib/nodejs-24/node-bin"
  [ -f "${tree}/dist/index.js" ] || { echo "check: dist/index.js が無い" >&2; return 1; }
  [ -f "${tree}/client/dist/index.html" ] || { echo "check: client/dist/index.html が無い" >&2; return 1; }
  [ -x "${nodebin}" ] || { echo "check: ${nodebin} が無い。nodejs-24 を入れること" >&2; return 1; }
  [ -d "${JB}/usr/lib/nodejs-24/node_modules/sqlite3" ] || {
    echo "check: nodejs-sqlite3 が無い" >&2
    return 1
  }
  "${nodebin}" --jitless --check "${tree}/dist/index.js"
}

package() {
  cd "${srcdir}" || return 1
  local tree="epgstation-${pkgver}-aarch64-apple-ios"
  local dest var
  dest="$(epg_libdir)"
  var="$(epg_vardir)"

  install -d "${pkgdir}${dest}" \
    "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/licenses/epgstation" \
    "${pkgdir}${var}/data" \
    "${pkgdir}${var}/recorded" \
    "${pkgdir}${var}/logs" \
    "${pkgdir}${var}/thumbnail" \
    "${pkgdir}${var}/drop"

  cp -R "${tree}/." "${pkgdir}${dest}/"

  # 書き込みは var。ROOT 直下の data/recorded/logs/thumbnail/drop を向ける。
  rm -rf "${pkgdir}${dest}/data" \
    "${pkgdir}${dest}/recorded" \
    "${pkgdir}${dest}/logs" \
    "${pkgdir}${dest}/thumbnail" \
    "${pkgdir}${dest}/drop"
  ln -s "${var}/data" "${pkgdir}${dest}/data"
  ln -s "${var}/recorded" "${pkgdir}${dest}/recorded"
  ln -s "${var}/logs" "${pkgdir}${dest}/logs"
  ln -s "${var}/thumbnail" "${pkgdir}${dest}/thumbnail"
  ln -s "${var}/drop" "${pkgdir}${dest}/drop"

  rm -rf "${pkgdir}${dest}/node_modules/sqlite3"
  ln -s "${JB}/usr/lib/nodejs-24/node_modules/sqlite3" \
    "${pkgdir}${dest}/node_modules/sqlite3"

  # 上流テンプレのパスを rootless 向けに直したものを同梱する。
  # ライブの config.yml は postinst が var へ初回コピーし、ここはリンク。
  if [ -f "${pkgdir}${dest}/config/config.yml.template" ]; then
    sed -e 's|http+unix://%2Fvar%2Frun%2Fmirakurun.sock/|http://127.0.0.1:40772/|' \
        -e 's|/usr/local/bin/ffmpeg|/var/jb/usr/bin/ffmpeg|' \
        -e 's|/usr/local/bin/ffprobe|/var/jb/usr/bin/ffprobe|' \
        "${pkgdir}${dest}/config/config.yml.template" \
      > "${pkgdir}${dest}/config/config.yml.template.mayflower"
    mv "${pkgdir}${dest}/config/config.yml.template.mayflower" \
      "${pkgdir}${dest}/config/config.yml.template"
  fi
  rm -f "${pkgdir}${dest}/config/config.yml"
  ln -s "${var}/config.yml" "${pkgdir}${dest}/config/config.yml"

  # 子プロセスは spawn(process.argv[0], [ServiceExecutor.js])。
  # index.js を EXTRA_ARGV に焼くと子も operator になるので、専用ラッパにする。
  mayflower_wrapper_compile "${pkgdir}${JB}/usr/bin/epgstation" \
    "${PROJECTROOT}/files/mayflower-epgstation.c" \
    -DNODE_BIN="\"${JB}/usr/lib/nodejs-24/node-bin\"" \
    -DINDEX_JS="\"${dest}/dist/index.js\"" \
    -DROOT="\"${dest}\""

  if [ -f "${tree}/LICENSE" ]; then
    install -m644 "${tree}/LICENSE" \
      "${pkgdir}${JB}/usr/share/licenses/epgstation/LICENSE"
  fi
}
