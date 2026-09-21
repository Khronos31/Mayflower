#!/bin/sh
# Mayflower | Mac から node-sqlite3 を aarch64-apple-ios へクロスビルドする。
#
#   export MAYFLOWER=/path/to/Mayflower
#   export PATH=~/ios-tools:$PATH
#   $MAYFLOWER/tools/mac/node-sqlite3/build.sh
#
# 成果は ${SQLITE3_BUILD_DIR:-$HOME/node-sqlite3-ios}/dist/sqlite3-<ver>-aarch64-apple-ios.tar.xz。
# 端末では SQLITE3_DIST_DIR にその dist を渡して ./make.sh node-sqlite3。
#
# Node 本体と同じ ios-clang。N-API なのでヘッダは nodejs.org の
# node-v<ver>-headers.tar.gz（公式、アーキ非依存）。prebuild-install は
# darwin-arm64 を macOS と取るので使わない。
set -eu

SQLITE3_VERSION=5.1.7
NODE_VERSION=24.21.0
IOS_DEPLOYMENT_TARGET=16.0

MAYFLOWER="${MAYFLOWER:-}"
if [ -z "${MAYFLOWER}" ]; then
  MAYFLOWER="$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)"
fi
PATCHDIR="${MAYFLOWER}/packages/node-sqlite3/patches-host"
IOS_CLANG="${IOS_CLANG:-${HOME}/ios-tools/ios-clang}"
IOS_CLANGXX="${IOS_CLANGXX:-${HOME}/ios-tools/ios-clang++}"

BUILD_DIR="${SQLITE3_BUILD_DIR:-${HOME}/node-sqlite3-ios}"
SRC="${BUILD_DIR}/package"
DIST="${BUILD_DIR}/dist"
STAGE="${BUILD_DIR}/stage"
SQLITE_TGZ="${BUILD_DIR}/sqlite3-${SQLITE3_VERSION}.tgz"
HEADERS="${BUILD_DIR}/node-v${NODE_VERSION}"
HEADERS_TGZ="${BUILD_DIR}/node-v${NODE_VERSION}-headers.tar.gz"
HEADERS_URL="https://nodejs.org/download/release/v${NODE_VERSION}/node-v${NODE_VERSION}-headers.tar.gz"
NODE_BIN="${NODE_BIN:-${HOME}/node-ios/dist/node-${NODE_VERSION}-aarch64-apple-ios/bin/node}"

if [ ! -x "${IOS_CLANG}" ]; then
  echo "error: ${IOS_CLANG} が無い。tools/mac/README.md の ios-clang を置くこと" >&2
  exit 1
fi
xcode_ios_sdk="$(/usr/bin/xcrun --sdk iphoneos --show-sdk-path)"
if [ ! -d "${xcode_ios_sdk}" ]; then
  echo "error: Xcode の iPhoneOS SDK が無い: ${xcode_ios_sdk}" >&2
  exit 1
fi
export MAYFLOWER_IOS_SDK="${xcode_ios_sdk}"
echo "iOS SDK: ${MAYFLOWER_IOS_SDK}"

HOST_NODE="$(command -v node)"
HOST_NPM="$(command -v npm)"
[ -n "${HOST_NODE}" ] || { echo "error: host node が無い" >&2; exit 1; }
[ -n "${HOST_NPM}" ] || { echo "error: host npm が無い" >&2; exit 1; }

mkdir -p "${BUILD_DIR}" "${DIST}"
cd "${BUILD_DIR}"
export COPYFILE_DISABLE=1

if [ ! -f "${HEADERS_TGZ}" ]; then
  curl -fsSL -o "${HEADERS_TGZ}" "${HEADERS_URL}"
fi
if [ ! -f "${HEADERS}/include/node/node.h" ]; then
  rm -rf "${HEADERS}"
  mkdir -p "${HEADERS}"
  tar xf "${HEADERS_TGZ}" --strip-components=1 -C "${HEADERS}"
fi

if [ ! -f "${SQLITE_TGZ}" ]; then
  (cd "${BUILD_DIR}" && "${HOST_NPM}" pack --ignore-scripts "sqlite3@${SQLITE3_VERSION}")
fi

rm -rf "${SRC}"
tar xf "${SQLITE_TGZ}"
# npm pack は package/ に展開する
[ -f "${SRC}/package.json" ] || { echo "error: sqlite3 tarball の形が違う" >&2; exit 1; }

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
apply_host_patches

# 依存の JS だけ。install スクリプト（prebuild-install）は macOS の .node を取る。
(cd "${SRC}" && "${HOST_NPM}" install --omit=dev --ignore-scripts --no-audit --no-fund)

NODE_GYP="${SRC}/node_modules/node-gyp/bin/node-gyp.js"
if [ ! -f "${NODE_GYP}" ]; then
  NODE_GYP="$("${HOST_NPM}" root -g)/node-gyp/bin/node-gyp.js"
fi
if [ ! -f "${NODE_GYP}" ]; then
  NODE_GYP="$(dirname "$("${HOST_NPM}" root -g)")/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js"
fi
[ -f "${NODE_GYP}" ] || { echo "error: node-gyp が無い" >&2; exit 1; }

ar_bin="$(/usr/bin/xcrun -f ar)"
nm_bin="$(/usr/bin/xcrun -f nm)"
ranlib_bin="$(/usr/bin/xcrun -f ranlib)"

