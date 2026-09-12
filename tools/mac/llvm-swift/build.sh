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
  mkdir -p "${SRC}"
  if [ ! -d llvm-project ]; then
    local lt="llvm-project-${tag}.tar.gz"
    echo "==> download apple/llvm-project @ ${tag}"
    curl -fL --retry 3 -o "${lt}" \
      "https://github.com/apple/llvm-project/archive/refs/tags/${tag}.tar.gz"
    tar xzf "${lt}"
    mv "llvm-project-${tag}" llvm-project
  fi
  if [ ! -d swift ]; then
    local st="swift-${tag}.tar.gz"
    echo "==> download swiftlang/swift @ ${tag}"
    curl -fL --retry 3 -o "${st}" \
      "https://github.com/swiftlang/swift/archive/refs/tags/${tag}.tar.gz"
    tar xzf "${st}"
    mv "swift-${tag}" swift
  fi
  # cmark / swift-syntax は Swift ビルドが要求したら足す
}

apply_patches() {
  local patchdir="${ROOT}/packages/llvm/patches-host"
  [ -d "${patchdir}" ] || return 0
  cd "${SRC}/llvm-project"
  local p
  for p in "${patchdir}"/*.patch; do
    [ -f "${p}" ] || continue
    # already applied?
    if patch -p1 --dry-run -N < "${p}" >/dev/null 2>&1; then
      echo "==> apply $(basename "${p}")"
      patch -p1 -N < "${p}"
    else
      echo "==> skip (already applied?) $(basename "${p}")"
    fi
  done
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
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_TABLEGEN="${BUILD}/native/bin/llvm-tblgen" \
    -DCLANG_TABLEGEN="${BUILD}/native/bin/clang-tblgen" \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DCLANG_INCLUDE_TESTS=OFF \
    -DLLDB_USE_SYSTEM_DEBUGSERVER=OFF \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
    -DLLVM_BUILD_LLVM_DYLIB=ON \
    -DLLVM_LINK_LLVM_DYLIB=ON \
    -DCLANG_LINK_CLANG_DYLIB=ON \
    -DLLVM_ENABLE_ZSTD=OFF \
    -DCMAKE_INSTALL_NAME_DIR=/var/jb/usr/lib/llvm-19/lib \
    -DCMAKE_INSTALL_RPATH=/var/jb/usr/lib/llvm-19/lib
  echo "==> configured target at ${t}"
  echo "    NOTE: DYLIB flags require a clean configure. If CMakeCache predates them:"
  echo "      rm -rf ${t}   # or at least CMakeCache.txt — then re-run configure"
  echo "    next: ninja -C ${t} … && ./tools/mac/llvm-swift/build.sh install"
}

# Run matching install-* ninja targets that exist; skip missing optional ones.
# Required targets fail hard so we never ship an incomplete Procursus replacement.
ninja_install_one() {
  local t="$1" target="$2" required="${3:-0}"
  if ninja -C "${t}" -t targets 2>/dev/null | awk '{print $1}' | grep -qx "${target}"; then
    echo "==> ninja ${target}"
    DESTDIR="${BUILD}/stage" ninja -C "${t}" "${target}"
    return 0
  fi
  if [ "${required}" = "1" ]; then
    echo "do_install: required ninja target missing: ${target}" >&2
    echo "  discover with: ninja -C ${t} -t targets | rg -i 'install.*(LLVM|clang|LTO|lld)'" >&2
    return 1
  fi
  echo "==> skip missing optional target: ${target}"
  return 0
}

do_install() {
  local t="${BUILD}/ios"
  local stage="${BUILD}/stage"
  [ -d "${t}" ] || { echo "do_install: ${t} が無い" >&2; exit 1; }
  if [ -f "${t}/CMakeCache.txt" ] && ! grep -q 'LLVM_BUILD_LLVM_DYLIB:BOOL=ON' "${t}/CMakeCache.txt" 2>/dev/null; then
    echo "do_install: ${t} was configured without LLVM_BUILD_LLVM_DYLIB=ON" >&2
    echo "  wipe and reconfigure: rm -rf ${t} && $0 configure" >&2
    exit 1
  fi
  rm -rf "${stage}"
  mkdir -p "${stage}"
  # Full `ninja install` pulls ORC/JIT/lldb for hours — explicit install-* only.
  echo "==> DESTDIR=${stage} selective ninja install-* (clang/lld/tools/dylibs/headers)"

  # Frontend + resources
  ninja_install_one "${t}" install-clang 1
  ninja_install_one "${t}" install-clang-resource-headers 1
  ninja_install_one "${t}" install-clang-headers 0

  # Linker
  ninja_install_one "${t}" install-lld 1

  # LLVM tools (names as produced by LLVM CMake)
  local tool
  for tool in \
    llvm-ar llvm-nm llvm-ranlib llvm-config dsymutil opt llc \
    llvm-objdump llvm-objcopy llvm-strip llvm-symbolizer llvm-cxxfilt \
    llvm-size llvm-strings llvm-install-name-tool llvm-lipo
  do
    ninja_install_one "${t}" "install-${tool}" 0
  done
  # Some trees expose unprefixed install targets for a few tools
  for tool in dsymutil opt llc; do
    ninja_install_one "${t}" "install-${tool}" 0
  done

  # Shared libs — discover spelling, prefer install-LLVM / install-clang-cpp / install-libclang / install-LTO
  if ninja -C "${t}" -t targets 2>/dev/null | awk '{print $1}' | grep -qx install-LLVM; then
    ninja_install_one "${t}" install-LLVM 1
  elif ninja -C "${t}" -t targets 2>/dev/null | awk '{print $1}' | grep -qx install-libLLVM; then
    ninja_install_one "${t}" install-libLLVM 1
  else
    echo "do_install: neither install-LLVM nor install-libLLVM exists — reconfigure with DYLIB?" >&2
    ninja -C "${t}" -t targets 2>/dev/null | rg -i 'install.*(LLVM|clang|LTO)' >&2 || true
    exit 1
  fi
  ninja_install_one "${t}" install-clang-cpp 0
  ninja_install_one "${t}" install-libclang-cpp 0
  ninja_install_one "${t}" install-libclang 0
  ninja_install_one "${t}" install-LTO 0
  ninja_install_one "${t}" install-libLTO 0

  # Headers
  ninja_install_one "${t}" install-llvm-headers 0
  ninja_install_one "${t}" install-llvm-c-headers 0

  # Require libLLVM in stage (Procursus replacement needs it)
  local libdir="${stage}${PREFIX_IN_TAR}/lib"
  if [ ! -e "${libdir}/libLLVM.dylib" ] && [ ! -e "${libdir}/libLLVM.19.dylib" ]; then
    echo "do_install: libLLVM.dylib missing under ${libdir}" >&2
    echo "  Available install targets (filter):" >&2
    ninja -C "${t}" -t targets 2>/dev/null | rg -i 'install.*(LLVM|clang|LTO|lld)' >&2 || true
    echo "  If CMake lacked DYLIB flags, wipe build/ios and re-run configure." >&2
    exit 1
  fi
  # Convenience symlink libLLVM-19.dylib if only libLLVM.dylib landed
  if [ -e "${libdir}/libLLVM.dylib" ] && [ ! -e "${libdir}/libLLVM-19.dylib" ]; then
    ln -sf libLLVM.dylib "${libdir}/libLLVM-19.dylib"
  fi

  local ent="${ROOT}/packages/llvm/files/entitlements.plist"
  if [ -f "${ent}" ]; then
    install -m644 "${ent}" "${stage}${PREFIX_IN_TAR}/entitlements.plist"
  fi
  echo "==> installed to ${stage}${PREFIX_IN_TAR}"
  du -sh "${stage}${PREFIX_IN_TAR}"
  ls -la "${libdir}"/libLLVM*.dylib "${libdir}"/libclang*.dylib "${libdir}"/libLTO.dylib 2>/dev/null || true
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
Usage: $0 <fetch|native|configure|install|pack|all>

  fetch      Swift ${SWIFT_VER} タグのソースを WORKDIR へ
  native     ホスト用 tblgen など
  configure  iphoneos 向け CMake（Clang/LLVM 中心。Swift は後続）
  install    DESTDIR=${BUILD}/stage へ ninja install（entitlements 同梱）
  pack       install 済みツリーを dist tarball に
  all        fetch + native + configure（ビルド/install/pack は手で）

Env: WORKDIR SWIFT_VER LLVM_VER IOS_MIN IPHONEOS_SDK
USAGE
}

cmd="${1:-all}"
case "${cmd}" in
  fetch) fetch ;;
  native) fetch; build_native ;;
  configure) fetch; apply_patches; build_native; configure_target ;;
  install) do_install ;;
  pack) pack_dist ;;
  all) fetch; apply_patches; build_native; configure_target; echo "==> configure まで完了。ビルドは手動で ninja" ;;
  -h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
