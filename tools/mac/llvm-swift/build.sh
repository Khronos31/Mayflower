#!/bin/bash
# Mayflower | tools/mac/llvm-swift/build.sh
#
# Swift 6.1.1 + Clang/LLVM 19 を macOS 上で iphoneos/arm64 向けにクロスし、
# packages/llvm が読む dist tarball を出す。
#
# 完全な Procursus 互換ビルドではない。まずは「動く骨格」——ソース取得、
# native tblgen、ターゲット configure の骨。通るまで何度も直す前提。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SWIFT_VER="${SWIFT_VER:-6.1.1}"
LLVM_VER="${LLVM_VER:-19.1.4}"
IOS_MIN="${IOS_MIN:-16.0}"
WORKDIR="${WORKDIR:-$HOME/dev/toolchain-swift-6.1}"
SRC="${WORKDIR}/src"
BUILD="${WORKDIR}/build"
DIST="${WORKDIR}/dist"
PREFIX_IN_TAR="/var/jb/usr/lib/llvm-19"
TRIPLE="arm64-apple-ios${IOS_MIN}"
DIST_NAME="llvm-${LLVM_VER}-swift-${SWIFT_VER}-aarch64-apple-ios"

IPHONEOS_SDK="${IPHONEOS_SDK:-$(xcrun --sdk iphoneos --show-sdk-path)}"
MACOSX_SDK="${MACOSX_SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
HOST_CC="${HOST_CC:-$(xcrun --find clang)}"
HOST_CXX="${HOST_CXX:-$(xcrun --find clang++)}"

echo "==> WORKDIR=${WORKDIR}"
echo "==> iPhoneOS SDK=${IPHONEOS_SDK}"
mkdir -p "${SRC}" "${BUILD}" "${DIST}"

fetch() {
  local tag="swift-${SWIFT_VER}-RELEASE"
  cd "${SRC}"
  if [ ! -d llvm-project ]; then
    echo "==> clone apple/llvm-project @ ${tag}"
    git clone --depth 1 --branch "${tag}" \
      https://github.com/apple/llvm-project.git llvm-project
  fi
  if [ ! -d swift ]; then
    echo "==> clone swiftlang/swift @ ${tag}"
    git clone --depth 1 --branch "${tag}" \
      https://github.com/swiftlang/swift.git swift
  fi
  # cmark / swift-syntax は Swift ビルドが要求したら足す
}

build_native() {
  # tblgen 等ホストツール
  local n="${BUILD}/native"
  if [ -f "${n}/.done" ]; then
    echo "==> native tools already built"
    return 0
  fi
  mkdir -p "${n}"
  cd "${n}"
  cmake -G Ninja "${SRC}/llvm-project/llvm" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="${HOST_CC}" \
    -DCMAKE_CXX_COMPILER="${HOST_CXX}" \
    -DCMAKE_OSX_SYSROOT="${MACOSX_SDK}" \
    -DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DCLANG_INCLUDE_TESTS=OFF
  ninja -j "${CMAKE_BUILD_PARALLEL_LEVEL:-$(sysctl -n hw.ncpu)}" \
    clang-tblgen llvm-tblgen lld
  touch "${n}/.done"
}

configure_target() {
  local t="${BUILD}/ios"
  mkdir -p "${t}"
  cd "${t}"
  # ここは Procursus llvm.mk の縮小版。Swift 同梱は次段。
  # まず Clang/LLVM だけ通してから SWIFT_EXTERNAL を足す。
  cmake -G Ninja "${SRC}/llvm-project/llvm" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Darwin \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_SYSROOT="${IPHONEOS_SDK}" \
    -DCMAKE_C_COMPILER="${HOST_CC}" \
    -DCMAKE_CXX_COMPILER="${HOST_CXX}" \
    -DCMAKE_C_FLAGS="-target ${TRIPLE} -isysroot ${IPHONEOS_SDK}" \
    -DCMAKE_CXX_FLAGS="-target ${TRIPLE} -isysroot ${IPHONEOS_SDK}" \
    -DCMAKE_INSTALL_PREFIX="${PREFIX_IN_TAR}" \
    -DLLVM_HOST_TRIPLE="${TRIPLE}" \
    -DLLVM_DEFAULT_TARGET_TRIPLE="${TRIPLE}" \
    -DLLVM_TARGETS_TO_BUILD="AArch64" \
    -DLLVM_ENABLE_PROJECTS="clang;lld;lldb" \
    -DLLVM_TABLEGEN="${BUILD}/native/bin/llvm-tblgen" \
    -DCLANG_TABLEGEN="${BUILD}/native/bin/clang-tblgen" \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DCLANG_INCLUDE_TESTS=OFF \
    -DLLDB_USE_SYSTEM_DEBUGSERVER=OFF \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
  echo "==> configured target at ${t}"
  echo "    next: ninja -C ${t} && DESTDIR=${BUILD}/stage ninja -C ${t} install"
}

pack_dist() {
  local stage="${BUILD}/stage"
  local root="${stage}${PREFIX_IN_TAR}"
  [ -d "${root}" ] || {
    echo "pack_dist: ${root} が無い。先に install すること" >&2
    exit 1
  }
  mkdir -p "${DIST}"
  local out="${DIST}/${DIST_NAME}.tar.xz"
  local tmp="${BUILD}/pkg/${DIST_NAME}"
  rm -rf "${tmp}"
  mkdir -p "${tmp}"
  cp -a "${root}/." "${tmp}/"
  tar -C "${BUILD}/pkg" -cJf "${out}" "${DIST_NAME}"
  echo "==> wrote ${out}"
  ls -lh "${out}"
}

usage() {
  cat <<USAGE
Usage: $0 <fetch|native|configure|pack|all>

  fetch      Swift ${SWIFT_VER} タグのソースを WORKDIR へ
  native     ホスト用 tblgen など
  configure  iphoneos 向け CMake（Clang/LLVM 中心。Swift は後続）
  pack       DESTDIR install 済みツリーを dist tarball に
  all        fetch + native + configure（ビルド/install/pack は手で）

Env: WORKDIR SWIFT_VER LLVM_VER IOS_MIN IPHONEOS_SDK
USAGE
}

cmd="${1:-all}"
case "${cmd}" in
  fetch) fetch ;;
  native) fetch; build_native ;;
  configure) fetch; build_native; configure_target ;;
  pack) pack_dist ;;
  all) fetch; build_native; configure_target; echo "==> configure まで完了。ビルドは手動で ninja" ;;
  -h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
