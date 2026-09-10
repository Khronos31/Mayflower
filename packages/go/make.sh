# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034  # 変数は ../../make.sh が読む/export する
#
# Mayflower | packages/go/make.sh
#
# Go を rootless 脱獄 iOS 上でビルドする。
#
# **クロスビルドした bootstrap ツールチェインが要る。** 端末に入っている go
# （Procursus 版）は使えない: 出力を無署名のまま吐くため、make.bash の途中で
# 実行される中間バイナリが起動できない。用意の仕方は README を見ること。
#
# 出来上がるのは Debian 流に分けた3つ:
#   golang-1.26-go   GOROOT 本体（bin・pkg・api・go.env・entitlements.plist）
#   golang-1.26-src  src ツリー
#   golang-go        /var/jb/usr/bin の symlink（Procursus の同名を置き換える）

# 1.27 系は採らない。ios/arm64 で起動時に作業ディレクトリが実行ファイルの
# 場所へ変わる退行が入っており（golang/go#81465）、cmd/go が go.mod を
# 見つけられなくなる。上流が直したら追随する。直らないまま 1.29 系まで来たら
# こちらでパッチを当てる。
pkgname=go
pkgver=1.26.8
pkgrel=1
srcname=go
source="https://go.dev/dl/go${pkgver}.src.tar.gz"
subpkgs=(go src bin)
export compress=xz

goseries=1.26

goroot_install() {
  echo "${JB}/usr/lib/go-${goseries}"
}

prepare() {
  : "${GOROOT_BOOTSTRAP:?クロスビルドした bootstrap ツールチェインのパスを渡すこと}"
  if ! "${GOROOT_BOOTSTRAP}/bin/go" version >/dev/null 2>&1; then
    echo "prepare: ${GOROOT_BOOTSTRAP}/bin/go が動かない。" >&2
    echo "  darwin/arm64 としてクロスビルドし、フレームワークのパスを iOS 用に" >&2
    echo "  書き換えて ldid で署名したものが要る（README 参照）。" >&2
    return 1
  fi
  cd "${srcdir}" || return 1
}

build() {
  cd "${srcdir}/src" || return 1

  export GOROOT_BOOTSTRAP
  export GOOS=ios GOARCH="${ARCH}"
  # bootstrap は darwin としてクロスビルドされているので runtime.GOOS が
  # darwin を返す。実機は iOS なので host を明示する（cmd/dist のパッチ）。
  export GOHOSTOS=ios GOHOSTARCH="${ARCH}"
  export CGO_ENABLED=1
  # CC は素の名前でなければならない。Go はこの値を zdefaultcc.go に焼き込む
  # ので、絶対パスのラッパーを渡すと利用者の環境に無いものを指してしまう。
  # 署名はリンカのパッチが行うため、ここにラッパーは要らない。
  export CC=clang CXX=clang++
  # Procursus の clang は rpath を自動では付けない。libiosexec を引く
  # バイナリが実行時に dyld で落ちるのを防ぐ。
  export CGO_LDFLAGS="-Wl,-rpath,${JB}/usr/lib"
  # リンカのパッチが読む。ビルド中の中間バイナリもこれで署名される。
  export GO_LDID_ENTITLEMENTS="${ENTFILE}"
  export GOTELEMETRY=off

  # -trimpath 相当を使わないこと。焼き込みの GOROOT と実行ファイルパスからの
  # 解決の両方が消え、GOROOT を環境変数で渡さないと go が起動しなくなる。
  bash make.bash -v --no-banner
}

check() {
  local goroot="${srcdir}"
  local work="${BUILDROOT}/check"
  rm -rf "${work}"
  mkdir -p "${work}"
  cd "${work}" || return 1

  cat > hello.go <<'EOF'
package main

import (
	"fmt"
	"os/exec"
)

func main() {
	fmt.Println("go hello")
	out, err := exec.Command("uname", "-m").Output()
	fmt.Printf("exec %q err=%v\n", string(out), err)
}
EOF
  cat > go.mod <<'EOF'
module hello

go 1.26
EOF
  # GOROOT を環境で渡さずに動くこと（焼き込みが効いているか）も見る。
  GOROOT="${goroot}" "${goroot}/bin/go" build -o hello ./
  ./hello
  ldid -e hello | grep -q platform-application
}

package_go() {
  cd "${srcdir}" || return 1
  local dest
  dest="${pkgdir}$(goroot_install)"
  install -d "${dest}"
  cp -R bin pkg api go.env VERSION "${dest}/"
  # リンカのパッチはここを既定の entitlements として探す。
  install -m644 "${ENTFILE}" "${dest}/entitlements.plist"
  install -d "${pkgdir}${JB}/usr/share/licenses/golang-${goseries}"
  install -m644 LICENSE "${pkgdir}${JB}/usr/share/licenses/golang-${goseries}/LICENSE"
}

package_src() {
  cd "${srcdir}" || return 1
  local dest
  dest="${pkgdir}$(goroot_install)"
  install -d "${dest}"
  cp -R src "${dest}/"
  find "${dest}/src" -name '*.orig' -delete
}

package_bin() {
  local dest="${pkgdir}${JB}/usr/bin"
  install -d "${dest}"
  ln -s "../lib/go-${goseries}/bin/go" "${dest}/go"
  ln -s "../lib/go-${goseries}/bin/gofmt" "${dest}/gofmt"
}
