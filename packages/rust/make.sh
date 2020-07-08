pkgname=rust
pkgver=1.44.1
pkgrel=1

# URL of source archive
source="https://static.rust-lang.org/dist/rustc-${pkgver}-src.tar.gz"

ARCH="${ARCH-$(arch)}"
COMMON_FLAGS=""

build() {
  cd "rustc-${pkgver}-src"

  local target_cpu="${ARCH}"
  case "${target_cpu}" in
    arm64) target_cpu=aarch64;;
  esac

  cat >config-stage1.toml <<END
[llvm]
link-shared = false

[build]
target = ["x86_64-apple-darwin"]
docs = false
compiler-docs = false
vendor = false
extended = false

[install]
prefix = "/usr"

[rust]
rpath = true
llvm-tools = false
channel = "stable"

[target.x86_64-apple-darwin]

[dist]
END

  cat >config.toml <<END
[llvm]
link-shared = false

[build]
host = ["${target_cpu}-apple-ios"]
target = ["${target_cpu}-apple-ios"]
docs = false
compiler-docs = false
vendor = true
extended = true

[install]
prefix = "/usr"

[rust]
codegen-units-std = 1
debuginfo-level-std = 2
default-linker = "clang"
channel = "stable"
rpath = true

[target.${target_cpu}-apple-ios]

[dist]
END

  export ${target_cpu^^}_APPLE_IOS_OPENSSL_LIB_DIR="${PROJECTROOT}/openssl/${ARCH}/lib"
  export ${target_cpu^^}_APPLE_IOS_OPENSSL_INCLUDE_DIR="${PROJECTROOT}/openssl/${ARCH}/include"

  python ./x.py dist \
    --stage 1 -j "$(nproc)" \
    --host="x86_64-apple-darwin" \
    --target="x86_64-apple-darwin" \
    --config config-stage1.toml
  python ./x.py dist cargo \
    --stage 1 -j "$(nproc)" \
    --host="x86_64-apple-darwin" \
    --target="x86_64-apple-darwin" \
    --config config-stage1.toml

  local date="$(date +%Y-%m-%d)"
  mv build build_
  mkdir -p "build/cache/${date}"
  mv build_/dist/* "build/cache/${date}"
  cat >src/stage0.txt <<END
date: ${date}
rustc: ${pkgver}
cargo: 0.45.1
END

  python ./x.py dist -j "$(nproc)" \
    --host="${target_cpu}-apple-ios" \
    --target="${target_cpu}-apple-ios" \
    --config config.toml
}

package() {
  cd "rustc-${pkgver}-src"

  local license
  for license in LICENSE*; do
    ginstall -D -m644 "${license}" "${pkgdir}/usr/share/licenses/${pkgname}/${license}"
  done

  local target_cpu="${ARCH}"
  case "${target_cpu}" in
    arm64) target_cpu=aarch64;;
  esac

  mkdir -p destdir

  tar xf "build/dist/rust-${pkgver}-${target_cpu}-apple-ios.tar.gz" -C destdir
  cd "destdir/rust-${pkgver}-${target_cpu}-apple-ios"
  bash ./install.sh --prefix=/usr --destdir="${pkgdir}" --without=llvm-tools-preview
  cd -

  tar xf "build/dist/rust-src-${pkgver}.tar.gz" -C destdir
  cd "destdir/rust-src-${pkgver}"
  bash ./install.sh --prefix=/usr --destdir="${pkgdir}"
  cd -

  rm -r "${pkgdir}/usr/share/doc"

  # delete unnecesary files, e.g. components and manifest files only used for the uninstall script
  cd "${pkgdir}/usr/lib/rustlib"
  rm components install.log manifest-* rust-installer-version uninstall.sh

  mkdir -p "${pkgdir}/usr/share/bash-completion"
  mv "${pkgdir}/usr/etc/bash_completion.d" "${pkgdir}/usr/share/bash-completion/completions"
  find "${pkgdir}" -type d -empty -delete
}
