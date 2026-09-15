# zig

ソースツリー: [`packages/zig`](../packages/zig)

Zig 0.16.0（stable, 2026-04-13）を rootless 脱獄 iOS（`iphoneos-arm64`）向けに
パッケージする。目標は端末上で `zig build` / `zig build-exe` が `aarch64-ios`
向けに通ること。**`zig cc` をシステム CC として据えることはしない**
（Mayflower の CC は clang / `bin/cc` ラッパーのまま）。

## Chosen version and why

| 候補 | 判定 |
|------|------|
| **0.16.0 stable** | **採用。** 2026-04-13 リリース。公式バイナリあり。LLVM 21 同梱。 |
| 0.17.0-dev（master） | 不採用。日次で ABI / std.Io が動く。apt 向けには不安定。 |

## Scope

### In scope

- 端末に入った `zig` ホストで:
  - `zig version`
  - `zig build-exe hello.zig -target aarch64-ios`（純 Zig）
  - `zig build`（同じく純 Zig）
- 出力 Mach-O を **ldid + entitlements** で署名（Go / Rust / Nim と同じ）。
- パッケージ名は `zig`。

### Out of scope

- **`zig cc` / `zig c++` をシステム CC 化**すること。
- App Store 向けコードサイン / バンドル。
- Simulator（`aarch64-ios-simulator`）。
- 端末上での LLVM フルブートストラップ。

## Critical finding: self-hosted Mach-O → SIGILL on device

Verified on ip8:

| 経路 | 結果 |
|------|------|
| Zig self-hosted Mach-O link（素の 0.16.0） | **SIGILL**（`udf` at `_main`） |
| `zig build-obj` + Xcode clang/ld + `ldid` | **hello が動く** |

だから Mayflower の Zig は **ios device**（`os.tag == .ios` かつ `abi != .simulator`）の
最終リンクを **システム clang（→ ld）に委譲**し、そのあと **ldid を最後に**呼ぶ。

## Mayflower link / sign patch（`packages/zig/patches/src_link_MachO.zig.patch`）

適用先: Zig 0.16.0 ソースツリー（`src/link/MachO.zig` の `flush`）。

### 振る舞い

1. `flush` で early `zo.flush` / `isStaticLib` / `isObject` のあと、
   **ios device** かつ出力が **Exe または dynamic Lib** なら
   `flushMayflowerIosDevice` を呼んで return（self-hosted リンク本体をスキップ）。
2. Mayflower 経路:
   - `clang` を PATH から起動（`-target arm64-apple-ios{min}`、objects、
     `-lSystem`、frameworks、`-isysroot`、`-o out`。`dumpArgv` に近い中身）。
   - **子環境に `CLANG_NO_LDID` / `LLD_NO_LDID` はセットしない。**
     二重署名は許容。抑止したいときは利用者が自分で env を付ける
     （それらのフラグは Mayflower の clang/lld 側のもので、言語 toolchain のフラグではない）。
   - clang 成功後に **`ldid` を最後に**実行。
   - **compiler_rt:** Apple ld may reject zig-packed `libcompiler_rt.a`
     (`ld: 64-bit mach-o member 'libcompiler_rt_zcu.o' not 8-byte aligned`).
     Mayflower prefers `compiler_rt_obj` (the zcu `.o`) for the system-clang
     ios-device path; falls back to `compiler_rt_lib` only when the `.o` is absent.
     GHA CI ld may still accept the `.a`.
3. Entitlements（Go の `GO_LDID_ENTITLEMENTS` 流儀）:
   - `ZIG_LDID_ENTITLEMENTS` が **非空** → `ldid -S$path`
   - `ZIG_LDID_ENTITLEMENTS` が **空文字** → 署名スキップ（任意・Go 互換）
   - 未設定 → `zig` lib 隣 / 既知 Mayflower パスの `entitlements.plist`、
     無ければ `ldid -S`
4. **`ZIG_NO_LDID` は作らない。** Go/Rust にも言語側 `*_NO_LDID` は無い。

Simulator と静的ライブラリ / `.o` は従来どおり self-hosted。

### なぜ「最後」か（rewrite 経路）

素の Zig self-hosted Mach-O はリンク後にイメージを書き換える:

| 段階 | 場所 | 何をする |
|------|------|----------|
| dSYM / debug | `MachO/DebugSymbols.zig` `flush` | デバッグ束・関連書き換え |
| UUID | `MachO.writeUuid` | `LC_UUID` 再計算 |
| ad-hoc codesig | `MachO.writeCodeSignature`（`requiresCodeSig` 時） | コード署名パディング込みで最後に書く |

Go のコメントと同じく、**dsymutil / strip / uuid / codesig のあとに署名しないと無効化される。**
Mayflower 経路では self-hosted のこれらの段階を踏まず、clang/ld の出力に対して
Zig が **ldid を最終ステップ**にする。

（参考: Mayflower clang/lld もリンク後や dsymutil 後に ldid する。
Zig が clang を呼ぶと二重 ldid になり得るが **問題ない**。
Swift の `*_NO_LDID` / wrapper は例外で、Go/Rust/Zig のモデルではない。）

### 他言語との対応

