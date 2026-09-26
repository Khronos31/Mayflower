# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/recisdb/make.sh
#
# recisdb 1.2.4 を decode-only + libpcsclite で端末 rustc 建て。
#
# ソースは Khronos31/recisdb-rs @ REC_COMMIT（kazuki0824#188 の fork）。
# 公式がマージして次のタグを出したら source を
#   https://github.com/kazuki0824/recisdb-rs/archive/refs/tags/vX.Y.Z.tar.gz
# に差し替える。iOS パッチ（decode-only / libpcsclite / LPTSTR）は残す。
#
# vendor.tar.gz は git 外（packages/*/*.tar.*）。crates.io が 403 になるため。

pkgname=recisdb
pkgver=1.2.4
pkgrel=1
REC_COMMIT=badc171f15bb010b972740c17a92cfe0cbfe8584
ARIBB25_COMMIT=12213899010738acaadd7fd945c9e25d35561af7
srcname="recisdb-rs-${REC_COMMIT}"
source="https://github.com/Khronos31/recisdb-rs/archive/${REC_COMMIT}.tar.gz"
export compress="${compress:-xz}"

prepare() {
  cd "${srcdir}" || return 1

  if [ ! -f b25-sys/externals/libaribb25/CMakeLists.txt ]; then
    local arib_tar="${BUILDROOT}/libaribb25-${ARIBB25_COMMIT}.tar.gz"
    if [ ! -r "${arib_tar}" ]; then
      curl -fsSL -o "${arib_tar}" \
        "https://github.com/tsukumijima/libaribb25/archive/${ARIBB25_COMMIT}.tar.gz"
    fi
    tar -xzf "${arib_tar}" -C "${BUILDROOT}"
    rm -rf b25-sys/externals/libaribb25
    mv "${BUILDROOT}/libaribb25-${ARIBB25_COMMIT}" b25-sys/externals/libaribb25
  fi

  local v="${PROJECTROOT}/vendor.tar.gz"
  [ -r "${v}" ] || {
    echo "prepare: ${v} が無い。端末で cargo vendor --locked して置くこと" >&2
    return 1
  }
  tar -xzf "${v}"
  mkdir -p .cargo
  cat "${PROJECTROOT}/files/cargo-vendor-config.toml" >> .cargo/config.toml

  python3 - "${srcdir}/recisdb-rs/build.rs" "${srcdir}/b25-sys/build.rs" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
t = p.read_text()
if 'Ok("ios")' not in t:
    old = 'if env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos") {'
    new = 'if matches!(env::var("CARGO_CFG_TARGET_OS").as_deref(), Ok("macos") | Ok("ios")) {'
    if old not in t:
        raise SystemExit("prepare: recisdb-rs/build.rs macos skip not found")
    t = t.replace(old, new, 1)
    p.write_text(t)

p = Path(sys.argv[2])
t = p.read_text()
if 'Some("ios")' in t:
    sys.exit(0)
old = '    if target.ends_with("-gnullvm") || target.ends_with("-apple-darwin") {'
new = '''    if target.ends_with("-gnullvm")
        || target.ends_with("-apple-darwin")
        || target.ends_with("-apple-ios")
    {'''
if old not in t:
    raise SystemExit("prepare: b25-sys apple-darwin link not found")
t = t.replace(old, new, 1)
old = '''        println!("cargo:rustc-link-lib=framework=PCSC");
    }
}'''
new = '''        println!("cargo:rustc-link-lib=framework=PCSC");
    } else if cx.os.as_deref() == Some("ios") {
        if pc.probe("libpcsclite").is_err() {
            panic!("libpcsclite not found.");
        }
        let res = prep_cmake(cx).build();
        println!("cargo:rustc-link-search=native={}/lib", res.display());
        println!("cargo:rustc-link-search=native={}/lib64", res.display());
    }
}'''
if old not in t:
    raise SystemExit("prepare: b25-sys macos PCSC branch not found")
p.write_text(t.replace(old, new, 1))
PY
}

build() {
  cd "${srcdir}" || return 1
  export CARGO_HOME="${BUILDROOT}/cargo-home"
  export CARGO_TARGET_DIR="${BUILDROOT}/recisdb-target"
  export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}"
  export CARGO_INCREMENTAL=0
  export CARGO_PROFILE_RELEASE_DEBUG=0
  export CC="${CC:-clang}"
  export CXX="${CXX:-clang++}"
  export CMAKE_MAKE_PROGRAM="${ROOTDIR}/bin/make"
  export CONFIG_SHELL="${JB}/bin/sh"
  export PKG_CONFIG_PATH="${JB}/usr/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
  export TMPDIR="${TMPDIR:-${HOME}/tmp}"
  mkdir -p "${CARGO_HOME}" "${TMPDIR}"
  cargo build --release --offline --locked -p recisdb
}

check() {
  local bin="${BUILDROOT}/recisdb-target/release/recisdb"
  ldid -S"${ENTFILE}" "${bin}"
  "${bin}" --help | grep -q decode
  "${bin}" --version
}

package() {
  local bin="${BUILDROOT}/recisdb-target/release/recisdb"
  ldid -S"${ENTFILE}" "${bin}"
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/recisdb" \
    "${pkgdir}${JB}/usr/share/licenses/recisdb"
  install -m755 "${bin}" "${pkgdir}${JB}/usr/bin/recisdb"
  cd "${srcdir}" || return 1
  install -m644 README.md "${pkgdir}${JB}/usr/share/doc/recisdb/"
  if [ -f LICENSE ]; then
    install -m644 LICENSE "${pkgdir}${JB}/usr/share/licenses/recisdb/"
  fi
  install -m644 "${PROJECTROOT}/copyright" \
    "${pkgdir}${JB}/usr/share/doc/recisdb/copyright"
}
