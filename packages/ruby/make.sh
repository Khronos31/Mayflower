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
#
# palera1n と Dopamine では configure の have_func が食い違う（Dopamine は
# shebang の posix_spawn が EPERM）。spawn の有無は検出に頼らず、脱獄では
# fork+exec が使える前提で cache を固定する。ビルドは palera1n（ip8）、
# 成果物の subprocess 確認は Dopamine（se3）。

pkgname=ruby
pkgver=4.0.6
pkgrel=3
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

  # ドライバの ios_compat.o は -target 無しで SDK 既定（16.2）になる。
  # ruby の configure は ld の「newer iOS version」警告を LDFLAGS 不正とみなす。
  clang -O2 ${CFLAGS} -c "${ROOTDIR}/compat/ios_compat.c" -o "${BUILDROOT}/ios_compat.o"
  rm -f "${BUILDROOT}/libios_compat.a"
  "${AR}" rcs "${BUILDROOT}/libios_compat.a" "${BUILDROOT}/ios_compat.o"

  # getentropy / clock_settime は iOS ヘッダで API_UNAVAILABLE。
  # fork は have_func に頼らない（Dopamine では試験バイナリの spawn が EPERM）。
  ac_cv_func_getentropy=no \
  ac_cv_func_clock_settime=no \
  ac_cv_func_fork=yes \
  ac_cv_func_fork_works=yes \
  ac_cv_func_vfork=no \
  ac_cv_func_vfork_works=no \
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

  # mkmf の have_func は -lruby-static でリンクする。mayflower_system が
  # 静的ライブラリに入っていないと、拡張の HAVE_* が全部落ちる。
  cp "${ROOTDIR}/compat/ios_compat.c" .
  printf '\nCOMMONOBJS += ios_compat.$(OBJEXT)\n' >> Makefile

  make -j"$(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || echo 4)"
}

check() {
  cd "${srcdir}" || return 1
  DYLD_LIBRARY_PATH="${srcdir}" ./ruby \
    -I.ext/arm64-darwin -I.ext/common -Ilib -e '
    raise "yjit" if defined?(RubyVM::YJIT) && RubyVM::YJIT.respond_to?(:enabled?) && RubyVM::YJIT.enabled?
    raise "zjit" if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.respond_to?(:enabled?) && RubyVM::ZJIT.enabled?
    puts "version #{RUBY_VERSION}"
    puts "platform #{RUBY_PLATFORM}"
    f = Fiber.new { Fiber.yield "ok" }
    puts "fiber   #{f.resume}"
    raise "system-array" unless system("echo", "system-ok")
    raise "system-shell" unless system("echo system-shell-ok")
    sh = `echo shell-ok`.strip
    raise "backtick #{sh.inspect}" unless sh == "shell-ok"
    pid = spawn("/var/jb/bin/sh", "-c", "exit 0")
    Process.wait(pid)
    raise "spawn" unless $?.success?
    require "open3"
    o, s = Open3.capture2("/var/jb/bin/sh", "-c", "echo open3-ok")
    raise "open3 #{o.inspect}" unless s.success? && o.strip == "open3-ok"
    require "pty"
    out = ""
    PTY.spawn("/var/jb/bin/sh", "-c", "echo pty-ok") do |r, w, p|
      out = r.gets.to_s.strip
      w.close
      Process.wait(p)
    end
    raise "pty #{out.inspect}" unless out.include?("pty-ok")
    shbang = "/var/tmp/mayflower-rb-shebang.sh"
    File.write(shbang, "#!/var/jb/bin/sh\necho rb-shebang-ok\n")
    File.chmod(0755, shbang)
    out = IO.popen([shbang], &:read)
    File.unlink(shbang) rescue nil
    raise "shebang #{out.inspect}" unless out.include?("rb-shebang-ok")
    puts "shebang #{out.strip}"
    require "openssl"; puts "ssl     #{OpenSSL::OPENSSL_VERSION}"
    require "yaml";    puts "yaml    ok"
    require "zlib";    puts "zlib    ok"
    puts "subprocess ok"
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
