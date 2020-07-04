tidy_options=("staticlibs" "zipman" "resign")

tidy_staticlibs() {
  if check_option "staticlibs" "n"; then
    local l
    find "${pkgdir}" ! -type d -name "*.a" |
    while read l; do
      if [ -f "${l%.a}.dylib" -o -h "${l%.a}.dylib" ]; then
        rm "$l"
      fi
    done
  fi
}

tidy_zipman() {
  if check_option "zipman" "y"; then
    find "${pkgdir}/usr/share/man" -type f -not -name "*.gz" -not -name "*.bz2" |
    while read file; do
      if [ -f "${file}" ]; then
        gzip -f "${file}"
      elif [ -h "${file}" ]; then
        ln -s "$(readlink "${file}").gz" "${file}.gz"
        rm "${file}"
      fi
    done
  fi
}

tidy_resign() {
  if check_option "resign" "y"; then
    local x
    find "${pkgdir}" -type f |
    while read x; do
      if ldid -e "$x" >"${ROOTDIR}/tmp.xml" 2>/dev/null && [ -s "${ROOTDIR}/tmp.xml" ]; then
        ldid -S"${ROOTDIR}/tmp.xml" "$x"
      else
        ldid -S"${ROOTDIR}/entitlements.xml" "$x" 2>/dev/null || true
      fi
      rm -f "${ROOTDIR}/tmp.xml"
    done
  fi
}

tidy() {
  local opt
  for opt in "${tidy_options[@]}"; do
    tidy_${opt}
  done
}
