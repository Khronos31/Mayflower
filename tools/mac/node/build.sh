#!/bin/sh
# Mayflower | Mac から Node.js を aarch64-apple-ios へクロスビルドする。
#
#   export MAYFLOWER=/path/to/Mayflower
#   export PATH=~/ios-tools:$PATH
#   export MAYFLOWER_IOS_SDK=~/ios-sdk/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
#   $MAYFLOWER/tools/mac/node/build.sh
#
# 成果は ${NODE_BUILD_DIR:-$HOME/node-ios}/dist/node-<ver>-aarch64-apple-ios.tar.xz。
# 端末では NODE_DIST_DIR にその dist を渡して ./make.sh node。
#
# ホスト用は macos-clang。iOS 用は ~/ios-tools/ios-clang。
# **Node だけ Xcode の iPhoneOS SDK を使う。** 端末 SDK 16.2 の libc++ には
# std::ranges が無く、ada / simdjson が落ちる。triple は arm64-apple-ios16.0
# のままなので、成果物の minos は 16。xcrun は /usr/bin の本物を見る。
set -eu

NODE_VERSION=24.21.0
NODE_SHA256=a6f54defb6fd7c84f41dba13d61e78e9b4e0961712cf61f29715c05f5ced94fc
IOS_DEPLOYMENT_TARGET=16.0

MAYFLOWER="${MAYFLOWER:-}"
if [ -z "${MAYFLOWER}" ]; then
  MAYFLOWER="$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)"
fi
PATCHDIR="${MAYFLOWER}/packages/node/patches-host"
HOSTCC="${MAYFLOWER}/tools/mac/node/macos-clang"
IOS_CLANG="${IOS_CLANG:-${HOME}/ios-tools/ios-clang}"
IOS_CLANGXX="${IOS_CLANGXX:-${HOME}/ios-tools/ios-clang++}"

BUILD_DIR="${NODE_BUILD_DIR:-${HOME}/node-ios}"
SRC="${BUILD_DIR}/node-v${NODE_VERSION}"
STAGE="${BUILD_DIR}/stage"
DIST="${BUILD_DIR}/dist"
TARBALL="${BUILD_DIR}/node-v${NODE_VERSION}.tar.xz"
URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}.tar.xz"

if [ ! -x "${IOS_CLANG}" ]; then
  echo "error: ${IOS_CLANG} が無い。tools/mac/README.md の ios-clang を置くこと" >&2
  exit 1
fi
# 端末 SDK ではなく Xcode の iPhoneOS SDK（C++20 ranges）。
xcode_ios_sdk="$(/usr/bin/xcrun --sdk iphoneos --show-sdk-path)"
if [ ! -d "${xcode_ios_sdk}" ]; then
  echo "error: Xcode の iPhoneOS SDK が無い: ${xcode_ios_sdk}" >&2
  exit 1
fi
export MAYFLOWER_IOS_SDK="${xcode_ios_sdk}"
echo "iOS SDK: ${MAYFLOWER_IOS_SDK}"

mkdir -p "${BUILD_DIR}" "${DIST}"
cd "${BUILD_DIR}"

if [ ! -f "${TARBALL}" ]; then
  curl -fsSL -o "${TARBALL}" "${URL}"
fi
got="$(shasum -a 256 "${TARBALL}" | awk '{print $1}')"
if [ "${got}" != "${NODE_SHA256}" ]; then
  echo "error: sha256 mismatch: ${got}" >&2
  exit 1
fi

if [ ! -d "${SRC}" ]; then
  tar xf "${TARBALL}"
fi

apply_host_patches() {
  local p
  for p in "${PATCHDIR}"/*.patch; do
    [ -e "$p" ] || continue
    if patch -d "${SRC}" -p1 --dry-run < "$p" >/dev/null; then
      echo "==> patch $(basename "$p")"
      patch -d "${SRC}" -p1 < "$p"
    elif patch -d "${SRC}" -p1 -R --dry-run < "$p" >/dev/null; then
      echo "==> already applied $(basename "$p")"
    else
      echo "error: patch does not apply: $p" >&2
      exit 1
    fi
  done
}

chmod +x "${HOSTCC}"
HOSTCXX="${BUILD_DIR}/macos-clang++"
ln -sf "${HOSTCC}" "${HOSTCXX}"

jobs="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"
# ホスト側は Xcode / CLT の macOS SDK。iOS 用は PATH の xcrun shim と ios-clang。
host_sdk="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
ar_bin="$(/usr/bin/xcrun -f ar)"
nm_bin="$(/usr/bin/xcrun -f nm)"
ranlib_bin="$(/usr/bin/xcrun -f ranlib)"

rm -rf "${STAGE}"
mkdir -p "${STAGE}"

cd "${SRC}"
make distclean >/dev/null 2>&1 || true

export CC_host="${HOSTCC}"
export CXX_host="${HOSTCXX}"
export CFLAGS_host="-isysroot ${host_sdk}"
export CXXFLAGS_host="-isysroot ${host_sdk} -std=gnu++20"
export LDFLAGS_host="-isysroot ${host_sdk} -framework CoreFoundation"
export CC_target="${IOS_CLANG}"
export CXX_target="${IOS_CLANGXX}"
export CFLAGS_target="${CFLAGS_target:-}"
export CXXFLAGS_target="${CXXFLAGS_target:--std=gnu++20}"
export AR_target="${ar_bin}"
export LD_target="${IOS_CLANGXX}"
export NM_target="${nm_bin}"
export RANLIB_target="${ranlib_bin}"
export GYP_DEFINES="OS=ios target_arch=arm64 v8_target_arch=arm64 iphoneos_deployment_target=${IOS_DEPLOYMENT_TARGET}"

# IPHONEOS_DEPLOYMENT_TARGET を環境に置かない（tools/mac/README.md）。
env -u SDKROOT -u IPHONEOS_DEPLOYMENT_TARGET \
  ./configure \
    --dest-os=ios \
    --dest-cpu=arm64 \
    --cross-compiling \
    --use_clang \
    --openssl-no-asm \
    --with-intl=small-icu \
    --prefix=/var/jb/usr

# configure が ares_config.h を darwin 用に書き戻すので、パッチはそのあと。
apply_host_patches

env -u SDKROOT -u IPHONEOS_DEPLOYMENT_TARGET \
  make -j"${jobs}" node

node_bin="${SRC}/out/Release/node"
if [ ! -x "${node_bin}" ]; then
  echo "error: out/Release/node が無い" >&2
  exit 1
fi

# make install は all に依存して openssl-cli 等まで建て直すので使わない。
OUT="${BUILD_DIR}/node-${NODE_VERSION}-aarch64-apple-ios"
rm -rf "${OUT}"
mkdir -p "${OUT}/bin" "${OUT}/lib/node_modules"
cp "${node_bin}" "${OUT}/bin/node"
if [ -d "${SRC}/deps/npm" ]; then
  cp -R "${SRC}/deps/npm" "${OUT}/lib/node_modules/npm"
fi
if [ -r "${SRC}/LICENSE" ]; then
  cp "${SRC}/LICENSE" "${OUT}/"
fi

tar -C "${BUILD_DIR}" -cJf "${DIST}/node-${NODE_VERSION}-aarch64-apple-ios.tar.xz" \
  "node-${NODE_VERSION}-aarch64-apple-ios"
echo "dist: ${DIST}/node-${NODE_VERSION}-aarch64-apple-ios.tar.xz"
