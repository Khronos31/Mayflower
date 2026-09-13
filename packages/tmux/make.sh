# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/tmux/make.sh
#
# tmux 3.7c を端末の Clang 19 で建てる。
# Procursus の tmux は 3.4（Package: tmux）。同名は Pin-Priority 1001 で
# 負けるので、本体は tmux-3.7、版なし tmux は tmux-default が
# Provides/Conflicts/Replaces: tmux する。
#
# utf8proc は使わない（Procursus の libutf8proc-dev が libutf8proc2 を
# 要求するが、リポジトリにあるのは libutf8proc3 だけ）。
# libevent / ncursesw は Procursus の実行時ライブラリをリンクする。

pkgname=tmux
pkgver=3.7c
pkgrel=1
srcname="tmux-${pkgver}"
source="https://github.com/tmux/tmux/releases/download/${pkgver}/tmux-${pkgver}.tar.gz"
subpkgs=(tmux default)
export compress="${compress:-xz}"

prepare() {
  cd "${srcdir}" || return 1
  # rootless に /bin/sh は無い。run-shell / if-shell / #() が _PATH_BSHELL を使う。
  if ! grep -q MAYFLOWER_BSHELL tmux.h; then
    cat >> tmux.h <<EOF

/* MAYFLOWER_BSHELL */
#undef _PATH_BSHELL
#define _PATH_BSHELL "${JB}/bin/sh"
EOF
  fi
  # iOS SDK は system(3) を unavailable。MSG_LOCK の1箇所だけ。
  python3 - "${srcdir}/client.c" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
t = p.read_text()
if "tmux_system(" in t:
    sys.exit(0)
old = "\t\tsystem(data);"
if old not in t:
    raise SystemExit("prepare: system(data) not found in client.c")
fn = """
static int
tmux_system(const char *cmd)
{
	pid_t	pid;
	int	status;

	pid = fork();
	if (pid == -1)
		return (-1);
	if (pid == 0) {
		execl(_PATH_BSHELL, "sh", "-c", cmd, (char *)NULL);
		_exit(127);
	}
	if (waitpid(pid, &status, 0) == -1)
		return (-1);
	return (status);
}

"""
needle = "/* Dispatch imsgs in attached state (after MSG_READY). */"
if needle not in t:
    raise SystemExit("prepare: attach-state comment not found")
t = t.replace(needle, fn + needle, 1).replace(old, "\t\ttmux_system(data);", 1)
p.write_text(t)
PY
  # iOS SDK に libproc.h が無い。sysctl 側に落とす。
  python3 - "${srcdir}/osdep-darwin.c" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
t = p.read_text()
if "MAYFLOWER_NO_LIBPROC" in t:
    sys.exit(0)
old = "#include <AvailabilityMacros.h>"
if old not in t:
    raise SystemExit("prepare: AvailabilityMacros.h not found")
t = t.replace(
    old,
    old
    + "\n/* MAYFLOWER_NO_LIBPROC */\n"
    + "#undef MAC_OS_X_VERSION_MIN_REQUIRED\n"
    + "#define MAC_OS_X_VERSION_MIN_REQUIRED 1040\n",
    1,
)
p.write_text(t)
PY
}

build() {
  cd "${srcdir}" || return 1
  export PKG_CONFIG_PATH="${JB}/usr/lib:${JB}/usr/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
  ./configure \
    --prefix="${JB}/usr" \
    --disable-static \
    --disable-utf8proc \
    --disable-jemalloc \
    YACC=bison \
    CC="${CC}" \
    CFLAGS="${CFLAGS}" \
    LDFLAGS="${LDFLAGS}" \
    LIBNCURSES_LIBS="-lncursesw" \
    LIBNCURSES_CFLAGS="-I${JB}/usr/include/ncursesw"
  make -j"${MAKE_JOBS:-1}"
}

check() {
  cd "${srcdir}" || return 1
  ldid -S"${ENTFILE}" ./tmux
  # iOS に ja_JP.UTF-8 は無い。C は US-ASCII 扱いで tmux が拒否する。
  local tmuxenv=(env LC_ALL=UTF-8 LANG=UTF-8)
  "${tmuxenv[@]}" ./tmux -V
  "${tmuxenv[@]}" ./tmux -f /dev/null -L mfcheck kill-server >/dev/null 2>&1 || true
  "${tmuxenv[@]}" ./tmux -f /dev/null -L mfcheck new-session -d -s mfcheck -- "${JB}/bin/sh"
  "${tmuxenv[@]}" ./tmux -f /dev/null -L mfcheck list-sessions | grep -q mfcheck
  "${tmuxenv[@]}" ./tmux -f /dev/null -L mfcheck kill-server
}

package_tmux() {
  cd "${srcdir}" || return 1
  ldid -S"${ENTFILE}" ./tmux
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/man/man1" \
    "${pkgdir}${JB}/usr/share/licenses/tmux-3.7"
  install -m755 ./tmux "${pkgdir}${JB}/usr/bin/tmux-3.7"
  install -m644 ./tmux.1 "${pkgdir}${JB}/usr/share/man/man1/tmux-3.7.1"
  install -m644 ./COPYING "${pkgdir}${JB}/usr/share/licenses/tmux-3.7/"
}

package_default() {
  install -d "${pkgdir}${JB}/usr/bin" \
    "${pkgdir}${JB}/usr/share/man/man1"
  ln -s tmux-3.7 "${pkgdir}${JB}/usr/bin/tmux"
  ln -s tmux-3.7.1 "${pkgdir}${JB}/usr/share/man/man1/tmux.1"
}
