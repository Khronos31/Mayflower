# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034  # 変数は ../../make.sh が読む/export する
#
# Mayflower | packages/rust/make.sh
#
# **これだけは端末で建てない。** rustc の bootstrap は LLVM を建てるので、RAM
# 1.93GB の iPhone 8 では成立しない。Mac から `host = ["aarch64-apple-ios"]` として
# 建て、その dist tarball をここへ渡して梱包する。Go の GOROOT_BOOTSTRAP と
# 同じ扱いで、母艦の事情を make.sh に持ち込まない。建て方は tools/mac/README.md。
#
# 当てるパッチは packages/rust/patches-host/ にある。**母艦で当てるので
# applyPatch の対象にしない**（そのための名前）。
#
# 出来上がるのは Debian 流に分けた4つ:
#   rustc-1.98      ツールチェイン本体（bin/rustc・librustc_driver・lib/rustlib）
#   rust-std-1.98   aarch64-apple-ios 向けの std
#   cargo-1.98      cargo
#   rust-default    /var/jb/usr/bin に置くラッパー
#
# Procursus に rustc も cargo も無いので、同名を避ける必要はない（bat / fd /
# dust / hyperfine のような Rust 製バイナリは配っているのに処理系が無い）。

pkgname=rust
pkgver=1.98.1
pkgrel=4
srcname=dist
source=""
subpkgs=(rustc std cargo default)
export compress=xz

rustseries=1.98
rust_install() {
  echo "${JB}/usr/lib/rust-${rustseries}"
}

prepare() {
  : "${RUST_DIST_DIR:?Mac で建てた dist tarball のあるディレクトリを渡すこと（tools/mac/README.md）}"
  mkdir -p "${srcdir}"
  cd "${srcdir}" || return 1
  local t
  for t in "rustc-${pkgver}-aarch64-apple-ios" \
           "rust-std-${pkgver}-aarch64-apple-ios" \
           "cargo-${pkgver}-aarch64-apple-ios"; do
    if [ ! -d "${t}" ]; then
      [ -r "${RUST_DIST_DIR}/${t}.tar.xz" ] || {
        echo "prepare: ${RUST_DIST_DIR}/${t}.tar.xz が無い" >&2
        return 1
      }
      tar xf "${RUST_DIST_DIR}/${t}.tar.xz"
    fi
  done
}

build() {
  : # 母艦で建ててある
}

# 端末の上で実際に動くかを見る。ここは端末なので本物を走らせられる。
check() {
  cd "${srcdir}" || return 1
  local r="${srcdir}/rustc-${pkgver}-aarch64-apple-ios/rustc"
  local c="${srcdir}/cargo-${pkgver}-aarch64-apple-ios/cargo"
  "${r}/bin/rustc" --version
  "${c}/bin/cargo" --version
}

package_rustc() {
  cd "${srcdir}" || return 1
  local dest
  dest="${pkgdir}$(rust_install)"
  install -d "${dest}"
  cp -R "rustc-${pkgver}-aarch64-apple-ios/rustc/." "${dest}/"

  # rust-installer の梱包用ファイル。インストール後には要らないうえ、各
  # コンポーネントが同じ名前で持っているのでファイル衝突になる。
  rm -f "${dest}/manifest.in"

  # std は別パッケージが持つので、本体からは外す
  rm -rf "${dest}/lib/rustlib/aarch64-apple-ios/lib"

  # リンカのパッチはここを既定の entitlements として探す（GOROOT と同じ流儀）。
  # 脱獄 prefix の外で走らせるバイナリには entitlements が要るので、付けて署名する。
  install -m644 "${ENTFILE}" "${dest}/lib/rustlib/entitlements.plist"

  # rust-objcopy は rustc の dist に入り、リンカパッチを通らない。未署名のまま
  # 梱包すると、cargo が release の strip に呼んだ瞬間 SIGKILL する（A11 で実測）。
  #
  # **署名の失敗は握りつぶさない。** ここは Mach-O しか置かれない場所なので、
  # ldid が失敗するのは本物の異常である。|| true で流すと、直したはずの
  # 「無署名のまま配られる」状態が黙って戻ってくる。
  local b
  for b in "${dest}/lib/rustlib/"*/bin/*; do
    [ -f "${b}" ] && [ -x "${b}" ] || continue
    ldid -S"${ENTFILE}" "${b}"
  done

  install -d "${pkgdir}${JB}/usr/share/licenses/rustc-${rustseries}"
  local l
  for l in "rustc-${pkgver}-aarch64-apple-ios"/LICENSE-* \
           "rustc-${pkgver}-aarch64-apple-ios"/COPYRIGHT; do
    [ -r "${l}" ] && install -m644 "${l}" \
      "${pkgdir}${JB}/usr/share/licenses/rustc-${rustseries}/$(basename "${l}")"
  done
}

package_std() {
  cd "${srcdir}" || return 1
  local dest
  dest="${pkgdir}$(rust_install)/lib/rustlib"
  install -d "${dest}"
  cp -R "rust-std-${pkgver}-aarch64-apple-ios/rust-std-aarch64-apple-ios/lib/rustlib/aarch64-apple-ios" \
     "${dest}/"

}

package_cargo() {
  cd "${srcdir}" || return 1
  local dest
  dest="${pkgdir}$(rust_install)"
  install -d "${dest}"
  cp -R "cargo-${pkgver}-aarch64-apple-ios/cargo/." "${dest}/"
  rm -f "${dest}/manifest.in"
  install -d "${pkgdir}${JB}/usr/share/licenses/cargo-${rustseries}"
  local l
  for l in "cargo-${pkgver}-aarch64-apple-ios"/LICENSE-*; do
    [ -r "${l}" ] && install -m644 "${l}" \
      "${pkgdir}${JB}/usr/share/licenses/cargo-${rustseries}/$(basename "${l}")"
  done
}

# PATH に置くのはラッパー。SDKROOT を補ってから本体を呼ぶ。
#
# **SDKROOT が無いと rustc が毎回警告を出す。** rustc は SDK の場所を
# （1）環境変数 SDKROOT（2）PATH の xcrun の順に探すが、端末に xcrun は無い。
# 見つからなくても警告だけでリンクは通る（端末の clang が既定の sysroot として
# 同じ SDK を持っているため）が、毎回出るので塞ぐ。
#
# rustc 自身の sysroot 探索は直せている必要が無い。iOS でも
# _NSGetExecutablePath は動くので、Go の GOROOT のような問題は起きない。
package_default() {
  local dest="${pkgdir}${JB}/usr/bin"
  local prefix
  prefix="$(rust_install)"
  install -d "${dest}"

  local b
  for b in rustc cargo; do
    mayflower_install_exec "${dest}/${b}" "${prefix}/bin/${b}" \
      "SDKROOT=${JB}/usr/share/SDKs/iPhoneOS.sdk"
  done
}
