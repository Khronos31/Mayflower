#!/var/jb/bin/bash
#
# Mayflower | make.sh
#
# 使い方: ./make.sh <パッケージ名>
#
# packages/<名前>/make.sh が定義する pkgname / pkgver / pkgrel / source と、
# prepare / build / check / package の各関数を読み込んで順に実行し、
# 最後に .deb を作る。
#
# シェバンに /var/jb を直書きしているのは、rootless では `/bin/bash` も
# `/usr/bin/env` も存在しないため。libiosexec を引いた実行ファイルから
# 呼ばれた場合だけ解決されるので、素の execve からは exec できない。

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 <package>" >&2
  exit 1
fi

ROOTDIR="$(cd "${0%/*}" && pwd)"
export ROOTDIR
export PROJECTROOT="${ROOTDIR}/packages/$1"
readonly PROJECTROOT

if [ ! -f "${PROJECTROOT}/make.sh" ]; then
  echo "$0: そんなパッケージは無い: $1" >&2
  echo "利用できるもの: $(cd "${ROOTDIR}/packages" && echo *)" >&2
  exit 1
fi

. "${ROOTDIR}/util/common.sh"

# パッケージ側が上書きする。ここで空配列にしておかないと、未定義のまま
# 参照したときに空文字列1要素の配列になり、分割しないパッケージで
# package_ という名前のない関数を呼んでしまう。
subpkgs=()

. "${PROJECTROOT}/make.sh"

export pkgname pkgver pkgrel source srcname

# 脱獄の接頭辞。rootless(palera1n / Dopamine 等の Procursus)は /var/jb 固定。
export JB="${JB:-/var/jb}"
export ARCH=arm64
export DEB_ARCH=iphoneos-arm64
export ENTFILE="${ROOTDIR}/entitlements.plist"

export BUILDROOT="${PROJECTROOT}/${ARCH}"
# 展開されたディレクトリ名が <name>-<ver> でない場合は、パッケージ側で
# srcname を定義する（Go の書庫は go/ に展開される、など）。
export srcdir="${BUILDROOT}/${srcname:-${pkgname}-${pkgver}}"
export pkgdir="${BUILDROOT}/build"

# $ROOTDIR/bin を PATH の先頭に置く。bin/make は GNU make に SHELL を与える
# ラッパーで、これが無いと autotools も cmake も /bin/sh を探して死ぬ。
# bin/cc と bin/c++ も同じ場所にあるので、ビルド中に cc を直接呼ぶ類も拾える。
export PATH="${ROOTDIR}/bin:${PATH}"

# autoconf の configure は SHELL=${CONFIG_SHELL-/bin/sh} を先頭で焼く。
# config.sub / config.guess の実行がここを通るため、指定しないと即死する。
export CONFIG_SHELL="${JB}/bin/sh"

export CC="${CC:-$(DEFAULT_CC)}"
export CXX="${CXX:-$(DEFAULT_CXX)}"
export AR="${AR:-llvm-ar}"
export RANLIB="${RANLIB:-llvm-ranlib}"

# Procursus の clang は素で SDK に合った LC_BUILD_VERSION を吐くため、
# -isysroot や -miphoneos-version-min を既定では足さない。上書きすると
# 実際の SDK とずれる。必要なパッケージだけ COMMON_FLAGS で与えること。
export CFLAGS="${CFLAGS} ${COMMON_FLAGS}"
export CXXFLAGS="${CXXFLAGS} ${COMMON_FLAGS}"

# -L は必須。iOS SDK の .tbd スタブは clang の既定の探索先にあり、そちらが
# 先に当たるため、Procursus が持っているものでも系統が system 側へ逃げる。
# 実測では -llzma がヘッダ 5.4.4 に対して実行時 5.0.5 の system を掴み、
# -lreadline は SDK の libreadline.tbd 経由で libedit になっていた。
#
# -rpath も必須。dyld は既定で /usr/lib と /usr/local/lib しか見ないので、
# Procursus の dylib を引いたバイナリは実行時に落ちる。Procursus 自身の
# 実行ファイルも一律に LC_RPATH /var/jb/usr/lib を持っている。
export LDFLAGS="-L${JB}/usr/lib -Wl,-rpath,${JB}/usr/lib ${LDFLAGS} ${COMMON_FLAGS}"
export CPPFLAGS="-I${JB}/usr/include ${CPPFLAGS} ${COMMON_FLAGS}"

# MAYFLOWER_RESUME=1 で clean / download / prepare / applyPatch を飛ばし、
# 既にあるビルドツリーで build から始める。移植中、次の壁を1つずつ潰すための
# 近道。完成したレシピの検証には使わないこと（素の状態から通るかが分からない）。
if [ "${MAYFLOWER_RESUME:-0}" = 1 ]; then
  echo "==> RESUME: 既存のビルドツリーを使う（clean/download/prepare/patch を飛ばす）"
  [ -d "${srcdir}" ] || { echo "$0: ${srcdir} が無い。最初は RESUME なしで回すこと" >&2; exit 1; }
else
  cd "${PROJECTROOT}"
  clean
  if [ -n "${source}" ]; then
    download
  fi

  cd "${BUILDROOT}"
  prepare

  cd "${PROJECTROOT}"
  applyPatch
fi

cd "${BUILDROOT}"
build

if declare -F check >/dev/null; then
  cd "${BUILDROOT}"
  check
fi

# subpkgs を定義してあれば、その数だけ package_<名前> を呼んで .deb を作る。
# control は deb/<名前>/DEBIAN/control を使う。定義が無ければ package() を
# 一度呼び、control は deb/DEBIAN/control を使う。
if [ "${#subpkgs[@]}" -gt 0 ]; then
  for sub in "${subpkgs[@]}"; do
    echo "==> パッケージ: ${sub}"
    pkgdir="${BUILDROOT}/pkg-${sub}"
    rm -rf "${pkgdir}"
    mkdir -p "${pkgdir}"
    cd "${BUILDROOT}"
    "package_${sub}"
    tidy
    makedeb "deb/${sub}"
  done
else
  cd "${BUILDROOT}"
  package
  tidy
  makedeb
fi

echo "==> できあがり:"
find "${BUILDROOT}" -maxdepth 1 -name '*.deb' -exec echo "    {}" \;
