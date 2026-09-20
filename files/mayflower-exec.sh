# Mayflower | compile PATH wrappers as Mach-O and ldid-sign them.
# Sourced from package make.sh. Requires ROOTDIR, ENTFILE.
# On Darwin (Mac packaging) wrappers are cross-built for iphoneos-arm64;
# bin/cc from ensure_bin_wrappers stays a host binary.

mayflower_wrapper_is_macos_packaging() {
  [ "$(uname -s)" = "Darwin" ] && [ ! -e /var/jb/usr/bin/clang ]
}

mayflower_wrapper_compile() {
  # Usage: mayflower_wrapper_compile <outfile> <src.c> [extra -D...]
  local out="$1" src="$2"
  shift 2
  if mayflower_wrapper_is_macos_packaging; then
    local sdk
    sdk="$(xcrun --sdk iphoneos --show-sdk-path)" || {
      echo "mayflower_wrapper_compile: iphoneos SDK missing" >&2
      return 1
    }
    # Match typical Mayflower floor; packages that need higher set minos themselves.
    clang -target arm64-apple-ios14.0 -isysroot "${sdk}" -O2 -o "${out}" "${src}" "$@" || return 1
  else
    "${CC}" -O2 -o "${out}" "${src}" "$@" || return 1
  fi
  ldid -S"${ENTFILE}" "${out}" || return 1
  chmod 755 "${out}"
}

mayflower_install_exec() {
  local out="$1" tool="$2"
  shift 2
  local src i=0 pair key val force extrai=0
  local -a defs
  src="${ROOTDIR}/files/mayflower-exec.c"
  [ -f "${src}" ] || { echo "mayflower_install_exec: missing ${src}" >&2; return 1; }
  defs=(-DTOOL="\"${tool}\"")
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "--" ]; then
      shift
      break
    fi
    pair="$1"
    shift
    force=0
    case "${pair}" in
      *:force)
        force=1
        pair="${pair%:force}"
        ;;
    esac
    key="${pair%%=*}"
    val="${pair#*=}"
    defs+=(-DSETENV${i}_KEY="\"${key}\"" -DSETENV${i}_VAL="\"${val}\"" -DSETENV${i}_OVERRIDE="${force}")
    i=$((i + 1))
    if [ "${i}" -gt 5 ]; then
      echo "mayflower_install_exec: too many env pairs" >&2
      return 1
    fi
  done
  while [ "$#" -gt 0 ]; do
    defs+=(-DEXTRA_ARGV${extrai}="\"$1\"")
    extrai=$((extrai + 1))
    shift
    if [ "${extrai}" -gt 2 ]; then
      echo "mayflower_install_exec: too many EXTRA args" >&2
      return 1
    fi
  done
  mayflower_wrapper_compile "${out}" "${src}" "${defs[@]}"
}

mayflower_install_node() {
  local out="$1" node_bin="$2" npm_prefix="${3:-${JB}/usr}"
  local src="${ROOTDIR}/files/mayflower-node.c"
  [ -f "${src}" ] || { echo "mayflower_install_node: missing ${src}" >&2; return 1; }
  mayflower_wrapper_compile "${out}" "${src}" \
    -DNODE_BIN="\"${node_bin}\"" \
    -DDEFAULT_NPM_PREFIX="\"${npm_prefix}\""
}

mayflower_compile_swift_tool() {
  local out="$1" srcname="$2"
  local src="${ROOTDIR}/files/${srcname}"
  [ -f "${src}" ] || src="${PROJECTROOT}/files/${srcname}"
  [ -f "${src}" ] || { echo "mayflower_compile_swift_tool: missing ${srcname}" >&2; return 1; }
  mayflower_wrapper_compile "${out}" "${src}"
}
