pkgname=llvm
pkgver=10.0.0
pkgrel=1

# URL of source archive
source="https://github.com/llvm/llvm-project/releases/download/llvmorg-${pkgver}/${pkgname}-${pkgver}.src.tar.xz"

ARCH="${ARCH-$(arch)}"
COMMON_FLAGS=""
staticlibs=y

build() {
  cd "${pkgname}-${pkgver}.src"
  mkdir build
  cd build

  local SDK="$(xcrun -sdk iphoneos --show-sdk-path)"

  cmake .. \
    -DCMAKE_CROSSCOMPILING=True \
    -DCMAKE_INSTALL_MESSAGE=LAZY \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=10.0 \
    -DCMAKE_OSX_SYSROOT="${SDK}" \
    -DCMAKE_C_FLAGS_RELEASE="-DNDEBUG" \
    -DCMAKE_CXX_FLAGS_RELEASE="-DNDEBUG" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_FIND_FRAMEWORK=LAST \
    -DLLVM_ENABLE_ASSERTIONS=OFF \
    -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="" \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_DOCS=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_ENABLE_TERMINFO=OFF \
    -DLLVM_ENABLE_BINDINGS=OFF \
    -DLLVM_ENABLE_Z3_SOLVER=OFF \
    -DLLVM_ENABLE_EH=ON \
    -DLLVM_ENABLE_FFI=ON \
    -DLLVM_ENABLE_LIBCXX=ON \
    -DLLVM_ENABLE_RTTI=ON \
    -DLLVM_PARALLEL_COMPILE_JOBS="$(nproc)" \
    -DLLVM_TARGET_ARCH=aarch64 \
    -DLLVM_DEFAULT_TARGET_TRIPLE=aarch64-apple-ios \
    -DLLVM_VERSION_SUFFIX="" \
    -DLLVM_LINK_LLVM_DYLIB=ON \
    -DLLVM_BUILD_LLVM_C_DYLIB=ON \
    -DLLVM_INSTALL_UTILS=ON \
    -DLLVM_INSTALL_BINUTILS_SYMLINKS=ON \
    -DLLVM_INSTALL_CCTOOLS_SYMLINKS=ON \
    -DLLVM_OPTIMIZED_TABLEGEN=ON \
    -DLLVM_TARGETS_TO_BUILD=all \
    -DLLVM_TABLEGEN=/usr/local/opt/llvm/bin/llvm-tblgen \
    -DFFI_INCLUDE_DIR="${PROJECTROOT}/libffi/include" \
    -DFFI_LIBRARY_DIR="${PROJECTROOT}/libffi/lib" \
    -DFFI_LIBRARY_PATH="${PROJECTROOT}/libffi/lib/libffi.a" \
    -Wno-dev

    #-DLLVM_NATIVE_BUILD=/Users/khronos31/src/Khronos/Mayflower/packages/rust/arm64/rustc-1.44.1-src/build/x86_64-apple-darwin/llvm/build \
    #-DLLVM_TARGETS_TO_BUILD="AArch64;ARM;Hexagon;MSP430;Mips;NVPTX;PowerPC;RISCV;Sparc;SystemZ;WebAssembly;X86" \
    #-DCMAKE_EXE_LINKER_FLAGS="-arch arm64 -miphoneos-version-min=10.0 -isysroot ${SDK}" \
    #-DCMAKE_MODULE_LINKER_FLAGS="-arch arm64 -miphoneos-version-min=10.0 -isysroot ${SDK}" \
    #-DCMAKE_SHARED_LINKER_FLAGS="-arch arm64 -miphoneos-version-min=10.0 -isysroot ${SDK}" \
    #-DLLVM_ENABLE_RUNTIMES="libcxx" \
    #-DCMAKE_C_FLAGS="-fPIC" \
    #-DCMAKE_CXX_FLAGS="-fPIC" \
    #-DCMAKE_C_COMPILER=cc \
    #-DCMAKE_CXX_COMPILER=c++ \
    #-DPYTHON_EXECUTABLE=/usr/bin/python \

  cmake --build . --config Release -- -j "$(nproc)"
}

package() {
  cd "${pkgname}-${pkgver}.src/build"
  DESTDIR="${pkgdir}" cmake --build . --target install --config Release -- -j "$(nproc)"

  install -d "${pkgdir}/usr/share/licenses/${pkgname}"
  install -m644 ../LICENSE.TXT "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
}
