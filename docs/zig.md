# zig

ソースツリー: [`packages/zig`](../packages/zig)

Zig 0.16.0（stable, 2026-04-13）を rootless 脱獄 iOS（`iphoneos-arm64`）向けに
パッケージする調査メモ。目標は端末上で `zig build` / `zig build-exe` が
`aarch64-ios` 向けに通ること。**`zig cc` をシステム CC として据えることはしない**
（Mayflower の CC は clang / `bin/cc` ラッパーのまま）。

## Chosen version and why

| 候補 | 判定 |
|------|------|
| **0.16.0 stable** | **採用。** 2026-04-13 リリース。公式バイナリあり。LLVM 21 同梱。 |
| 0.17.0-dev（master） | 不採用。日次で ABI / std.Io が動く。apt 向けには不安定。 |

選定理由:

- Mayflower の他言語（Go 1.26 / Rust 1.98 / Nim 2.2）と同様、**stable 版固定**。
- 公式 `zig-aarch64-macos-0.16.0.tar.xz`（~50 MiB）と `zig-bootstrap-0.16.0.tar.xz`
  （~53 MiB）が揃っている。
- `aarch64-ios` は Tier 3（codegen / linker / std は ✅、**libc は ❌**、CI なし）。
  0.17-dev でも Tier は同じで、待つ理由が薄い。

## Scope（何が動く想定 / 何を切る）

### In scope（製品化したい）

- 端末に入った `zig` ホストで:
  - `zig version`
  - `zig build-exe hello.zig -target aarch64-ios`（純 Zig、C 依存なし）
  - `zig build`（`build.zig`、同じく純 Zig）
- 出力 Mach-O を **ldid + entitlements** で署名（Go / Rust / Nim と同じ）。
- パッケージ名は `zig`（Procursus に zig 無し → 名前衝突回避不要。将来出たら
  `zig-0.16` + `zig-default` に分割する余地を README に残す）。

### Out of scope（明示的に切る）

- **`zig cc` / `zig c++` を `/usr/bin/cc` や `update-alternatives` で据えること。**
  Recommends に clang を置き、C 連携が要るときだけ利用者に任せる。
- App Store 向けコードサイン / バンドル / `Info.plist` 生成の製品化。
- Simulator（`aarch64-ios-simulator`）サポート。
- 端末上での LLVM フルブートストラップ（iPhone 8 の RAM では Rust と同様に不可）。

## Feasibility: Mac-cross で「端末で動く zig」は作れるか

