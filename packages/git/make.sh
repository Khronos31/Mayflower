# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/git/make.sh
#
# Git 2.55.0 を rootless 脱獄 iOS 上でセルフビルドする。
# Procursus の git は 2.39.1（Package: git）。同名は Pin-Priority 1001 で
# 負けるので、本体は git-2.55、版なし git は git-default が
# Provides/Conflicts/Replaces: git する。
#
# gitexecdir は /usr/libexec/git-core にしない。Procursus と同居できるよう
# /usr/libexec/git-2.55 に置く。gettext / Tcl/Tk / expat は使わない。

pkgname=git
pkgver=2.55.0
pkgrel=2
srcname="git-${pkgver}"
source="https://www.kernel.org/pub/software/scm/git/git-${pkgver}.tar.xz"
subpkgs=(git default)
export compress=xz

git_make() {
  make -j"${MAKE_JOBS:-1}" \
    prefix="${JB}/usr" \
    gitexecdir="${JB}/usr/libexec/git-2.55" \
    template_dir="${JB}/usr/share/git-2.55/templates" \
    sysconfdir="${JB}/etc" \
    CC="${CC}" \
    AR="${AR}" \
    RANLIB="${RANLIB}" \
    CFLAGS="${CFLAGS}" \
    LDFLAGS="${LDFLAGS}" \
    CURLDIR="${JB}/usr" \
    OPENSSLDIR="${JB}/usr" \
    PERL_PATH="${JB}/usr/bin/perl" \
    SHELL_PATH="${JB}/bin/sh" \
    perllibdir="${JB}/usr/share/perl5/Git-2.55" \
    NO_TCLTK=YesPlease \
    NO_GETTEXT=YesPlease \
    NO_EXPAT=YesPlease \
    NO_INSTALL_HARDLINKS=YesPlease \
    USE_LIBPCRE2=YesPlease \
    INSTALL_SYMLINKS=YesPlease \
    "$@"
}

prepare() {
  cd "${srcdir}" || return 1
  # iOS has no FSEvents. config.mak.uname は Darwin なら darwin バックエンドを
  # 選ぶ。config.mak はそれより後に読まれる。
  cat >> config.mak <<'EOF'
FSMONITOR_DAEMON_BACKEND =
FSMONITOR_OS_SETTINGS =
# t/helper は system(3) を使う。本体の install には不要。
TEST_BUILTINS_OBJS =
TEST_PROGRAMS_NEED_X =
TEST_PROGRAMS =
UNIT_TEST_PROGRAMS =
UNIT_TEST_PROGS =
FUZZ_OBJS =
FUZZ_PROGRAMS =
NO_GITWEB = YesPlease
EOF
}

build() {
  cd "${srcdir}" || return 1
  git_make all
}

check() {
  local bin="${srcdir}/git"
  ldid -S"${ENTFILE}" "${bin}"
  GIT_EXEC_PATH="${srcdir}" "${bin}" --version
}

package_git() {
  cd "${srcdir}" || return 1
  git_make DESTDIR="${pkgdir}" install
  local b="${pkgdir}${JB}/usr/bin"
  local e="${pkgdir}${JB}/usr/libexec/git-2.55"
  # make install は libexec/git を ../../bin/git への symlink にする。
  # argv0 が git-2.55 だと本体が subcommand "2.55" と取るので、
  # 実体は libexec に Mach-O のまま置き、bindir はラッパー。
  rm -f "${e}/git"
  cp -p "${b}/git" "${e}/git"
  ldid -S"${ENTFILE}" "${e}/git"
  local p
  for p in "${e}"/git-*; do
    [ -L "${p}" ] || continue
    case "$(readlink "${p}")" in
      *bin/git|git) ln -sf git "${p}" ;;
    esac
  done
  rm -f "${b}/git"
  . "${ROOTDIR}/files/mayflower-exec.sh"
  mayflower_install_exec "${b}/git-2.55" "${JB}/usr/libexec/git-2.55/git"
  local x
  for x in git-shell git-cvsserver scalar git-receive-pack git-upload-pack git-upload-archive; do
    if [ -L "${b}/${x}" ]; then
      rm -f "${b}/${x}"
    elif [ -e "${b}/${x}" ]; then
      mv "${b}/${x}" "${b}/${x}-2.55"
    fi
  done
}

package_default() {
  install -d "${pkgdir}${JB}/usr/bin"
  ln -s git-2.55 "${pkgdir}${JB}/usr/bin/git"
  ln -s git-2.55 "${pkgdir}${JB}/usr/bin/git-receive-pack"
  ln -s git-2.55 "${pkgdir}${JB}/usr/bin/git-upload-pack"
  ln -s git-2.55 "${pkgdir}${JB}/usr/bin/git-upload-archive"
  ln -s git-shell-2.55 "${pkgdir}${JB}/usr/bin/git-shell"
  ln -s git-cvsserver-2.55 "${pkgdir}${JB}/usr/bin/git-cvsserver"
  ln -s scalar-2.55 "${pkgdir}${JB}/usr/bin/scalar"
}
