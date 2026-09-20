# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034  # 変数は ../../make.sh が読む/export する
#
# Mayflower | packages/ruby/make.sh
#
# CRuby 4.0.6 を rootless 脱獄 iOS 上でセルフビルドする。
#
# **darwin として建てる。** `uname -m` が iPhone10,1 を返すので config.guess
# は当てにならない。--build を明示する。coroutine は arm64 アセンブリ
# （configure が arm64-darwin なら同じものを選ぶ）。
#
# YJIT / ZJIT は建てない。端末に rustc があると configure が既定で両方を
# 有効にするので、明示して切る。あとで足す余地はある。
#
# Procursus に ruby は無いので、同名を避ける必要はない。

pkgname=ruby
pkgver=4.0.6
pkgrel=2
srcname="ruby-${pkgver}"
source="https://cache.ruby-lang.org/pub/ruby/4.0/ruby-${pkgver}.tar.xz"

# **-target を明示しないと macOS モードで建ってしまう。** Python と同じ。
COMMON_FLAGS="-target arm64-apple-ios16.0"

# vm_dump.c の RUBY_ON_BUG が system(3) を呼ぶ。iOS SDK では unavailable。
ios_compat=1

prepare() {
  cd "${srcdir}" || return 1
}

build() {
  cd "${srcdir}" || return 1

  # getentropy は iOS ヘッダで API_UNAVAILABLE。configure のリンク試験は通るが
  # コンパイルで未宣言になる（Python と同じ）。
  # Ruby の configure は -target / -lmayflower_spawn 等が混ざると
  # 「something wrong with LDFLAGS」で落ちる。一方 -L だけだと conftest 実行時に
  # @rpath/libgmp が解決できず sizeof 計算が死ぬ。-L と -Wl,-rpath だけ渡す。
  local _ldflags_save="${LDFLAGS}"
  export LDFLAGS="-L${JB}/usr/lib -Wl,-rpath,${JB}/usr/lib"

  ac_cv_func_getentropy=no \
  ac_cv_func_clock_settime=no \
  "${CONFIG_SHELL}" configure \
    --build=aarch64-apple-darwin \
    --prefix="${JB}/usr" \
    --enable-shared \
    --with-coroutine=arm64 \
    --disable-yjit \
    --disable-zjit \
    --disable-dtrace \
    --disable-install-doc \
    --disable-install-rdoc

  export LDFLAGS="${_ldflags_save}"

  # configure が Makefile に焼いた LDFLAGS は最小値のまま。さらに Apple ld は
  # オブジェクトより前に置いた -lstatic を引き込まないので、-lios_compat だけでは
  # miniruby で _mayflower_system が未定義のままになる。force_load で必ず入れる。
  {
    printf '\n# Mayflower: after configure\n'
    printf 'LDFLAGS += %s\n' "${_ldflags_save}"
    printf 'LIBS += -Wl,-force_load,%s/libios_compat.a\n' "${BUILDROOT}"
  } >> Makefile

  # mkmf / libruby-static 用にもオブジェクトを COMMONOBJS へ
  cp "${ROOTDIR}/compat/ios_compat.c" .
  printf '\nCOMMONOBJS += ios_compat.$(OBJEXT)\n' >> Makefile
  make ios_compat.o

  make -j"$(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || echo 4)"
}

check() {
  cd "${srcdir}" || return 1
  # 建てた ruby が動き、シェルと Fiber が使えるかを見る。YJIT は入っていない。
  DYLD_LIBRARY_PATH="${srcdir}" ./ruby \
    -I.ext/arm64-darwin -I.ext/common -Ilib -e '
    raise "yjit" if defined?(RubyVM::YJIT) && RubyVM::YJIT.respond_to?(:enabled?) && RubyVM::YJIT.enabled?
    raise "zjit" if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.respond_to?(:enabled?) && RubyVM::ZJIT.enabled?
    puts "version #{RUBY_VERSION}"
    puts "platform #{RUBY_PLATFORM}"
    f = Fiber.new { Fiber.yield "ok" }
    puts "fiber   #{f.resume}"
    puts "system  #{system("echo", "system-ok")}"
    puts "shell   #{`echo shell-ok`.strip}"
    # Dopamine: fork+execve of a shebang script (mayflower_spawn fishhook)
    sh = "#{ENV.fetch("HOME")}/mayflower-rb-shebang.sh"
    File.write(sh, "#!/var/jb/bin/sh\necho rb-shebang-ok\n")
    File.chmod(0755, sh)
    out = IO.popen([sh], &:read)
    raise "shebang failed: #{out.inspect}" unless out.include?("rb-shebang-ok")
    puts "shebang #{out.strip}"
    require "openssl"; puts "ssl     #{OpenSSL::OPENSSL_VERSION}"
    require "yaml";    puts "yaml    ok"
    require "zlib";    puts "zlib    ok"
  '
}

package() {
  cd "${srcdir}" || return 1
  make DESTDIR="${pkgdir}" install

  install -d "${pkgdir}${JB}/usr/share/licenses/ruby"
  install -m644 COPYING BSDL "${pkgdir}${JB}/usr/share/licenses/ruby/" 2>/dev/null || \
    install -m644 COPYING "${pkgdir}${JB}/usr/share/licenses/ruby/"

  local f
  for f in bin/ruby lib/libruby.dylib; do
    if [ ! -e "${pkgdir}${JB}/usr/${f}" ]; then
      # 共有ライブラリの実名は libruby.4.0.dylib など。どれかがあればよい。
      case "$f" in
        lib/libruby.dylib)
          ls "${pkgdir}${JB}/usr/lib"/libruby*.dylib >/dev/null 2>&1 || {
            echo "package: libruby*.dylib が無い" >&2
            return 1
          }
          ;;
        *)
          echo "package: ${f} が無い" >&2
          return 1
          ;;
      esac
    fi
  done
}
