pkgname=tapi
pkgver=2.0.0
pkgrel=1

# URL of source archive
source="https://opensource.apple.com/tarballs/tapi/tapi-1000.10.8.tar.gz"

ARCH="${ARCH-$(arch)}"
COMMON_FLAGS=""
staticlibs=y

prepare() {
  git clone --depth 1 -b swift-4.2.4-RELEASE https://github.com/apple/swift-llvm llvm
  git clone --depth 1 -b swift-4.2.4-RELEASE https://github.com/apple/swift-clang clang
  
  mkdir -p dest host
  mv tapi-1000.10.8 tapi
}

build() {
  cd host
  cmake -GNinja ../llvm \
    -C ../tapi/cmake/caches/apple-tapi.cmake \
    -DCMAKE_C_COMPILER=cc \
    -DCMAKE_CXX_COMPILER=c++
  ninja clang-tblgen llvm-tblgen
  cd ..

  cd dest
  cmake -GNinja ../llvm \
    -C ../tapi/cmake/caches/apple-tapi.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CROSSCOMPILING=True \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=10.0 \
    -DCMAKE_OSX_SYSROOT="$(xcrun -sdk iphoneos --show-sdk-path)" \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
    -DCMAKE_INSTALL_RPATH=/usr/local/lib \
    -DCMAKE_BUILD_WITH_INSTALL_NAME_DIR=ON \
    -DCMAKE_INSTALL_NAME_DIR=/usr/local/lib \
    -DLLVM_PARALLEL_COMPILE_JOBS="$(nproc)" \
    -DLLVM_TARGET_ARCH=arm64 \
    -DLLVM_DEFAULT_TARGET_TRIPLE=arm64-apple-ios \
    -DCLANG_TABLEGEN="${BUILDROOT}/host/bin/clang-tblgen" \
    -DLLVM_TABLEGEN="${BUILDROOT}/host/bin/llvm-tblgen" \
    -Wno-dev
  ninja distribution
}

package() {
  cd dest
  DESTDIR="${pkgdir}" ninja install-distribution
}
