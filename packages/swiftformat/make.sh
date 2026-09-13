# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/swiftformat/make.sh
#
# nicklockwood/SwiftFormat — Swift ソース整形 CLI。
# 端末の Mayflower swiftc-6.1 で SPM 無し（swift-package 未同梱）のため
# Sources + CommandLineTool を一括 swiftc する。
# Procursus に同名は無い。
#
# ビルド依存:
#   - swift-6.1（swiftc-6.1）
#   - Theos 等の iPhoneOS*.sdk（SDKROOT か $HOME/theos/sdks）
#   - files/libclang_rt.ios.a（___isPlatformVersionAtLeast）
#   - files/clang-include-override/arm_vector_types.h（18.x SDK + 古い
#     Mayflower clang resource-dir の __mfp8 食い違い回避）

pkgname=swiftformat
pkgver=0.63.0
pkgrel=1
srcname="SwiftFormat-${pkgver}"
source="https://github.com/nicklockwood/SwiftFormat/archive/refs/tags/${pkgver}.tar.gz"
export compress="${compress:-xz}"

_find_sdk() {
  if [ -n "${SDKROOT:-}" ] && [ -d "${SDKROOT}" ]; then
    printf '%s\n' "${SDKROOT}"
    return 0
  fi
  local d newest=""
  # Prefer higher SDK versions when several exist
  for d in "${HOME}/theos/sdks"/iPhoneOS*.sdk /opt/theos/sdks/iPhoneOS*.sdk; do
    [ -d "${d}" ] || continue
    newest="${d}"
  done
  if [ -n "${newest}" ]; then
    printf '%s\n' "${newest}"
    return 0
  fi
  return 1
}

_setup_resource_dir() {
  # Thin resource-dir: stock Mayflower Swift libs + Xcode-aligned arm_vector_types.h
  local rd="${BUILDROOT}/swift-rd"
  local stock="${JB}/usr/lib/swift"
  local override="${PROJECTROOT}/files/clang-include-override/arm_vector_types.h"
  rm -rf "${rd}"
  mkdir -p "${rd}/clang"
  local x
  for x in "${stock}"/*; do
    [ -e "${x}" ] || continue
    case "$(basename "${x}")" in
      clang) continue ;;
    esac
    ln -s "${x}" "${rd}/$(basename "${x}")"
  done
  for x in "${stock}/clang"/*; do
    [ -e "${x}" ] || continue
    case "$(basename "${x}")" in
      include) continue ;;
    esac
    ln -s "${x}" "${rd}/clang/$(basename "${x}")"
  done
  cp -a "${stock}/clang/include" "${rd}/clang/include"
  if [ -f "${override}" ]; then
    cp "${override}" "${rd}/clang/include/arm_vector_types.h"
  fi
  printf '%s\n' "${rd}"
}

prepare() {
  cd "${srcdir}" || return 1
  local rt="${PROJECTROOT}/files/libclang_rt.ios.a"
  [ -r "${rt}" ] || {
    echo "prepare: ${rt} が無い" >&2
    return 1
  }
}

build() {
  cd "${srcdir}" || return 1
  export TMPDIR="${TMPDIR:-${HOME}/tmp}"
  mkdir -p "${TMPDIR}" "${BUILDROOT}"

  local swc
  swc="$(command -v swiftc-6.1 || true)"
  [ -n "${swc}" ] || swc="$(command -v swiftc || true)"
  [ -n "${swc}" ] || {
    echo "build: swiftc-6.1 / swiftc が無い（swift-6.1 を入れること）" >&2
    return 1
  }

  local sdk
  sdk="$(_find_sdk)" || {
    echo "build: iPhoneOS SDK が無い。SDKROOT か \$HOME/theos/sdks/iPhoneOS*.sdk を用意すること" >&2
    return 1
  }

  local rd rt
  rd="$(_setup_resource_dir)"
  rt="${PROJECTROOT}/files/libclang_rt.ios.a"

  # Collect sources (SPM 無しなので一括)
  local -a srcs=()
  local f
  while IFS= read -r f; do
    srcs+=("${f}")
  done < <(find Sources -name '*.swift' | sort)
  while IFS= read -r f; do
    srcs+=("${f}")
  done < <(find CommandLineTool -name '*.swift' | sort)
  [ "${#srcs[@]}" -gt 1 ] || {
    echo "build: Sources / CommandLineTool の .swift が見つからない" >&2
    return 1
  }

  echo "build: swiftc=${swc}"
  echo "build: sdk=${sdk}"
  echo "build: resource-dir=${rd}"
  echo "build: sources=${#srcs[@]}"

  # Mayflower Swift 6.1.1: complex SIL で DSE SIGTRAP することがある
  "${swc}" -O \
    -target arm64-apple-ios15.0 \
    -sdk "${sdk}" \
    -resource-dir "${rd}" \
    -Xllvm -sil-disable-pass=dead-store-elimination \
    -Xlinker "${rt}" \
    "${srcs[@]}" \
    -o "${BUILDROOT}/swiftformat"
}

check() {
  local bin="${BUILDROOT}/swiftformat"
  [ -x "${bin}" ] || return 1
  ldid -S"${ENTFILE}" "${bin}"
  "${bin}" --version
  local smoke="${BUILDROOT}/sf-smoke.swift"
  printf 'func hello( name:String )->String{return "hi \\(name)"}\n' > "${smoke}"
  "${bin}" --swiftversion 5.0 "${smoke}"
  grep -q 'func hello(name: String)' "${smoke}"
}

package() {
  local bin="${BUILDROOT}/swiftformat"
  ldid -S"${ENTFILE}" "${bin}"
  install -d \
    "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/doc/swiftformat" \
    "${pkgdir}${JB}/usr/share/licenses/swiftformat"
  install -m755 "${bin}" "${pkgdir}${JB}/usr/bin/swiftformat"
  cd "${srcdir}" || return 1
  if [ -f README.md ]; then
    install -m644 README.md "${pkgdir}${JB}/usr/share/doc/swiftformat/"
  fi
  if [ -f CHANGELOG.md ]; then
    install -m644 CHANGELOG.md "${pkgdir}${JB}/usr/share/doc/swiftformat/"
  fi
  if [ -f LICENSE.md ]; then
    install -m644 LICENSE.md "${pkgdir}${JB}/usr/share/licenses/swiftformat/"
  fi
  printf 'nicklockwood/SwiftFormat %s — format Swift source on the CLI.\nBuilt on-device with Mayflower swiftc-6.1 (no SPM; direct swiftc).\n' \
    "${pkgver}" > "${pkgdir}${JB}/usr/share/doc/swiftformat/README.mayflower"
}
