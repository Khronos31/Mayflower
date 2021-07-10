#!/usr/bin/env bash

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 <package>" >&2
  exit 1
fi

export ROOTDIR="$(cd "${0%/*}"&&pwd)"
export PROJECTROOT="${ROOTDIR}/packages/$1"
readonly PROJECTROOT

. "${ROOTDIR}/util/common.sh"

. "${PROJECTROOT}/make.sh"

export pkgname
export source
export ARCH=arm64

export BUILDROOT="${PROJECTROOT}/${ARCH}"
export pkgdir="${BUILDROOT}/build"

export CC="${CC:-$(DEFAULT_CC)}"
export CXX="${CXX:-$(DEFAULT_CXX)}"
export AR="${AR:-llvm-ar}"
export RANLIB="${RANLIB:-llvm-ranlib}"

export COMMON_FLAGS="${COMMON_FLAGS--isysroot /usr/share/SDKs/iPhoneOS.sdk -miphoneos-version-min=11.0 -arch ${ARCH}}"
export CFLAGS="${CFLAGS} ${COMMON_FLAGS}"
export CXXFLAGS="${CXXFLAGS} ${COMMON_FLAGS}"
export CPPFLAGS="${CPPFLAGS} ${COMMON_FLAGS}"
export LDFLAGS="${LDFLAGS} ${COMMON_FLAGS}"

cd "${PROJECTROOT}"
clean
if [ "x${source}" != "x" ]; then
  download
fi

cd "${BUILDROOT}"
prepare

cd "${PROJECTROOT}"
applyPatch

cd "${BUILDROOT}"
build

cd "${BUILDROOT}"
package
tidy

makedeb
