export staticlibs=n
export zipman=n

check_option() {
  if [ $# -lt 2 ]; then
    echo "Usage: ${FUNCNAME} <option> [y|n]" >&2
    return 2
  fi

  local opt
  case "$2" in
    y|n) :;;
    *) echo "Usage: ${FUNCNAME} <option> [y|n]" >&2; return 2;;
  esac

  if [ -z "${!1}" ]; then
    echo "Undefined option \"$1\"" >&2
    return 2
  fi

  case "${!1,,}" in
    y|yes|true|1) opt=y;;
    n|no|false|0) opt=n;;
    *) echo "Unvalid value." >&2; return 2;;
  esac

  if [ "${opt}" = "$2" ]; then
    return 0
  else
    return 1
  fi
}