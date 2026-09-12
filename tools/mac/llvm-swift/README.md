# Mac: Swift 6.1 / Clang 19 → iOS dist

iPhone 上では建てない。ここでクロスして tarball を作り、端末の
`packages/llvm/make.sh` が梱包する。

## 前提

- macOS + Xcode（iPhoneOS.sdk）
- `cmake` / `ninja` / `python3` / `xz`
- 空き容量に余裕（ソース + ビルドで数十 GB 見ておく）

## 使い方（概略）

```sh
export WORKDIR="$HOME/dev/toolchain-swift-6.1"
./tools/mac/llvm-swift/build.sh all
# Prefer building the artifacts we package (discover exact names after configure):
#   ninja -C "$WORKDIR/build/ios" -t targets | rg -i 'install.*(LLVM|clang|LTO|lld)'
ninja -C "$WORKDIR/build/ios" clang lld libLLVM LLVM clang-cpp libclang LTO \
  llvm-ar llvm-nm llvm-ranlib llvm-config dsymutil opt llc
./tools/mac/llvm-swift/build.sh libcxx    # headers-only runtimes → stage
./tools/mac/llvm-swift/build.sh install
./tools/mac/llvm-swift/build.sh pack
# => $WORKDIR/dist/llvm-19.1.4-swift-6.1.1-aarch64-apple-ios.tar.xz
```

### libc++ headers (`libcxx`)

Darwin/iOS の `libc++.dylib` は Apple のものを使う。必要なのは **Clang 19 用
ヘッダ**（`include/c++/v1`）。`build/ios` の既存 LLVM には runtimes ターゲットが
無いので、別ディレクトリ `$WORKDIR/build/ios-libcxx` で
`llvm-project/runtimes` を configure する:

- triple: `arm64-apple-ios16.0`、iphoneos SDK（clang 本体と同じ）
- コンパイラ: ホスト clang + `-target` + sysroot（`build/ios` の clang は
  iOS バイナリなので Mac では実行できない）
- `LIBCXX_OVERRIDE_DARWIN_INSTALL=ON`
- `LIBCXX_ENABLE_SHARED=OFF` / `LIBCXX_INSTALL_LIBRARY=OFF`（dylib を置かない）
- `DESTDIR=$WORKDIR/build/stage` へ `install-cxx-headers`（+ cxxabi / pstl）
- prefix: `/var/jb/usr/lib/llvm-19` → 成果は `include/c++`（clang が
  `InstalledDir/../include/c++/v1` を先に見る）

`install` は LLVM 本体を stage に入れたあと、同じ stage に libc++ ヘッダを
マージする。`pack` はそのまま tarball に含める。

### Reconfigure note (DYLIB)

`configure` now passes:

- `-DLLVM_BUILD_LLVM_DYLIB=ON`
- `-DLLVM_LINK_LLVM_DYLIB=ON`
- `-DCLANG_LINK_CLANG_DYLIB=ON`
- `-DCMAKE_INSTALL_NAME_DIR=/var/jb/usr/lib/llvm-19/lib`
- `-DCMAKE_INSTALL_RPATH=/var/jb/usr/lib/llvm-19/lib`

If `build/ios` was configured **without** these flags, `install` alone will not
produce `libLLVM.dylib`. Wipe and re-run configure:

```sh
rm -rf "$WORKDIR/build/ios"
./tools/mac/llvm-swift/build.sh configure
```

`install` refuses to proceed if `CMakeCache.txt` lacks `LLVM_BUILD_LLVM_DYLIB=ON`,
and fails if `libLLVM.dylib` is still missing after selective `install-*`.

### What `install` ships

Explicit `ninja install-*` (not full `install`):

- clang + resource headers (+ clang headers if target exists)
- lld
- llvm tools: ar nm ranlib config dsymutil opt llc objdump objcopy strip
  symbolizer cxxfilt size strings install-name-tool lipo
- shared: `libLLVM.dylib`, `libclang-cpp*`, `libclang`, `libLTO` (via
  `install-LLVM` / `install-clang-cpp` / `install-libclang` / `install-LTO` or
  discovered aliases)
- headers for llvm / llvm-c when install targets exist
- libc++ headers under `include/c++` (+ `__pstl*` / `pstl` if generated)
  via the separate `ios-libcxx` runtimes build (headers-only)

Swift ランタイム同梱は後続。`patches-host/*.patch` は `configure` / `all` 時に当たる。

端末（または Mac から `LLVM_DIST_DIR` を渡して）:

```sh
export LLVM_DIST_DIR=/path/to/dist
./make.sh llvm
```

## 版

| 項目 | 値 |
|---|---|
| Swift | 6.1.1-RELEASE |
| LLVM（CMake） | 19.1.4 |
| 三重項 | `arm64-apple-ios16.0`（要調整） |
| 接頭辞 | `/var/jb/usr/lib/llvm-19` |

Procursus の `llvm.mk`（Swift 同梱・二段ビルド・rootless prefix）を参考にしている。