# IPHONEOS_DEPLOYMENT_TARGET / SDKROOT / MACOSX_DEPLOYMENT_TARGET は置かない
# （tools/mac/README.md）。ios-clang が -target と -isysroot を付ける。
export CC="${IOS_CLANG}"
export CXX="${IOS_CLANGXX}"
export AR="${ar_bin}"
export NM="${nm_bin}"
export RANLIB="${ranlib_bin}"
export LINK="${IOS_CLANGXX}"
export npm_config_nodedir="${HEADERS}"
export npm_config_arch=arm64
export npm_config_target_arch=arm64
export npm_config_build_from_source=true
unset MACOSX_DEPLOYMENT_TARGET IPHONEOS_DEPLOYMENT_TARGET SDKROOT || true

# gyp には darwin の -bundle を出させる。コンパイルは ios-clang が iOS にする。
# OS=ios にすると node-gyp が bundle フラグを落とす。
export GYP_DEFINES="target_arch=arm64 host_arch=arm64"

cd "${SRC}"
"${HOST_NODE}" "${NODE_GYP}" clean
set +e
env -u SDKROOT -u IPHONEOS_DEPLOYMENT_TARGET -u MACOSX_DEPLOYMENT_TARGET \
  "${HOST_NODE}" "${NODE_GYP}" rebuild --verbose --nodedir="${HEADERS}" --arch=arm64
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  echo "==> retry with -bundle_loader (undefined dynamic_lookup が iOS で落ちた場合)" >&2
  if [ ! -x "${NODE_BIN}" ]; then
    dist_tar="${HOME}/node-ios/dist/node-${NODE_VERSION}-aarch64-apple-ios.tar.xz"
    if [ -f "${dist_tar}" ]; then
      mkdir -p "${HOME}/node-ios/dist"
      tar xf "${dist_tar}" -C "${HOME}/node-ios/dist"
    fi
  fi
  [ -x "${NODE_BIN}" ] || { echo "error: NODE_BIN が無い: ${NODE_BIN}" >&2; exit 1; }
  export LDFLAGS="${LDFLAGS:-} -bundle_loader ${NODE_BIN}"
  env -u SDKROOT -u IPHONEOS_DEPLOYMENT_TARGET -u MACOSX_DEPLOYMENT_TARGET \
    "${HOST_NODE}" "${NODE_GYP}" rebuild --verbose --nodedir="${HEADERS}" --arch=arm64
fi

NODE_ADDON="${SRC}/build/Release/node_sqlite3.node"
[ -f "${NODE_ADDON}" ] || { echo "error: ${NODE_ADDON} が無い" >&2; exit 1; }

echo "==> vtool"
/usr/bin/vtool -show-build "${NODE_ADDON}" || true
/usr/bin/file "${NODE_ADDON}"

# macOS 向けになっていたら失敗。iOS の LC_BUILD_VERSION を要求する。
if /usr/bin/vtool -show-build "${NODE_ADDON}" 2>/dev/null | grep -qi macos; then
  echo "error: .node が macOS 向けになっている" >&2
  /usr/bin/vtool -show-build "${NODE_ADDON}" >&2
  exit 1
fi
if ! /usr/bin/vtool -show-build "${NODE_ADDON}" 2>/dev/null | grep -qi ios; then
  echo "error: .node に iOS の build version が無い" >&2
  /usr/bin/vtool -show-build "${NODE_ADDON}" >&2
  exit 1
fi

# 出荷ツリー。他 ABI の prebuild と build 中間物は捨て、Release の .node だけ残す。
rm -rf "${STAGE}"
mkdir -p "${STAGE}/sqlite3-${SQLITE3_VERSION}-aarch64-apple-ios"
stage_pkg="${STAGE}/sqlite3-${SQLITE3_VERSION}-aarch64-apple-ios"
# 実行時に要るのは JS と .node だけ。amalgamation の tarball は入れない。
cp -R "${SRC}/lib" "${SRC}/package.json" "${stage_pkg}/"
if [ -f "${SRC}/LICENSE" ]; then
  cp "${SRC}/LICENSE" "${stage_pkg}/"
elif [ -f "${SRC}/licence" ]; then
  cp "${SRC}/licence" "${stage_pkg}/"
fi
# bindings() は build/Release/node_sqlite3.node を探す
mkdir -p "${stage_pkg}/build/Release"
cp "${NODE_ADDON}" "${stage_pkg}/build/Release/node_sqlite3.node"
# node-addon-api / bindings は実行時に要る
mkdir -p "${stage_pkg}/node_modules"
for dep in bindings node-addon-api file-uri-to-path; do
  if [ -d "${SRC}/node_modules/${dep}" ]; then
    cp -R "${SRC}/node_modules/${dep}" "${stage_pkg}/node_modules/${dep}"
  fi
done
# bindings の依存を拾う
if [ -d "${SRC}/node_modules/file-uri-to-path" ]; then
  :
fi

# node_modules から .node / テスト / ドキュメントを削る
find "${stage_pkg}/node_modules" \( -name '*.node' -o -name '*.o' -o -name '*.a' \) -delete 2>/dev/null || true

out="${DIST}/sqlite3-${SQLITE3_VERSION}-aarch64-apple-ios.tar.xz"
rm -f "${out}"
tar -C "${STAGE}" -cJf "${out}" "sqlite3-${SQLITE3_VERSION}-aarch64-apple-ios"
echo "できあがり ${out}"
ls -lh "${out}"
