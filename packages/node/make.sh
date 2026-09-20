# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034  # 変数は ../../make.sh が読む/export する
#
# Mayflower | packages/node/make.sh
#
# **これだけは端末で建てない。** Node の bootstrap はホスト用 V8 を建てるので、
# RAM 1.93GB の iPhone 8 では成立しない。Mac から `--dest-os=ios` でクロスし、
# その tarball をここへ渡して梱包する。Rust と同じ扱いで、母艦の事情は
# make.sh に持ち込まない。建て方は tools/mac/node/build.sh。
#
# 当てるパッチは packages/node/patches-host/ にある。**母艦で当てるので
# applyPatch の対象にしない**（そのための名前）。
#
# 出来上がるのは2つ:
#   nodejs-24     版付きの node-24 / npm-24 / npx-24 と実体
#   node-default  /var/jb/usr/bin の node / npm / npx
#                 Provides: nodejs, npm。Conflicts/Replaces: npm
#                 （python3-default と同じ。Procursus の npm 8.1.1 を置換）
#
# ios-ports の `nodejs-ios24` とは名前を分け、あちらへの Conflicts は付けない。

pkgname=node
pkgver=24.21.0
pkgrel=2
srcname=dist
source=""
subpkgs=(nodejs default)
export compress=xz

nodeseries=24
node_libdir() {
  echo "${JB}/usr/lib/nodejs-${nodeseries}"
}

prepare() {
  : "${NODE_DIST_DIR:?Mac で建てた dist tarball のあるディレクトリを渡すこと（tools/mac/node/build.sh）}"
  mkdir -p "${srcdir}"
  cd "${srcdir}" || return 1
  local t="node-${pkgver}-aarch64-apple-ios"
  if [ ! -d "${t}" ]; then
    [ -r "${NODE_DIST_DIR}/${t}.tar.xz" ] || {
      echo "prepare: ${NODE_DIST_DIR}/${t}.tar.xz が無い" >&2
      return 1
    }
    tar xf "${NODE_DIST_DIR}/${t}.tar.xz"
  fi
}

build() {
  : # 母艦で建ててある
}

check() {
  cd "${srcdir}" || return 1
  local bin="node-${pkgver}-aarch64-apple-ios/bin/node"
  # 母艦では未署名。ここで entitlements を付けて --version だけ見る。
  ldid -S"${PROJECTROOT}/files/entitlements.plist" "${bin}"
  "${bin}" --jitless --version
}

package_nodejs() {
  cd "${srcdir}" || return 1
  local tree="node-${pkgver}-aarch64-apple-ios"
  local lib
  lib="$(node_libdir)"

  install -d "${pkgdir}${lib}" \
    "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/nodejs-${nodeseries}" \
    "${pkgdir}${JB}/usr/share/licenses/nodejs-${nodeseries}"

  install -m755 "${tree}/bin/node" "${pkgdir}${lib}/node-bin"
  mayflower_install_node "${pkgdir}${JB}/usr/bin/node-${nodeseries}" \
    "${lib}/node-bin" "${JB}/usr"
  install -m644 "${PROJECTROOT}/files/entitlements.plist" \
    "${pkgdir}${lib}/entitlements.plist"
  install -m644 "${PROJECTROOT}/files/smoke.js" \
    "${pkgdir}${JB}/usr/share/nodejs-${nodeseries}/smoke.js"

  # 端末の ldid で、JIT 用 entitlements を付ける。母艦では署名しない。
  ldid -S"${pkgdir}${lib}/entitlements.plist" "${pkgdir}${lib}/node-bin"

  if [ -d "${tree}/lib/node_modules" ]; then
    cp -R "${tree}/lib/node_modules" "${pkgdir}${lib}/"
  fi
  if [ -d "${tree}/include" ]; then
    cp -R "${tree}/include" "${pkgdir}${lib}/"
  fi
  if [ -d "${tree}/share" ]; then
    cp -R "${tree}/share" "${pkgdir}${lib}/"
  fi

  # npm / npx は env node を見に行くので、版付きラッパー経由にする。
  mayflower_install_exec "${pkgdir}${JB}/usr/bin/npm-${nodeseries}" \
    "${JB}/usr/bin/node-${nodeseries}" -- "${lib}/node_modules/npm/bin/npm-cli.js"
  mayflower_install_exec "${pkgdir}${JB}/usr/bin/npx-${nodeseries}" \
    "${JB}/usr/bin/node-${nodeseries}" -- "${lib}/node_modules/npm/bin/npx-cli.js"

  local l
  for l in "${tree}"/LICENSE "${tree}"/license; do
    if [ -r "${l}" ]; then
      install -m644 "${l}" \
        "${pkgdir}${JB}/usr/share/licenses/nodejs-${nodeseries}/$(basename "${l}")"
    fi
  done
}

package_default() {
  local dest="${pkgdir}${JB}/usr/bin"
  install -d "${dest}"
  ln -s "node-${nodeseries}" "${dest}/node"
  ln -s "npm-${nodeseries}" "${dest}/npm"
  ln -s "npx-${nodeseries}" "${dest}/npx"
}
