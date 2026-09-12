# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/llvm/make.sh
#
# Mac で建てた dist を梱包。端末ではソースビルドしない。
# Swift は別パッケージ（packages/swift — ここには含めない）。
#
# Procursus 互換の分割（lib* + versioned + metas）:
#   libllvm19, libclang-cpp19, libclang1-19, libclang-common-19-dev,
#   llvm-19-linker-tools (libLTO; NOT lld), lld-19, lld,
#   llvm-19, llvm-19-dev, llvm-dev,
#   libc++-19-dev, libc++-dev,
#   clang-19, clang-default, llvm-default

pkgname=llvm
pkgver=19.1.4
pkgrel=7
# dist tarball 名に残っているだけ（Swift 同梱前の Mac 成果物）
swiftver=6.1.1
srcname=dist
source=""
subpkgs=(
  libllvm19
  libclangcpp19
  libclang119
  libclangcommon19dev
  linkertools
  lld19
  lld
  llvm19
  llvm19dev
  llvmdev
  libcxx19dev
  libcxxdev
  clang19
  clangdefault
  llvmdefault
)
export compress=xz

llvm_major=19

llvm_prefix() {
  echo "${JB}/usr/lib/llvm-${llvm_major}"
}

tree_name() {
  echo "llvm-${pkgver}-swift-${swiftver}-aarch64-apple-ios"
}

prepare() {
  : "${LLVM_DIST_DIR:?Mac で建てた dist のあるディレクトリを渡すこと（tools/mac/llvm-swift/build.sh）}"
  mkdir -p "${srcdir}"
  cd "${srcdir}" || return 1
  local t
  t="$(tree_name)"
  if [ ! -d "${t}" ]; then
    [ -r "${LLVM_DIST_DIR}/${t}.tar.xz" ] || {
      echo "prepare: ${LLVM_DIST_DIR}/${t}.tar.xz が無い" >&2
      return 1
    }
    tar xf "${LLVM_DIST_DIR}/${t}.tar.xz"
  fi
}

build() {
  :
}

check() {
  cd "${srcdir}" || return 1
  local clang treedir
  treedir="$(tree_name)"
  clang="${treedir}/bin/clang"
  [ -x "${clang}" ] || {
    echo "check: ${clang} が無い" >&2
    return 1
  }
  # Shared builds need libclang-cpp / libLLVM from the unpacked tree before install.
  # Do NOT export permanently — later wrapper compile uses host/procursus cc.
  local _dyld="${srcdir}/${treedir}/lib"
  if command -v ldid >/dev/null 2>&1; then
    ldid -S"${ENTFILE}" "${clang}"
    local d
    for d in "${treedir}/lib"/libLLVM.dylib "${treedir}/lib"/libclang-cpp*.dylib \
             "${treedir}/lib"/libclang.dylib "${treedir}/lib"/libLTO.dylib; do
      [ -e "${d}" ] || continue
      ldid -S"${ENTFILE}" "${d}" || true
    done
  fi
  DYLD_LIBRARY_PATH="${_dyld}${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" "${clang}" --version
}


install_tool() {
  local src="$1" dest="$2"
  install -d "$(dirname "${dest}")"
  if [ -L "${src}" ]; then
    cp -a "${src}" "${dest}"
  else
    install -m755 "${src}" "${dest}"
    ldid -S"${ENTFILE}" "${dest}" || true
  fi
}

install_dylib() {
  local src="$1" dest="$2"
  install -d "$(dirname "${dest}")"
  if [ -L "${src}" ]; then
    cp -a "${src}" "${dest}"
  else
    install -m755 "${src}" "${dest}"
    ldid -S"${ENTFILE}" "${dest}" || true
  fi
}

require_file() {
  local f="$1" what="$2"
  [ -e "${f}" ] || {
    echo "${what}: required file missing: ${f}" >&2
    return 1
  }
}

