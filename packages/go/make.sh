# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034  # 変数は ../../make.sh が読む/export する
#
# Mayflower | packages/go/make.sh
#
# Go を rootless 脱獄 iOS 上でビルドする。
#
# **クロスビルドした bootstrap ツールチェインが要る。** 端末に入っている go
# （Procursus 版）は使えない: 出力を無署名のまま吐くため、make.bash の途中で
# 実行される中間バイナリが起動できない。用意の仕方は docs/go.md を見ること。
#
# 出来上がるのは Debian 流に分けた3つ:
#   golang-1.26-go   GOROOT 本体（bin・pkg・api・go.env・entitlements.plist）
#   golang-1.26-src  src ツリー
#   golang-default   /var/jb/usr/bin に置くラッパー（Procursus の golang-go を置換）
#
# **Procursus と同じパッケージ名は使えない。** あちらは
# /var/jb/etc/apt/preferences.d/procursus で `Package: *` を Pin-Priority 1001
# に固定しており、1001 は「降格してでもその版を入れる」を意味する。同名の
# golang-go 1.26.8-1 を出していたところ、apt-get -s upgrade が Procursus の
# 1.22.4 への降格を提案した（実測）。戻される先は出力を署名しない Go なので
# 端末では動かない。名前を変え、Provides: golang-go で golang メタパッケージの
# 依存を満たす形にする。

# 1.27 系は採らない。ios/arm64 で起動時に作業ディレクトリが実行ファイルの
# 場所へ変わる退行が入っており（golang/go#81465）、cmd/go が go.mod を
# 見つけられなくなる。
#
# **上流は直しつつある（2026-09-11 時点）。** CL 830864
# 「runtime: keep the working directory for non-bundled ios/arm64 binaries」が
# Code-Review +2・TryBot 緑で master に出ており、1.27 へのバックポートも
# golang/go#81469 としてマイルストーン **Go1.27.2** で起票済み。中身は
# 報告どおりで、`Info.plist` の有無を chdir の条件に戻し、パスの取得だけ
# CFBundleCopyBundleURL に残す形。**Go1.27.2 が出たらそこへ移る。**
pkgname=go
pkgver=1.26.8
pkgrel=3
srcname=go
source="https://go.dev/dl/go${pkgver}.src.tar.gz"
subpkgs=(go src bin)
export compress=xz

goseries=1.26

goroot_install() {
  echo "${JB}/usr/lib/go-${goseries}"
}

# 共通 entitlements.plist では Dopamine で go が SIGKILL する。
go_entfile() {
  echo "${PROJECTROOT}/entitlements-jit.plist"
}

prepare() {
  : "${GOROOT_BOOTSTRAP:?クロスビルドした bootstrap ツールチェインのパスを渡すこと}"
  if ! "${GOROOT_BOOTSTRAP}/bin/go" version >/dev/null 2>&1; then
    echo "prepare: ${GOROOT_BOOTSTRAP}/bin/go が動かない。" >&2
    echo "  darwin/arm64 としてクロスビルドし、フレームワークのパスを iOS 用に" >&2
    echo "  書き換えて ldid で署名したものが要る（docs/go.md 参照）。" >&2
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
  # リンカのパッチが読む。ビルド中の中間バイナリもこれで署名される。
  export GO_LDID_ENTITLEMENTS="$(go_entfile)"
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
  ldid -e hello | grep -q dynamic-codesigning
}

package_go() {
  cd "${srcdir}" || return 1
  local dest
  dest="${pkgdir}$(goroot_install)"
  local ent
  ent="$(go_entfile)"
  install -d "${dest}"
  cp -R bin pkg api go.env VERSION "${dest}/"
  # リンカのパッチはここを既定の entitlements として探す（go build 成果物も同 ents）。
  install -m644 "${ent}" "${dest}/entitlements.plist"
  local tool
  for tool in "${dest}/bin/go" "${dest}/bin/gofmt"; do
    ldid -S"${ent}" "${tool}" || return 1
  done
  if [ -d "${dest}/pkg/tool" ]; then
    find "${dest}/pkg/tool" -type f -perm -111 | while read -r tool; do
      ldid -S"${ent}" "${tool}" || return 1
    done
  fi
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

# PATH に置くのは symlink ではなく GOROOT を補うラッパー。
#
# go は GOROOT を「環境変数 → ビルド時の焼き込み値 → os.Executable からの
# 探索」の順に決めるが、iOS では **os.Executable が失敗する**ため3番目が
# 効かない。焼き込み値もビルドした場所を指すのでインストール後には無く、
# 素のままでは `'go' binary is trimmed and GOROOT is not set` で起動しない。
# 既に GOROOT が設定されていればそれを尊重する。
package_bin() {
  local dest="${pkgdir}${JB}/usr/bin"
  local goroot="${JB}/usr/lib/go-${goseries}"
  install -d "${dest}"

  local b
  for b in go gofmt; do
    mayflower_install_exec "${dest}/${b}" "${goroot}/bin/${b}" \
      "GOROOT=${goroot}"
  done
}
