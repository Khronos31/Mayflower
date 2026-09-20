#!/bin/sh
# Mayflower | Mac から mirakc-arib を aarch64-apple-ios へクロスビルドする。
#
#   export MAYFLOWER=/path/to/Mayflower
#   export PATH=~/ios-tools:$PATH
#   $MAYFLOWER/tools/mac/mirakc-arib/build.sh
#
# 成果は ${MIRAKC_ARIB_BUILD_DIR:-$HOME/mirakc-arib-ios}/dist/mirakc-arib-<ver>-aarch64-apple-ios.tar.xz。
# 端末では MIRAKC_ARIB_DIST_DIR にその dist を渡して ./make.sh mirakc-arib。
#
# ios-clang は Node と同じ。tsduck は uname=Darwin を macOS と取るので
# patches-host で iOS 向けに直す。aribb24 は CC/CXX を ios-clang にする。
set -eu

MIRAKC_ARIB_VERSION=0.9.1
IOS_DEPLOYMENT_TARGET=16.0

MAYFLOWER="${MAYFLOWER:-}"
if [ -z "${MAYFLOWER}" ]; then
  MAYFLOWER="$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)"
fi
PATCHDIR="${MAYFLOWER}/packages/mirakc-arib/patches-host"
IOS_CLANG="${IOS_CLANG:-${HOME}/ios-tools/ios-clang}"
IOS_CLANGXX="${IOS_CLANGXX:-${HOME}/ios-tools/ios-clang++}"

BUILD_DIR="${MIRAKC_ARIB_BUILD_DIR:-${HOME}/mirakc-arib-ios}"
SRC="${BUILD_DIR}/src"
BUILD="${BUILD_DIR}/build"
DIST="${BUILD_DIR}/dist"
STAGE="${BUILD_DIR}/stage"
NAME="mirakc-arib-${MIRAKC_ARIB_VERSION}-aarch64-apple-ios"
TOOLCHAIN="${BUILD_DIR}/ios.toolchain.cmake"

if [ ! -x "${IOS_CLANG}" ] || [ ! -x "${IOS_CLANGXX}" ]; then
  echo "error: ${IOS_CLANG} / ${IOS_CLANGXX} が無い。tools/mac/README.md の ios-clang を置くこと" >&2
  exit 1
fi
xcode_ios_sdk="$(/usr/bin/xcrun --sdk iphoneos --show-sdk-path)"
if [ ! -d "${xcode_ios_sdk}" ]; then
  echo "error: Xcode の iPhoneOS SDK が無い: ${xcode_ios_sdk}" >&2
  exit 1
fi
export MAYFLOWER_IOS_SDK="${xcode_ios_sdk}"
echo "iOS SDK: ${MAYFLOWER_IOS_SDK}"

for t in cmake ninja git patch autoconf automake; do
  command -v "$t" >/dev/null 2>&1 || {
    echo "error: $t が無い" >&2
    exit 1
  }
done

mkdir -p "${BUILD_DIR}" "${DIST}"
cd "${BUILD_DIR}"
export COPYFILE_DISABLE=1
# RapidJSON 等の古い cmake_minimum を cmake 4 が拒否する。
export CMAKE_POLICY_VERSION_MINIMUM=3.5

if [ ! -f "${SRC}/CMakeLists.txt" ]; then
  rm -rf "${SRC}"
  git clone --depth 1 --branch "${MIRAKC_ARIB_VERSION}" \
    https://github.com/mirakc/mirakc-arib.git "${SRC}"
fi

# 上流 CMakeLists へ iOS 向けの差分を当てる。再実行は idempotent。
if ! grep -q 'SPDLOG_FMT_EXTERNAL=OFF' "${SRC}/CMakeLists.txt"; then
  patch -p1 -d "${SRC}" < "${PATCHDIR}/0001-cmake-ios.patch"
fi
cp "${PATCHDIR}/0002-tsduck-ios.patch" "${SRC}/patches/tsduck-ios.patch"

cat > "${TOOLCHAIN}" <<EOF
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_PROCESSOR arm64)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET ${IOS_DEPLOYMENT_TARGET})
set(CMAKE_C_COMPILER "${IOS_CLANG}")
set(CMAKE_CXX_COMPILER "${IOS_CLANGXX}")
set(CMAKE_C_COMPILER_TARGET arm64-apple-ios${IOS_DEPLOYMENT_TARGET})
set(CMAKE_CXX_COMPILER_TARGET arm64-apple-ios${IOS_DEPLOYMENT_TARGET})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

# 1 回目: vendor だけ。2 回目: find_package が通ったあと mirakc-arib を生成。
cmake -G Ninja -S "${SRC}" -B "${BUILD}" \
  -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DMIRAKC_ARIB_TEST=OFF
cmake --build "${BUILD}" --target vendor
cmake -G Ninja -S "${SRC}" -B "${BUILD}" \
  -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DMIRAKC_ARIB_TEST=OFF
cmake --build "${BUILD}" --target mirakc-arib

BIN="${BUILD}/bin/mirakc-arib"
[ -x "${BIN}" ] || { echo "error: ${BIN} が無い" >&2; exit 1; }

rm -rf "${STAGE}"
mkdir -p "${STAGE}/${NAME}/bin"
cp "${BIN}" "${STAGE}/${NAME}/bin/mirakc-arib"
cp "${SRC}/LICENSE-MIT" "${SRC}/LICENSE-APACHE" "${SRC}/README.md" \
  "${STAGE}/${NAME}/"

rm -f "${DIST}/${NAME}.tar.xz"
# bsdtar は COPYFILE_DISABLE しても com.apple.provenance を残す。
tar --no-xattrs --no-mac-metadata -C "${STAGE}" -cJf "${DIST}/${NAME}.tar.xz" "${NAME}"
echo "できあがり: ${DIST}/${NAME}.tar.xz"