install_clang_wrapper() {
  local outname="$1" toolname="$2" pref="$3"
  local real="${pref}/bin/${toolname}"
  [ -e "${pkgdir}${real}" ] || [ -L "${pkgdir}${real}" ] || return 0
  "${CC}" -O2 -o "${pkgdir}${JB}/usr/bin/${outname}" \
    "${PROJECTROOT}/files/toolchain-wrapper.c" \
    -DTOOL="\"${real}\"" \
    -DDEFAULT_SYSROOT="\"${JB}/usr/share/SDKs/iPhoneOS.sdk\"" \
    -DEXTRA_CPATH="\"${JB}/usr/include\"" \
    -DEXTRA_LIBRARY_PATH="\"${JB}/usr/lib\""
  ldid -S"${ENTFILE}" "${pkgdir}${JB}/usr/bin/${outname}"
}

# --- libllvm19 ---
package_libllvm19() {
  cd "${srcdir}" || return 1
  local tree pref libdir
  tree="$(tree_name)"
  pref="$(llvm_prefix)"
  libdir="${tree}/lib"

  require_file "${libdir}/libLLVM.dylib" "libllvm19" || return 1

  install -d "${pkgdir}${pref}/lib"
  install_dylib "${libdir}/libLLVM.dylib" "${pkgdir}${pref}/lib/libLLVM.dylib"
  if [ -e "${libdir}/libLLVM-${llvm_major}.dylib" ]; then
    install_dylib "${libdir}/libLLVM-${llvm_major}.dylib" \
      "${pkgdir}${pref}/lib/libLLVM-${llvm_major}.dylib"
  else
    ln -sf libLLVM.dylib "${pkgdir}${pref}/lib/libLLVM-${llvm_major}.dylib"
  fi
}

# --- libclang-cpp19 ---
package_libclangcpp19() {
  cd "${srcdir}" || return 1
  local tree pref libdir f found=0
  tree="$(tree_name)"
  pref="$(llvm_prefix)"
  libdir="${tree}/lib"

  install -d "${pkgdir}${pref}/lib"
  for f in "${libdir}"/libclang-cpp*.dylib; do
    [ -e "${f}" ] || continue
    install_dylib "${f}" "${pkgdir}${pref}/lib/$(basename "${f}")"
    found=1
  done
  [ "${found}" = 1 ] || {
    echo "libclang-cpp19: no libclang-cpp*.dylib in dist" >&2
    return 1
  }
}

# --- libclang1-19 ---
package_libclang119() {
  cd "${srcdir}" || return 1
  local tree pref libdir
  tree="$(tree_name)"
  pref="$(llvm_prefix)"
  libdir="${tree}/lib"

  require_file "${libdir}/libclang.dylib" "libclang1-19" || return 1

  install -d "${pkgdir}${pref}/lib"
  install_dylib "${libdir}/libclang.dylib" "${pkgdir}${pref}/lib/libclang.dylib"
  if [ -e "${libdir}/libclang-${llvm_major}.dylib" ]; then
    install_dylib "${libdir}/libclang-${llvm_major}.dylib" \
      "${pkgdir}${pref}/lib/libclang-${llvm_major}.dylib"
  else
    ln -sf libclang.dylib "${pkgdir}${pref}/lib/libclang-${llvm_major}.dylib"
  fi
}

