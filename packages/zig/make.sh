# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034  # 変数は ../../make.sh が読む/export する
#
# Mayflower | packages/zig/make.sh
#
# Zig 0.16.0 を rootless 脱獄 iOS 向けに梱包する。
#
# **端末で LLVM 付き Zig をブートストラップしない。** iPhone 8 の RAM では
# 成立しない（Rust と同じ理由）。母艦（Mac）で得た配布物を ZIG_DIST_DIR に
# 渡して deb 化する。経路の候補と現状の可否は docs/zig.md を見ること。
#
# 製品化の範囲:
#   - zig build / zig build-exe が aarch64-ios 向けに動くこと
#   - zig cc をシステム CC には据えない
#
# Procursus に zig は無いので、当面パッケージ名は zig のまま。将来衝突したら
# zig-0.16 + zig-default に分割する。

pkgname=zig
pkgver=0.16.0
pkgrel=1
srcname=dist
source=""
export compress=xz

zig_install() {
  echo "${JB}/usr/lib/zig-${pkgver}"
}

prepare() {
  : "${ZIG_DIST_DIR:?Mac で用意した Zig 配布ディレクトリを渡すこと（docs/zig.md）}"
  mkdir -p "${srcdir}"
  cd "${srcdir}" || return 1

  # 期待するレイアウト（どちらか）:
  #   1) 公式 tarball 展開形: zig-aarch64-*/zig + lib/
  #   2) 交叉ビルド成果物: zig + lib/ （prefix 相当）
  if [ -x "${ZIG_DIST_DIR}/zig" ] && [ -d "${ZIG_DIST_DIR}/lib" ]; then
    cp -R "${ZIG_DIST_DIR}/zig" "${ZIG_DIST_DIR}/lib" .
    [ -r "${ZIG_DIST_DIR}/LICENSE" ] && cp "${ZIG_DIST_DIR}/LICENSE" .
    [ -d "${ZIG_DIST_DIR}/doc" ] && cp -R "${ZIG_DIST_DIR}/doc" .
    return 0
  fi

  local tarball
  tarball="$(echo "${ZIG_DIST_DIR}"/zig-*-0.16.0.tar.xz "${ZIG_DIST_DIR}"/zig-*.tar.xz 2>/dev/null | awk 'NF{print; exit}')"
  if [ -n "${tarball}" ] && [ -r "${tarball}" ]; then
    tar xf "${tarball}"
    local top
    top="$(find . -maxdepth 1 -type d -name 'zig-*' | head -1)"
    [ -n "${top}" ] || { echo "prepare: tarball 内に zig-* が無い" >&2; return 1; }
    mv "${top}/zig" "${top}/lib" .
    [ -r "${top}/LICENSE" ] && mv "${top}/LICENSE" .
    [ -d "${top}/doc" ] && mv "${top}/doc" .
    rm -rf "${top}"
    return 0
  fi

  echo "prepare: ${ZIG_DIST_DIR} に zig + lib/ も tarball も無い" >&2
  return 1
}

build() {
  : # 母艦で建ててある / 公式バイナリを使う
}

check() {
  cd "${srcdir}" || return 1
  [ -x ./zig ] || { echo "check: zig が無い" >&2; return 1; }

  # 署名が無いと端末では即 SIGKILL。梱包前に必ず当てる。
  ldid -S"${ENTFILE}" ./zig

  # 軽量スモークのみ。ip8 での on-device build-exe は jetsam/OOM しやすい
  # （docs/zig.md）。Rust の check と同様、version 系で止める。
  ./zig version
  ./zig targets >/dev/null
}

package() {
  cd "${srcdir}" || return 1
  local dest
  dest="${pkgdir}$(zig_install)"
  install -d "${dest}" "${pkgdir}${JB}/usr/bin" \
             "${pkgdir}${JB}/usr/share/licenses/zig"

  cp -R lib "${dest}/"
  install -m755 zig "${dest}/zig"
  [ -d doc ] && cp -R doc "${dest}/"
  [ -r LICENSE ] && install -m644 LICENSE "${pkgdir}${JB}/usr/share/licenses/zig/LICENSE"

  # PATH 上の zig は lib/ を相対探索する（../lib または同階層 lib/）。
  # 本体を lib/zig-0.16.0/zig に置き、bin からは相対 symlink。
  ln -s "../lib/zig-${pkgver}/zig" "${pkgdir}${JB}/usr/bin/zig"

  # 出力署名用の既定 entitlements（Go/Rust と同位置感覚）。
  install -m644 "${ENTFILE}" "${dest}/entitlements.plist"

  find "${pkgdir}" -type d -exec chmod 755 {} +
  chmod 755 "${dest}/zig"
}
