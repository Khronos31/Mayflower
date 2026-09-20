# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034
#
# Mayflower | packages/perl/make.sh
#
# perl 5.42 を rootless 脱獄 iOS 上でセルフビルドする。
# Procursus は perl 5.32.1（libiosexec 依存）。同名は使わず
# perl5.42 + perl-default（Conflicts/Replaces: perl）にする。
#
# system/exec/open-pipe は fork+exec。シェルは Configure -Dsh で
# /var/jb/bin/sh。shebang の execvp は doio.c で EPERM/ENOENT/ENOEXEC
# を同じ sh 経由で再試行する。libiosexec は付けない。
#
# ビルドは palera1n（ip8）、成果物の subprocess 確認は Dopamine（se3）。

pkgname=perl
pkgver=5.42.0
pkgrel=1
srcname="perl-${pkgver}"
source="https://www.cpan.org/src/5.0/perl-${pkgver}.tar.xz"
subpkgs=(main default)

perlseries=5.42
COMMON_FLAGS="-target arm64-apple-ios16.0"

prepare() {
  cd "${srcdir}" || return 1
  chmod -R u+w .
}

build() {
  cd "${srcdir}" || return 1

  # Darwin ヒントが MACOSX_DEPLOYMENT_TARGET を足すと clang が
  # iPhoneOS SDK を macOS 向けに読む。-target で押さえる。
  env -u MACOSX_DEPLOYMENT_TARGET -u SDKROOT \
  "${CONFIG_SHELL}" ./Configure -des \
    -Dprefix="${JB}/usr" \
    -Dprivlib="${JB}/usr/lib/perl5/${perlseries}" \
    -Darchlib="${JB}/usr/lib/perl5/${perlseries}" \
    -Dsitelib="${JB}/usr/lib/perl5/site_perl" \
    -Dsitearch="${JB}/usr/lib/perl5/site_perl" \
    -Dvendorprefix="${JB}/usr" \
    -Dvendorlib="${JB}/usr/share/perl5" \
    -Dvendorarch="${JB}/usr/lib/perl5/vendor_perl" \
    -Dman1dir="${JB}/usr/share/man/man1" \
    -Dman3dir="${JB}/usr/share/man/man3" \
    -Dsh="${JB}/bin/sh" \
    -Dtargetsh="${JB}/bin/sh" \
    -Dcc=clang \
    -Dld=clang \
    -Dccflags="${COMMON_FLAGS} -O2 -fno-common -DPERL_DARWIN" \
    -Dldflags="${COMMON_FLAGS} -Wl,-rpath,${JB}/usr/lib" \
    -Dlddlflags="${COMMON_FLAGS} -dynamiclib -Wl,-undefined,dynamic_lookup -Wl,-rpath,${JB}/usr/lib" \
    -Dlibs='-lgdbm' \
    -Ud_crypt \
    -Ui_crypt \
    -Duseshrplib \
    -Dlibperl=libperl.dylib \
    -Dusethreads \
    -Duse64bitall \
    -Dosname=darwin \
    -Darchname=aarch64-darwin \
    -Uusedevel \
    -Duselargefiles \
    -Dd_fork=define \
    -Ud_syscall \
    -Ud_pause \
    -Ud_setitimer \
    -Ud_getitimer

  make -j"$(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || echo 4)"
}

check() {
  cd "${srcdir}" || return 1
  DYLD_LIBRARY_PATH="${srcdir}" ./perl -Ilib -e '
    die "version" unless $^V eq v5.42.0;
    print "version $]\n";
    die "system-shell" if system("echo system-shell-ok") != 0;
    my $sh = `echo shell-ok`;
    chomp $sh;
    die "backtick $sh" unless $sh eq "shell-ok";
    open my $fh, "-|", "/var/jb/bin/sh", "-c", "echo pipe-ok" or die $!;
    my $p = <$fh>;
    chomp $p;
    die "pipe $p" unless $p eq "pipe-ok";
    close $fh;
  '
  local t
  t="$(mktemp "${TMPDIR:-/var/jb/tmp}/perl-shebang.XXXXXX")"
  printf '%s\n' '#!/bin/sh' 'echo shebang-ok' > "$t"
  chmod 755 "$t"
  DYLD_LIBRARY_PATH="${srcdir}" ./perl -Ilib -e '
    my $t = $ARGV[0];
    my $out = `$t`;
    chomp $out;
    die "shebang `$out`" unless $out eq "shebang-ok";
    print "shebang $out\n";
  ' "$t"
  rm -f "$t"
}

package_main() {
  cd "${srcdir}" || return 1
  make DESTDIR="${pkgdir}" install
  local b="${pkgdir}${JB}/usr/bin"
  # 版なしの名前は perl-default の持ち物（Procursus perl 5.32 と同居できる）
  if [ -e "${b}/perl" ] && [ ! -e "${b}/perl${perlseries}" ]; then
    mv "${b}/perl" "${b}/perl${perlseries}"
  else
    rm -f "${b}/perl"
  fi
  rm -f "${b}/perl${pkgver}"
  ln -sf "perl${perlseries}" "${b}/perl${pkgver}" 2>/dev/null || true
  local n
  for n in "${b}"/*; do
    [ -e "$n" ] || continue
    case "$(basename "$n")" in
      perl${perlseries}|perl${pkgver}) ;;
      *) rm -f "$n" ;;
    esac
  done
  install -d "${pkgdir}${JB}/usr/share/licenses/perl"
  install -m644 Artistic Copying README "${pkgdir}${JB}/usr/share/licenses/perl/" 2>/dev/null || true
  [ -e "${b}/perl${perlseries}" ] || { echo "package_main: perl${perlseries} が無い" >&2; return 1; }

  local libp="${pkgdir}${JB}/usr/lib/perl5/${perlseries}/CORE/libperl.dylib"
  local coreid="${JB}/usr/lib/perl5/${perlseries}/CORE/libperl.dylib"
  if [ -e "$libp" ]; then
    install_name_tool -id "$coreid" "$libp"
    install_name_tool -change '@rpath/libperl.dylib' "$coreid" "${b}/perl${perlseries}" || true
    find "${pkgdir}${JB}/usr/lib/perl5" -name '*.bundle' -print0 2>/dev/null \
      | xargs -0 -n 1 install_name_tool -change '@rpath/libperl.dylib' "$coreid" 2>/dev/null || true
    ldid -S"${ENTFILE}" "$libp" "${b}/perl${perlseries}"
    find "${pkgdir}${JB}/usr/lib/perl5" -name '*.bundle' -print0 2>/dev/null \
      | xargs -0 -n 1 ldid -S"${ENTFILE}" 2>/dev/null || true
  fi
}

package_default() {
  local b="${pkgdir}${JB}/usr/bin"
  install -d "${b}"
  ln -s "perl${perlseries}" "${b}/perl"
}