# --- libclang-common-19-dev (resource headers; polly if present) ---
package_libclangcommon19dev() {
  cd "${srcdir}" || return 1
  local tree pref
  tree="$(tree_name)"
  pref="$(llvm_prefix)"

  [ -d "${tree}/lib/clang" ] || {
    echo "libclang-common-19-dev: ${tree}/lib/clang missing" >&2
    return 1
  }

  install -d "${pkgdir}${pref}/lib" \
    "${pkgdir}${JB}/usr/lib/clang"

  cp -a "${tree}/lib/clang" "${pkgdir}${pref}/lib/"
  # Procursus-style alias: usr/lib/clang/<ver> -> ../llvm-19/lib/clang/<ver>
  local verdir
  for verdir in "${pkgdir}${pref}/lib/clang"/*; do
    [ -d "${verdir}" ] || continue
    verdir="$(basename "${verdir}")"
    ln -sfn "../llvm-${llvm_major}/lib/clang/${verdir}" \
      "${pkgdir}${JB}/usr/lib/clang/${verdir}"
  done

  # Polly static/libs/headers if the dist shipped them
  local f
  for f in "${tree}/lib"/libPolly*.a; do
    [ -e "${f}" ] || continue
    install -d "${pkgdir}${pref}/lib"
    install -m644 "${f}" "${pkgdir}${pref}/lib/"
  done
  if [ -d "${tree}/include/polly" ]; then
    install -d "${pkgdir}${pref}/include"
    cp -a "${tree}/include/polly" "${pkgdir}${pref}/include/"
  fi
  if [ -d "${tree}/lib/cmake/polly" ]; then
    install -d "${pkgdir}${pref}/lib/cmake"
    cp -a "${tree}/lib/cmake/polly" "${pkgdir}${pref}/lib/cmake/"
  fi
}

# --- llvm-19-linker-tools: libLTO (+ LLVMPolly); NOT lld bins ---
package_linkertools() {
  cd "${srcdir}" || return 1
  local tree pref libdir
  tree="$(tree_name)"
  pref="$(llvm_prefix)"
  libdir="${tree}/lib"

  require_file "${libdir}/libLTO.dylib" "llvm-19-linker-tools" || return 1

  install -d "${pkgdir}${pref}/lib" \
    "${pkgdir}${JB}/usr/share/doc/llvm-${llvm_major}-linker-tools"

  install_dylib "${libdir}/libLTO.dylib" "${pkgdir}${pref}/lib/libLTO.dylib"

  local f
  for f in "${libdir}"/LLVMPolly.so "${libdir}"/LLVMPolly.dylib \
           "${libdir}"/libLLVMPolly.dylib; do
    [ -e "${f}" ] || continue
    install_dylib "${f}" "${pkgdir}${pref}/lib/$(basename "${f}")"
  done

  printf 'llvm-%s-linker-tools: libLTO (+ LLVMPolly if present); lld is in lld-%s\n' \
    "${llvm_major}" "${llvm_major}" \
    > "${pkgdir}${JB}/usr/share/doc/llvm-${llvm_major}-linker-tools/README"
}

# --- lld-19 ---
package_lld19() {
  cd "${srcdir}" || return 1
  local tree pref
  tree="$(tree_name)"
  pref="$(llvm_prefix)"

  require_file "${tree}/bin/lld" "lld-19" || return 1

  install -d "${pkgdir}${pref}/bin" "${pkgdir}${JB}/usr/bin"

  install_tool "${tree}/bin/lld" "${pkgdir}${pref}/bin/lld"
  ln -sf lld "${pkgdir}${pref}/bin/ld64.lld"
  ln -sf lld "${pkgdir}${pref}/bin/ld.lld"
  # Optional extras if dist has them
  local t
  for t in lld-link wasm-ld; do
    [ -e "${tree}/bin/${t}" ] || continue
    install_tool "${tree}/bin/${t}" "${pkgdir}${pref}/bin/${t}"
  done

  for t in lld ld64.lld ld.lld lld-link wasm-ld; do
    [ -e "${pkgdir}${pref}/bin/${t}" ] || [ -L "${pkgdir}${pref}/bin/${t}" ] || continue
    ln -sf "../lib/llvm-${llvm_major}/bin/${t}" \
      "${pkgdir}${JB}/usr/bin/${t}-${llvm_major}"
  done
}

# --- lld meta (unversioned PATH → lld-19) ---
package_lld() {
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/lld"

  local t
  for t in lld ld64.lld ld.lld lld-link wasm-ld; do
    ln -sf "../lib/llvm-${llvm_major}/bin/${t}" \
      "${pkgdir}${JB}/usr/bin/${t}"
  done

  printf 'lld → lld-%s binaries under /var/jb/usr/lib/llvm-%s/bin\n' \
    "${llvm_major}" "${llvm_major}" \
    > "${pkgdir}${JB}/usr/share/doc/lld/README"
}

# --- llvm-19 expanded tools ---
package_llvm19() {
  cd "${srcdir}" || return 1
  local tree pref
  tree="$(tree_name)"
  pref="$(llvm_prefix)"

  install -d "${pkgdir}${pref}/bin" "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/llvm-${llvm_major}"

  local t
  for t in \
    llvm-ar llvm-nm llvm-ranlib llvm-config dsymutil opt llc \
    llvm-objdump llvm-objcopy llvm-strip llvm-symbolizer llvm-cxxfilt \
    llvm-size llvm-strings llvm-install-name-tool llvm-lipo
  do
    [ -e "${tree}/bin/${t}" ] || continue
    install_tool "${tree}/bin/${t}" "${pkgdir}${pref}/bin/${t}"
  done

  # ranlib often a symlink to llvm-ar
  if [ ! -e "${pkgdir}${pref}/bin/llvm-ranlib" ]; then
    if [ -e "${tree}/bin/llvm-ranlib" ]; then
      cp -a "${tree}/bin/llvm-ranlib" "${pkgdir}${pref}/bin/llvm-ranlib"
    elif [ -e "${pkgdir}${pref}/bin/llvm-ar" ]; then
      ln -sf llvm-ar "${pkgdir}${pref}/bin/llvm-ranlib"
    fi
  fi

  for t in \
    llvm-ar llvm-nm llvm-ranlib llvm-config dsymutil opt llc \
    llvm-objdump llvm-objcopy llvm-strip llvm-symbolizer llvm-cxxfilt \
    llvm-size llvm-strings llvm-install-name-tool llvm-lipo
  do
    [ -e "${pkgdir}${pref}/bin/${t}" ] || [ -L "${pkgdir}${pref}/bin/${t}" ] || continue
    ln -sf "../lib/llvm-${llvm_major}/bin/${t}" \
      "${pkgdir}${JB}/usr/bin/${t}-${llvm_major}"
  done
}

# --- llvm-19-dev ---
package_llvm19dev() {
  cd "${srcdir}" || return 1
  local tree pref
  tree="$(tree_name)"
  pref="$(llvm_prefix)"

  install -d "${pkgdir}${pref}/include" "${pkgdir}${pref}/lib"

  if [ -d "${tree}/include/llvm" ]; then
    cp -a "${tree}/include/llvm" "${pkgdir}${pref}/include/"
  else
    echo "llvm-19-dev: include/llvm missing (optional headers install may have been skipped)" >&2
  fi
  if [ -d "${tree}/include/llvm-c" ]; then
    cp -a "${tree}/include/llvm-c" "${pkgdir}${pref}/include/"
  fi

  local f
  for f in "${tree}/lib"/libLLVM*.a; do
    [ -e "${f}" ] || continue
    install -m644 "${f}" "${pkgdir}${pref}/lib/"
  done
  if [ -e "${tree}/lib/libRemarks.dylib" ]; then
    install_dylib "${tree}/lib/libRemarks.dylib" "${pkgdir}${pref}/lib/libRemarks.dylib"
  fi
  if [ -d "${tree}/lib/cmake/llvm" ]; then
    install -d "${pkgdir}${pref}/lib/cmake"
    cp -a "${tree}/lib/cmake/llvm" "${pkgdir}${pref}/lib/cmake/"
  fi
}

# --- llvm-dev meta ---
package_llvmdev() {
  local pref
  pref="$(llvm_prefix)"

  install -d "${pkgdir}${JB}/usr/include" "${pkgdir}${JB}/usr/lib" \
    "${pkgdir}${JB}/usr/share/doc/llvm-dev"

  ln -sfn "../lib/llvm-${llvm_major}/include/llvm" \
    "${pkgdir}${JB}/usr/include/llvm"
  ln -sfn "../lib/llvm-${llvm_major}/include/llvm-c" \
    "${pkgdir}${JB}/usr/include/llvm-c"
  ln -sfn "llvm-${llvm_major}/lib/libLTO.dylib" \
    "${pkgdir}${JB}/usr/lib/libLTO.dylib"

  printf 'llvm-dev → llvm-%s-dev + llvm-%s-linker-tools (Provides liblto)\n' \
    "${llvm_major}" "${llvm_major}" \
    > "${pkgdir}${JB}/usr/share/doc/llvm-dev/README"
}

# --- libc++-19-dev (headers + pstl; no dylib) ---
package_libcxx19dev() {
  cd "${srcdir}" || return 1
  local tree pref
  tree="$(tree_name)"
  pref="$(llvm_prefix)"

  [ -d "${tree}/include/c++" ] || {
    echo "libc++-19-dev: ${tree}/include/c++ missing (run build.sh libcxx / install)" >&2
    return 1
  }

  install -d "${pkgdir}${pref}/include"
  cp -a "${tree}/include/c++" "${pkgdir}${pref}/include/"

  # Procursus ships include/*pstl* next to include/c++
  local f
  for f in "${tree}/include"/__pstl* "${tree}/include"/pstl; do
    [ -e "${f}" ] || continue
    cp -a "${f}" "${pkgdir}${pref}/include/"
  done
}

# --- libc++-dev meta: /var/jb/usr/include/c++ → llvm-19 ---
package_libcxxdev() {
  install -d "${pkgdir}${JB}/usr/include" \
    "${pkgdir}${JB}/usr/share/doc/libc++-dev"

  ln -sfn "../lib/llvm-${llvm_major}/include/c++" \
    "${pkgdir}${JB}/usr/include/c++"

  printf 'libc++-dev → libc++-%s-dev headers under /var/jb/usr/lib/llvm-%s/include/c++\n' \
    "${llvm_major}" "${llvm_major}" \
    > "${pkgdir}${JB}/usr/share/doc/libc++-dev/README"
}

# --- clang-19 (frontend + wrappers; resources moved out) ---
package_clang19() {
  cd "${srcdir}" || return 1
  local tree pref
  tree="$(tree_name)"
  pref="$(llvm_prefix)"

  install -d "${pkgdir}${pref}/bin" \
    "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/clang-${llvm_major}" \
    "${pkgdir}${JB}/usr/share/licenses/clang-${llvm_major}"

  install_tool "${tree}/bin/clang-19" "${pkgdir}${pref}/bin/clang-19"
  ln -sf clang-19 "${pkgdir}${pref}/bin/clang"
  ln -sf clang-19 "${pkgdir}${pref}/bin/clang++"
  ln -sf clang-19 "${pkgdir}${pref}/bin/clang-cpp"

  # Resource headers live in libclang-common-19-dev — do NOT ship here.

  install -m644 "${PROJECTROOT}/files/entitlements.plist" \
    "${pkgdir}${pref}/entitlements.plist"

  install_clang_wrapper "clang-${llvm_major}" "clang-19" "${pref}"
  install_clang_wrapper "clang++-${llvm_major}" "clang++" "${pref}"
  install_clang_wrapper "clang-cpp-${llvm_major}" "clang-cpp" "${pref}"

  if [ -r "${tree}/LICENSE.TXT" ]; then
    install -m644 "${tree}/LICENSE.TXT" \
      "${pkgdir}${JB}/usr/share/licenses/clang-${llvm_major}/"
  fi
}

package_clangdefault() {
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/clang-default"

  ln -sf "clang-${llvm_major}" "${pkgdir}${JB}/usr/bin/clang"
  ln -sf "clang++-${llvm_major}" "${pkgdir}${JB}/usr/bin/clang++"
  ln -sf "clang-cpp-${llvm_major}" "${pkgdir}${JB}/usr/bin/clang-cpp"
  ln -sf "clang-${llvm_major}" "${pkgdir}${JB}/usr/bin/cc"
  ln -sf "clang++-${llvm_major}" "${pkgdir}${JB}/usr/bin/c++"

  printf 'clang-default → clang-%s\n' "${llvm_major}" \
    > "${pkgdir}${JB}/usr/share/doc/clang-default/README"
}

package_llvmdefault() {
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/llvm-default"

  local t
  for t in llvm-ar llvm-nm llvm-ranlib llvm-config dsymutil opt llc \
           llvm-objdump llvm-objcopy llvm-strip llvm-symbolizer \
           llvm-cxxfilt llvm-size llvm-strings llvm-install-name-tool llvm-lipo; do
    ln -sf "${t}-${llvm_major}" "${pkgdir}${JB}/usr/bin/${t}"
  done
  # Unversioned lld / ld64.lld / ld.lld live in the lld meta package.

  printf 'llvm-default → llvm-%s tools (lld PATH via lld meta)\n' "${llvm_major}" \
    > "${pkgdir}${JB}/usr/share/doc/llvm-default/README"
}
