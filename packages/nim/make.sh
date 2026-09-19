# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034  # 変数は ../../make.sh が読む/export する
#
# Mayflower | packages/nim/make.sh
#
# Nim を rootless 脱獄 iOS 上でセルフビルドする。要点は3つ:
#
# 1. entitlements 付きの ldid 署名が無いと、出来た実行ファイルは起動時に
#    SIGKILL される。パッチで nim 自身がリンク後に署名するようにし、
#    ブートストラップ段だけは bin/cc ラッパーが肩代わりする。
# 2. rootless に /bin/sh は無い。libiosexec の ie_system / ie_exec* /
#    ie_posix_spawn へ差し替える（patches/）。
# 3. csources 版コンパイラは並列ビルドで startProcess 経由の /bin/sh を
#    呼ぶため --parallelBuild:1 が要る。直列なら system() ＝ シム経由。

pkgname=nim
pkgver=2.2.12
pkgrel=3

# nightly（2.2.12 は正式リリース前のため nim-lang.org/download には無い）
source="https://github.com/nim-lang/nightlies/releases/download/2026-09-08-version-2-2-8e8fbf60693418dc95bb0d762fd660231d08a583/nim-${pkgver}.tar.xz"

# 既に nim が入っていればそれを種にする（warm）。無ければ同梱の C ソースから
# 立ち上げる（cold）。cold では system(3) が iOS SDK で unavailable なうえ
# /bin/sh も無いため、shim/ios_system.c を -include で差し込む。
prepare() {
  cd "${srcdir}" || return 1

  if command -v nim >/dev/null 2>&1; then
    echo "==> 既存の nim を種にする: $(command -v nim)"
    install -m755 "$(command -v nim)" bin/nim
    return
  fi

  echo "==> csources からブートストラップする"
  clang -O2 -c "${PROJECTROOT}/shim/ios_system.c" -o "${BUILDROOT}/ios_system.o"

  # uname -m が iPhone10,1 を返すので ucpu/uos は手で与える。
  # makefile は darwin 節で CC を固定するため、CC は環境ではなく引数で渡す。
  local cold_ld="${BUILDROOT}/ios_system.o"
  if [ -f "${BUILDROOT}/libmayflower_spawn.a" ]; then
    cold_ld="${cold_ld} -L${BUILDROOT} -lmayflower_spawn -liosexec"
  fi
  CFLAGS="-include ${PROJECTROOT}/shim/ios_system.h" \
  LDFLAGS="${cold_ld}" \
    make -j"$(sysctl -n hw.ncpu)" \
      ucpu=arm64 uos=darwin \
      SHELL="${JB}/bin/sh"

  ldid -S"${ENTFILE}" bin/nim
}

build() {
  cd "${srcdir}" || return 1

  # --clang.linkerexe は cold 用（csources 版には ldid ステップが無い）。
  # warm でも害は無い（ldid を二重に当てるだけ）。
  local flags=(
    --os:ios
    --cpu:"${ARCH}"
    -d:release
    --parallelBuild:1
    --clang.linkerexe:"${ROOTDIR}/bin/cc"
    --ldid.entitlements:"${ENTFILE}"
  )
  # 端末ビルドで make.sh が用意した mayflower_spawn を nim / tools に静的リンク。
  # 明示 ie_* に加え、素の posix_spawn/execve 呼び出しも fishhook する。
  if [ -f "${BUILDROOT}/libmayflower_spawn.a" ]; then
    flags+=(--passL:"-L${BUILDROOT} -lmayflower_spawn -liosexec")
  fi

  ./bin/nim c "${flags[@]}" koch
  ./koch boot "${flags[@]}"
  ./koch tools -d:release --ldid.entitlements:"${ENTFILE}"
}

# 素の nim が使えるか（ラッパー無し・並列ビルド既定）を実際に確かめる。
check() {
  local nim="${srcdir}/bin/nim"
  local work="${BUILDROOT}/check"

  rm -rf "${work}"
  mkdir -p "${work}"
  cp "${PROJECTROOT}"/test/* "${work}"
  chmod +x "${work}/t.sh"
  cd "${work}" || return 1

  # exec 系: execShellCmd / execCmdEx / shebang スクリプトの startProcess
  "${nim}" c --hints:off --ldid.entitlements:"${ENTFILE}" t_exec.nim
  ./t_exec

  # dynlib: rpath 経由で libssl.3 / libcrypto.3 を dlopen できるか
  "${nim}" c --hints:off -d:ssl --ldid.entitlements:"${ENTFILE}" t_ssl.nim
  ./t_ssl

  # pcre: nimgrep が libpcre.1.dylib を掴めるか
  "${srcdir}/bin/nimgrep" --version >/dev/null
}

# 自己完結した prefix を /var/jb/usr/lib/nim に置き、/var/jb/usr/bin からは
# 相対シンボリックリンクを張る。nim は getAppFilename() の realpath の親の親を
# prefix にするため（/usr → /usr/lib/nim の特例は /var/jb/usr には効かない）、
# bin を直接 /var/jb/usr/bin に置くと lib も config も見失う。
package() {
  cd "${srcdir}" || return 1

  local prefix="${pkgdir}${JB}/usr"
  local nimdir="${prefix}/lib/nim"
  local sharedir="${prefix}/share"

  install -d "${nimdir}" "${prefix}/bin" "${sharedir}/nim" \
             "${sharedir}/licenses/nim" \
             "${sharedir}/bash-completion/completions" \
             "${sharedir}/zsh/site-functions"

  cp -R bin lib config compiler doc "${nimdir}/"
  rm -rf "${nimdir}/doc/html"
  rm -f "${nimdir}/bin/nim-gdb"   # gdb と tools/debug を同梱しないため

  local b
  for b in atlas nim nim_dbg nimble nimgrep nimpretty nimsuggest testament; do
    [ -x "${nimdir}/bin/$b" ] || { echo "package: bin/$b が無い" >&2; return 1; }
    ln -s "../lib/nim/bin/$b" "${prefix}/bin/$b"
  done

  # nim.cfg の ldid.entitlements 既定値がこのパスを指している。
  install -m644 "${ROOTDIR}/entitlements.plist" "${sharedir}/nim/entitlements.plist"

  install -m644 copying.txt "${sharedir}/licenses/nim/copying.txt"
  install -m644 dist/nimble/license.txt "${sharedir}/licenses/nim/nimble-license.txt"

  local c
  for c in nim nimgrep nimpretty nimsuggest; do
    install -m644 "tools/$c.bash-completion" "${sharedir}/bash-completion/completions/$c"
  done
  install -m644 dist/nimble/nimble.bash-completion "${sharedir}/bash-completion/completions/nimble"
  install -m644 tools/nim.zsh-completion "${sharedir}/zsh/site-functions/_nim"
  install -m644 dist/nimble/nimble.zsh-completion "${sharedir}/zsh/site-functions/_nimble"

  find "${pkgdir}" -type d -exec chmod 755 {} +
  find "${pkgdir}" -type f -exec chmod 644 {} +
  chmod 755 "${nimdir}"/bin/*
}