| 経路 | 判定 | 根拠 |
|------|------|------|
| 公式 iOS ホストバイナリ | **No** | [download](https://ziglang.org/download/) に ios ホスト成果物なし。 |
| `zig-bootstrap` → `aarch64-ios-*` | **No（公式未サポート）** | bootstrap README の Supported Targets に **iOS 無し**。Apple は `aarch64-macos-none` / `x86_64-macos-none` のみ OK。 |
| Mac 上の host zig で `zig build -Dtarget=aarch64-ios`（コンパイラ自身） | **Unknown（実験待ち）** | `build.zig` は `standardTargetOptions` を取るので形式的には可能。ただし静的 LLVM 同梱は巨大・ビルド時間長・iOS 向け LLVM/libc++ リンクが未検証。中間成果物の **ldid 署名**が必須。 |
| 公式 `aarch64-macos` バイナリをプラットフォーム書き換え + ldid（Go の darwin→ios 流儀） | **Unknown（最初の煙）** | Go は純 Go 内部リンクだった。Zig は LLVM 同梱の大きな Mach-O。`LC_BUILD_VERSION` の platform 不一致で SIGKILL されやすい。要実測。 |
| 端末 native bootstrap（cmake + system LLVM） | **Later / 重い** | Mayflower に clang-19 はあるが、Zig 0.16 は **LLVM 21.x 開発ライブラリ**を要求。端末で LLVM 21 を建てるのは非現実的。 |

**Verdict（2026-09-14）: Mac-cross runnable zig on ios = unknown（公式経路なし）。**
最初の実験は「Mac で `-Dtarget=aarch64-ios` のコンパイラ交叉」か
「macos 公式バイナリの platform rewrite 煙テスト」のどちらか。どちらも未実施
（本調査中、executor から Mac `machineId` Shell が使えず母艦コマンド未実行）。

### 補足: プログラムとしての `aarch64-ios` 交叉は Mac なら現実的

- Tier 3 で linker / codegen は揃う。
- 出荷 libc は **`aarch64-macos-none` / `x86_64-macos-none` のみ**（`zig targets`）。
  Linux ホストから `zig build-exe -target aarch64-ios` は
  `unable to find libSystem system library` で失敗（本調査で実測）。
- Mac では iPhoneOS SDK（端末から持ってきた Procursus SDK で可。Rust と同じ
  `tools/mac` 流儀）を `--sysroot` / `zig libc` で渡せば交叉できる。

## Build-time dependencies（Mac）

母艦で「端末で動く zig」を交叉する想定:

| 依存 | 用途 |
|------|------|
| Zig 0.16.0 `aarch64-macos` 公式 tarball | host コンパイラ |
| Xcode CLT（または Xcode） | cmake / host clang（bootstrap 経路時） |
| iPhoneOS SDK（端末 `/var/jb/usr/share/SDKs/iPhoneOS.sdk` を複製） | `-Dtarget=aarch64-ios` リンク / libSystem |
| `tools/mac/xcrun` shim | Rust と同じ。グローバル `SDKROOT` は置かない |
| CMake ≥ 3.19 / Ninja（`zig-bootstrap` 経路時） | LLVM 21 + Zig ブートストラップ |
| Python 3 | bootstrap スクリプト |
| `ldid` + Mayflower `entitlements.plist` | 交叉後のホスト `zig` に署名してから端末へ |
| ディスク余裕 | 静的 LLVM 付きなら **数 GiB〜十数 GiB** のビルドツリーを見込む |

公式 macos バイナリを「ほぼそのまま」使う煙の場合:

| 依存 | 用途 |
|------|------|
| `zig-aarch64-macos-0.16.0.tar.xz`（~50 MiB） | 展開して platform / 署名だけ触る |
| `ldid`、（任意）`install_name_tool` / `vtool` / `lc_uuid` 系 | platform 書き換え実験 |
| 端末への scp | `$HOME` 配下で展開（`/tmp` 禁止） |

## Runtime Depends / Recommends / Suggests（apt）

コンパイラ系の Mayflower 方針に合わせ、**Depends に `build-essential`** を入れる
（= Procursus SDK meta + `libiosexec1`）。既存の nim/go は `clang, ldid,
libiosexec1` 直書きだが、今回の依頼どおり meta を正面に据える。

提案:

```
Depends: build-essential, ldid, libiosexec1 (>= 1.3.1)
Recommends: clang-19 | clang, ld64
Suggests: llvm-19 | llvm
```

| フィールド | 中身 | 理由 |
|------------|------|------|
| **Depends: `build-essential`** | Procursus SDK meta | ヘッダ / ライブラリ探索の土台。依頼どおり。 |
| **Depends: `ldid`** | 署名必須 | 未署名 Mach-O は SIGKILL。Zig 本体・出力の両方。 |
| **Depends: `libiosexec1 (>= 1.3.1)`** | `/bin/sh` 無し対策 | `zig build` が子プロセス / シェルを蹴る場合に備える（Go/Nim と同水準）。 |
| **Recommends: `clang-19 \| clang`** | C 連携・`@cImport` 移行後の translate-c | **システム CC にはしない**。要る人だけ。 |
| **Recommends: `ld64`** | 外部リンクが要る場合の予備 | Zig 内蔵 MachO リンカが主。失敗時の逃げ。 |
| **Suggests: llvm** | bitcode / 高度な調査 | 通常パスでは Zig 同梱 LLVM で足りる。 |

Installed size 目安: 公式バイナリ展開で **~150–200 MiB**（Linux x86_64 の
`zig` 単体が ~165 MiB）。静的 LLVM 交叉成果物も同オーダーかそれ以上。

## Size / LLVM bundling / ldid / libiosexec

- **LLVM bundling:** 公式リリースの `zig` は LLVM 拡張付き自己完結バイナリ。
  端末に別途 `libLLVM` を Depends する必要は基本なし（静的リンク想定）。
- **ldid:** (1) 配布する `zig` ホスト自体 (2) `zig` が吐く実行ファイル。
  後者は Go/Rust 同様、リンカ直後に ldid を挟むパッチかラッパーが要る可能性大。
  探索の当たりは `dsymutil` 周辺（`docs/building.md`）。
- **libiosexec / `/bin/sh`:** rootless に `/bin/sh` は無い。`zig build` が
  `std.process` 経由でシェルを呼ぶ経路があれば `ie_*` 差し替えか、
  Mayflower の `bin/make` / `CONFIG_SHELL` 流儀で回避する。
- **native OS 検出:** 端末の `uname` は `Darwin` / `iPhone10,1` など。
  Zig がホストを `macos` と誤認するとデプロイメントターゲットや
  framework パスがずれる。`-target aarch64-ios` 明示と、必要なら
  `builtin.os.tag` 周りのパッチを検討。

## Open risks

1. **ホスト OS としての ios が公式未サポート** — bootstrap / CI なし。交叉が通っても
   実行時に `std.Io` / ファイル / プロセス API が jailbreak 環境で落ちる可能性。
2. **libc ❌ for aarch64-ios** — 純 Zig は compiler_rt + libSystem 動的リンクで
   いけることが多いが、SDK / TBD の所在が端末と Mac で違う。
3. **出力の自動署名が未実装** — 素の zig は ldid を呼ばない。パッチ必須の公算大。
4. **巨大バイナリ** — apt 転送・端末ストレージ・起動時メモリ。
5. **0.16 の std.Io 刷新** — 子プロセス API が変わっており、既存の jailbreak
   知見（0.11 台）をそのまま適用できない。
6. **Mac Shell 未到達（本調査）** — docs / skeleton は staging に書いた。
   母艦 `/Users/yunomin61/dev/Mayflower` への反映と実ビルドは次ステップ。

## First build path（提案）

明確に「今すぐ deb が建つ」わけではないが、実験順は次でよい:

1. **Mac:** 公式 `zig-aarch64-macos-0.16.0.tar.xz` を展開し、`zig targets` /
   `zig build-exe hello.zig -target aarch64-ios --sysroot <iPhoneOS.sdk>` で
   **プログラム交叉**が通ることを確認（ホスト zig は macOS のまま）。
2. **Mac:** 同じ host zig でソース `zig build -Dtarget=aarch64-ios -Doptimize=ReleaseFast`
   （必要なら `-Denable-llvm -Dstatic-llvm`）を試し、コンパイラ交叉のエラーを収集。
3. 並行煙: macos 公式 `zig` を端末へコピー → `ldid -S entitlements.plist` →
   `ssh ip8` で起動するか（platform 不一致なら即終了のはず）。
4. 通った成果物だけ `packages/zig` の `ZIG_DIST_DIR` に載せて deb 化（Rust 流儀）。

## Next concrete step for ip8 smoke

```sh
# Mac (Mayflower 作業ツリー)
curl -fsSL -o /tmp/zig-aarch64-macos-0.16.0.tar.xz \
  https://ziglang.org/download/0.16.0/zig-aarch64-macos-0.16.0.tar.xz
# ※作業は $HOME 配下へ
mkdir -p ~/dev/zig-smoke && tar -xJf … -C ~/dev/zig-smoke
~/dev/zig-smoke/zig-aarch64-macos-0.16.0/zig version

# 端末へ（署名してから）
ldid -S ~/dev/Mayflower/entitlements.plist ~/dev/zig-smoke/.../zig
scp … ip8:~/dev/zig-smoke/zig
ssh ha 'ssh ip8 "~/dev/zig-smoke/zig version"'
```

期待: platform 不一致なら即座に Kill。その場合はステップ 2 の
`-Dtarget=aarch64-ios` 交叉へ進む。



## Experimental results (2026-09-14 Mac → ip8)

Host: Mac mini + official `zig-aarch64-macos-0.16.0`. Device: ip8 (iPhone 8 / A11)
via `ssh ha` → `ssh ip8`. SDK: Xcode `iPhoneOS18.4.sdk` under `~/Downloads/Xcode.app`.

### What works

1. **Program cross with `--libc` kit** (Mac host zig stays macos):
   ```sh
   zig libc -target aarch64-ios > zig-libc-ios.txt   # then point include/sys_include at SDK
   zig build-obj hello.zig -target aarch64-ios -mcpu=apple_a11 -OReleaseSmall \
     --libc zig-libc-ios.txt -femit-bin=hello.o
   clang -target arm64-apple-ios16.0 -isysroot "$SDK" -o hello hello.o -lSystem
   ldid -S entitlements.plist hello
   ```
   On ip8: prints `hello from zig`, exit 0.

2. **`--sysroot` alone is not enough** — Zig still reports
   `unable to find libSystem system library` until `--libc` paths point at
   `$SDK/usr/include` (and optionally `crt_dir=$SDK/usr/lib`). Absolute `-L`
   under `--sysroot` double-prefixes and fails.

### What fails

1. **`zig build-exe -target aarch64-ios` (Zig’s own Mach-O linker)** — binary
   gets `Illegal instruction: 4` (exit 132) on ip8. Disassembly of `_main`
   starts with `udf` traps when using the default linker path. `-mcpu=apple_a11`
   / `baseline` / `generic` and `-fno-lld` did not fix runtime (still SIGILL).
2. **Official ios host binary / zig-bootstrap `aarch64-ios`** — not offered
   upstream (unchanged).
3. **Shipping macos `zig` onto the device** — not expected to run (platform 1
   / macos); smoke deferred while program-link path was debugged.

### Implication for the Mayflower package

- Runtime **Depends** proposal below still stands for an eventual on-device
  `zig` host.
- Until a host `zig` for `aarch64-ios` exists, the practical Mayflower path is
  **Mac cross** (`zig` + `--libc` + **Apple `clang`/`ld` final link** + `ldid`),
  same shape as Rust’s Mac→ip8 flow.
- On-device `zig build` productization needs either:
  - a successfully cross-built ios-host `zig` linked with **system ld** (not
    Zig’s broken ios Mach-O path), or
  - a wrapper that always `build-obj` + invokes `clang`/`ldid`.

### Proposed Depends (unchanged)

```
Depends: build-essential, ldid, libiosexec1 (>= 1.3.1)
Recommends: clang-19 | clang, ld64
Suggests: llvm-19 | llvm
```

`clang`/`ld64` stay in **Recommends** because the working link path for ios
programs currently **requires** an external Apple-compatible linker; once an
ios-host zig is proven, we may promote `clang`/`ld64` to Depends.

## Scaffold status（本ターン）

作成済み（**Mac 上の Mayflower 本樹には未反映** — executor に `ListMachines` /
`machineId` Shell / `CopyFromBox` が無く、母艦パスへ書けなかった）:

- `docs/zig.md`（本ファイル）
- `packages/zig/make.sh` — `ZIG_DIST_DIR` 受けの Rust 流儀スケルトン
- `packages/zig/deb/DEBIAN/control` — Depends 案を焼き込み
- `packages/zig/README.md`

Handoff 用コピー:

- `/workspace/Mayflower-zig-handoff/`（同内容）
- `/workspace/Mayflower-zig-handoff.tgz`

**zls（言語サーバ）は後回し**（利用者指示）。本パッケージはコンパイラ /
toolchain のみ。

母艦への反映例（親エージェントが `CopyFromBox` できるとき）:

```sh
# box → Mac
# CopyFromBox: /workspace/Mayflower-zig-handoff.tgz → Mac
cd /Users/yunomin61/dev/Mayflower
tar -xzf ~/Downloads/Mayflower-zig-handoff.tgz   # 実際の着地パスに合わせる
# docs/zig.md と packages/zig/ が載ることを確認。git add は煙が通ってから。
```

コミットはしていない（ビルド未成功・本樹未書き込みのため）。
