# packages/swift

Swift 6.1.1 for jailbroken iOS (`iphoneos-arm64`), installed under the
`llvm-19` prefix (shared install names with clang-19).

## Packages

| Deb | Role |
|---|---|
| `libswift-6.1` | Runtime dylibs |
| `swift-6.1` | Compiler + host plugins + `mayflower-swift-ld` |
| `swift-6.1-dev` | Modules / headers |
| `swift-default` | Unversioned `swift` / `swiftc` → 6.1 |

Fat IDE/test tools (`swift-ide-test`, …) are not packaged.

## Build (device)

```sh
export SWIFT_DIST_DIR=/path/to/dist   # contains swift-6.1.1-aarch64-apple-ios.tar.xz
./make.sh swift
```

## ldid matrix

```sh
export CLANG_NO_LDID=1 LLD_NO_LDID=1
bash packages/swift/tests/ldid-matrix.sh
```

Signing skip for the Swift path is `SWIFT_NO_LDID` only.
