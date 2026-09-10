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

export CC="${CC:-$(DEFAULT_CC)}"
export CXX="${CXX:-$(DEFAULT_CXX)}"
export AR="${AR:-llvm-ar}"
export RANLIB="${RANLIB:-llvm-ranlib}"

# Procursus の clang は素で SDK に合った LC_BUILD_VERSION を吐くため、
# -isysroot や -miphoneos-version-min を既定では足さない。上書きすると
# 実際の SDK とずれる。必要なパッケージだけ COMMON_FLAGS で与えること。
export CFLAGS="${CFLAGS} ${COMMON_FLAGS}"
export CXXFLAGS="${CXXFLAGS} ${COMMON_FLAGS}"
export CPPFLAGS="${CPPFLAGS} ${COMMON_FLAGS}"
export LDFLAGS="${LDFLAGS} ${COMMON_FLAGS}"

cd "${PROJECTROOT}"
clean
if [ -n "${source}" ]; then
  download
fi

cd "${BUILDROOT}"
prepare

cd "${PROJECTROOT}"
applyPatch

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
