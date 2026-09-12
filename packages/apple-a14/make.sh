# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/apple-a14/make.sh
#
# 中身の無いゲート。A14（ARMv8.5-A）未満の端末では apt / Sileo が拒否する。
# Cydia の仮想パッケージ cy+model.* の版は hw.machine の「13,1」を「13.1」に
# したもの（iPhone 8 = iPhone10,1 → cy+model.iphone 10.1）。
# iPhone13,1 = iPhone 12 mini（A14）、iPad13,1 = iPad Air（第4世代、A14）。
#
# Claude Code はこのパッケージに Depends する。

pkgname=apple-a14
pkgver=1.0
pkgrel=1
source=""
srcname="apple-a14-${pkgver}"

prepare() {
  mkdir -p "${srcdir}"
}

build() {
  :
}

package() {
  install -d "${pkgdir}${JB}/usr/share/doc/apple-a14"
  cat > "${pkgdir}${JB}/usr/share/doc/apple-a14/README" <<'EOF'
Virtual package. Installable only on A14 / ARMv8.5-A or newer
(iPhone13,1 / iPad13,1 or later). Used as a dependency gate for
packages that ship darwin-arm64 binaries with v8.5 instructions.
EOF
}