| 言語 | 差し込み | env |
|------|----------|-----|
| Go | `cmd/link` 外部リンク後（dsymutil/uuid/codesig の後） | `GO_LDID_ENTITLEMENTS`（空で skip） |
| Rust | `link.rs` の最後（dsymutil/strip/archive の後） | `RUST_LDID_ENTITLEMENTS` |
| Nim | `extccomp` の dsymutil の直後 | nim.cfg `ldid.entitlements` |
| clang/lld | Darwin リンク / dsymutil 後 | `CLANG_NO_LDID` / `LLD_NO_LDID`（抑止専用） |
| **Zig** | `MachO.flush` の ios-device 分岐 → clang → **ldid last** | **`ZIG_LDID_ENTITLEMENTS`** |

## Build-time dependencies（Mac）

| 依存 | 用途 |
|------|------|
| Zig 0.16.0 `aarch64-macos` 公式 tarball | host ブートストラップ |
| ソース `zig-0.16.0` + 本パッチ | patched host zig |
| Xcode / iPhoneOS SDK | `aarch64-ios` リンク用 sysroot / libc kit |
| `ldid` + Mayflower `entitlements.plist` | 出力署名（および配布 zig 自身） |

## Runtime Depends（apt 案）

```
Depends: build-essential, ldid, libiosexec1 (>= 1.3.1)
Recommends: clang-19 | clang, ld64
Suggests: llvm-19 | llvm
```

## First smoke（母艦 → ip8）

```sh
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH"
ZIG=~/dev/zig-smoke/zig-mayflower-prefix/bin/zig   # patched build prefix
SDK=~/Downloads/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS*.sdk
ENT=~/dev/Mayflower/entitlements.plist

# libc kit / sysroot は既存の zig-smoke 手順に合わせる
ZIG_LDID_ENTITLEMENTS="$ENT" \
  "$ZIG" build-exe hello.zig -target aarch64-ios -mcpu=apple_a11 \
  --sysroot "$SDK" --libc ...

# 署名は patched zig が済み。確認:
ldid -e ./hello | grep -i platform-application

# 端末へ（ha 経由）
ssh ha "ssh ip8 'cat > ~/hello && chmod +x ~/hello && ~/hello'" < ./hello
# 期待: hello
```

`CLANG_NO_LDID` が既に環境にあってもよい（利用者が付けた場合）。Zig は付けない。

## Scaffold / patch status

- `docs/zig.md`（本ファイル）
- `packages/zig/make.sh` — `ZIG_DIST_DIR` 受けの Rust 流儀スケルトン
- `packages/zig/deb/DEBIAN/control`
- `packages/zig/README.md`
- **`packages/zig/patches/src_link_MachO.zig.patch`** — ios device → clang → ldid last

母艦適用・ビルド・ip8 煙・`zig-0.16-wip` への commit/push は
`scripts/mac-apply-zig-mayflower.sh` を参照（executor に `Shell(machineId=…)` が無い場合は
親が Mac mini で実行する）。

**zls は後回し。** `ZIG_NO_LDID` は導入しない。

## Host rebuild note (Mac mini 8GB)

Patched stage3 `zig` with LLVM on an 8GB Mac mini is not practical today:

- `zig build` without `-Denable-llvm` produced a ~24MB host `zig` that OOM-kills
  (`exit 137`) even on an empty native `build-exe`.
- Full LLVM-enabled stage3 link is expected to need more RAM than this machine has.
- Do not treat Grok Bot local-exec as the root cause; Latitude→SSH does not add RAM.

Validated smoke (2026-09-15, ip8): official `zig-aarch64-macos-0.16.0` `build-obj`
→ system `clang -target arm64-apple-ios… -isysroot iPhoneOS.sdk -lSystem` →
`ldid -Sentitlements.plist` last → device printed `hello` (`exit 0`).
That is the same link/sign order the MachO patch encodes; in-process patched
`build-exe` still waits for a host with enough RAM (or an ios-host package build).

## CI: patched LLVM stage3 on GitHub Actions

Mac mini (8GB) OOMs when linking LLVM into Zig. Use workflow
[`.github/workflows/zig-mayflower-macos.yml`](../.github/workflows/zig-mayflower-macos.yml):

- Runner: `macos-15` (~14GB+)
- `brew install llvm@21 lld@21` + CMake/Ninja
- Apply `packages/zig/patches/src_link_MachO.zig.patch`
- Build/install stage3, smoke `build-exe -target aarch64-ios` (clang + ldid path)
- Upload `zig-mayflower-0.16.0-aarch64-macos` artifact

GHA macos-15 reports ~7.5GiB free while Zig LLVM stage3 declares `max_rss = 8GiB`; the workflow passes `-DZIG_EXTRA_BUILD_ARGS=--maxrss;8000000000` so the build may proceed (OOM risk remains).

Trigger: `workflow_dispatch`, or push/PR touching `packages/zig/**` on `zig-0.16-wip`.

## ios dyld stubs

`std.debug.SelfInfo` references `_dyld_get_image_header_containing_address` /
`_dyld_image_path_containing_address`, which headers mark `__API_UNAVAILABLE`
on ios. System `ld` then fails Mayflower's clang link for Exe/dylib that pull
in SelfInfo (e.g. `std.debug.print` panic paths).

The MachO patch compiles a tiny C stub (NULL returns) into the local cache and
links it before `-lSystem`. Stack traces that need those APIs get
`MissingDebugInfo` instead of a link error.
