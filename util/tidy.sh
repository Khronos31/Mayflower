# shellcheck shell=bash
# shellcheck disable=SC2154  # 変数は make.sh が export する
#
# Mayflower | util/tidy.sh
#
# package() の後に pkgdir を整える。

tidy_options=("staticlibs" "zipman" "resign")

# .dylib があるなら .a は落とす。
tidy_staticlibs() {
  if check_option "staticlibs" "n"; then
    local l
    find "${pkgdir}" ! -type d -name "*.a" |
    while read -r l; do
      if [ -f "${l%.a}.dylib" ] || [ -h "${l%.a}.dylib" ]; then
        rm "$l"
      fi
    done
  fi
}

tidy_zipman() {
  if check_option "zipman" "y"; then
    find "${pkgdir}${JB}/usr/share/man" -type f -not -name "*.gz" -not -name "*.bz2" |
    while read -r file; do
      if [ -f "${file}" ]; then
        gzip -f "${file}"
      elif [ -h "${file}" ]; then
        ln -s "$(readlink "${file}").gz" "${file}.gz"
        rm "${file}"
      fi
    done
  fi
}

# 署名し直す。既に entitlements を持つものはそれを維持し、無いものには
# リポジトリの entitlements.plist を当てる。ビルド中に署名されない経路
# （インストーラ経由で入るバイナリ等）の保険。
tidy_resign() {
  if check_option "resign" "y"; then
    local x ent
    ent="$(mktemp)"
    find "${pkgdir}" -type f |
    while read -r x; do
      if ldid -e "$x" >"${ent}" 2>/dev/null && [ -s "${ent}" ]; then
        ldid -S"${ent}" "$x"
      else
        ldid -S"${ENTFILE}" "$x" 2>/dev/null || true
      fi
    done
    rm -f "${ent}"
  fi
}

tidy() {
  local opt
  for opt in "${tidy_options[@]}"; do
    "tidy_${opt}"
  done
}
