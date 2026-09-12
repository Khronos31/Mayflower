# ip8 LLVM/Clang status (2026-09-12)

Snapshot after Mayflower Clang/LLVM 19 cutover on the jailbroken iPhone 8
(`ha` → `ssh ip8`). Work files under `$HOME` (not `/tmp`).

## Installed (Mayflower 19.1.4-7)

- versioned/libs: `libllvm19`, `libclang-cpp19`, `libclang1-19`,
  `libclang-common-19-dev`, `llvm-19-linker-tools`, `lld-19`, `llvm-19`,
  `llvm-19-dev`, `libc++-19-dev`, `clang-19`
- metas: `clang-default`, `llvm-default`, `lld`, `llvm-dev`, `libc++-dev`

## Removed

Procursus `libllvm16`, `clang-16`, `libclang-cpp16`, `libclang-common-16-dev`,
`libc++-16-dev`, `llvm-16`, `llvm-16-dev`, `llvm-16-linker-tools`,
`llvm-16-runtime`, `swift`, `swift-5.9.2`.

## apt-mark

- `build-essential` → **manual** (do not autoremove; SDK / compile baseline)

## Notes

- Dist tarball: `~/dev/toolchain-swift-6.1/dist/llvm-19.1.4-swift-6.1.1-aarch64-apple-ios.tar.xz`
- Branch: `swift-6.1-clang-19`
- Swift 6.1 package still deferred (`packages/swift` scaffold only)
