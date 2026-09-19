# 脱獄 iOS でビルドするときの勘所

脱獄した rootless iOS 環境でのビルドは、主に以下の点への対処で成り立っている。

## 1. 署名が無い実行ファイルは起動できない

素の clang が吐いた Mach-O は、実行しようとすると **SIGKILL（rc=137）** される。
entitlements 無しの `ldid -S` でも足りない。`platform-application` と
`com.apple.private.security.container-required=false` を持つ plist が要る
（`entitlements.plist`）。

そのため `CC` / `CXX` は素の clang ではなく `bin/cc` / `bin/c++` を指す。
これは clang を呼んだあと出力を `ldid -S` するラッパーで、`configure` が作る
テストバイナリのような「ビルドの途中で実行される実行ファイル」もこれで動く。

### 自前のリンカを持つ言語では、`dsymutil` を探す

Go や Rust や Nim のように**自分でリンカを起動する**処理系は、ラッパーを
`CC` に置くだけでは足りず、リンク後に `ldid` を呼ぶコードを本体に入れる
必要がある。その差し込み場所は `dsymutil` を grep すると見つかる。

```sh
grep -lr dsymutil <ソースツリー>
```

`dsymutil` は Darwin でリンクした直後にデバッグ情報を取り出す後処理なので、
それを呼んでいる場所を追うことで、リンク処理や出力ファイルを扱う箇所を
特定できる。

| 処理系 | 見つかるファイル |
|---|---|
| Nim | `compiler/extccomp.nim`（`getExtraCmds` の dsymutil の直後に ldid を足した） |
| Go | `src/cmd/link/internal/ld/lib.go`（`hostlink`。`llvm-ar` への差し替えも同じ関数） |
| Rust | `compiler/rustc_codegen_ssa/src/back/link.rs`（`link_natively` の最後。dsymutil・strip・書庫化のあと） |

## 2. `/bin/sh` が無い

rootless では rootfs が封印されていて、`/bin` には `df` と `ps` しかない。
`system()` は iOS SDK では unavailable（コンパイルエラー）で、しかも実行時は
`/bin/sh` を探す。

端末には **libiosexec**（Procursus）が入っており、`ie_system` / `ie_exec*` /
`ie_posix_spawn` が接頭辞付きのシェルと shebang を解決する。移植対象がシェルを
呼ぶなら、そこへ差し替えるパッチを当てる。動的リンクするときは
`-Wl,-rpath,/var/jb/usr/lib` が要る（Procursus の clang は自動では付けない）。

## PATH wrappers (Mach-O) と spawn / libiosexec

Dopamine（se3）では shebang の `posix_spawn` が EPERM になることがあり、対処は
**二層**ある。

### 層 1: PATH 入り口の Mach-O ラッパー

Mayflower が `/var/jb/usr/bin` に置く起動入り口（`go` / `rustc` / `git-2.55` /
`node-24` / `swift-6.1` / `claude` など）と、ビルド用の `bin/cc`・`bin/c++`・
`bin/make` は **shebang スクリプトではなく Mach-O** にする。llvm の
`toolchain-wrapper.c` と同じく、パッケージ時に `files/mayflower-exec.c`
（および用途別の `.c`）をコンパイルして `ldid` 署名する。ヘルパーは
`files/mayflower-exec.sh`。

### 層 2: `mayflower_spawn`（fishhook）+ `-liosexec`

端末上の `./make.sh` ビルドでは、既定の `LDFLAGS` に
`-lmayflower_spawn -liosexec` を足す（`make.sh`、ios_compat と同様に静的
ライブラリ化）。iOS も Darwin なので、Mac ホスト判定は
`uname=Darwin` かつ `${JB}/usr/bin/clang` が無いときだけスキップする。

- **`-liosexec`**: Procursus の dyld interpose（`ie_posix_spawn` 等）。他の
  `ie_*` 呼び出しにも必要。明示的に `ie_*` を呼ぶパッチ（Go / Nim 等）用。
- **`-lmayflower_spawn`**: `files/mayflower_spawn.c` + Facebook fishhook
  （`files/fishhook.c` / `fishhook.h`、BSD-3-Clause）。Dopamine の systemhook が
  `__posix_spawn` を差し替えると dyld interpose は効かないため、プロセス内で
  `posix_spawn` / `posix_spawnp` / `execve` / `execv` を fishhook し、
  EPERM/ENOEXEC の shebang を interpreter argv で再試行する。`/bin`・
  `/usr/bin` のインタプリタは `/var/jb` 接頭辞へ書き換える（libiosexec と同じ）。

言語処理系で `posix_spawn` を使うもの（CPython の subprocess 等）は層 2 の
再リンクで足りる。素の `execve` 経路（CRuby の fork+exec 等）も同じ fishhook
で拾う。PATH 入り口が shebang スクリプトそのもの（`luarocks` 等）は層 1 の
Mach-O ラッパーが要る。

Mac ホストでのパッケージ作業（`claude-code` 等）ではこの層はスキップする。

**シェバンに `/bin/bash` や `/usr/bin/env` は書けない。** どちらのパスも存在しない。
libiosexec を引いている実行ファイルから呼ばれた場合だけ解決されるため一見動くが、
素の `execve` からは `No such file or directory` になる。このリポジトリの
スクリプトは `#!/var/jb/bin/bash` で統一している。

また、`$ROOTDIR/bin` を PATH の先頭に置いている。`bin/make` は GNU make に
SHELL を与えるラッパーで、これが無いと autotools も cmake も `/bin/sh` を
探して失敗する。

## 3. 動的ライブラリが見つからない

`dlopen("libfoo.dylib")` は既定で `/usr/lib` と `/usr/local/lib` しか見ない。
実行ファイルに `LC_RPATH` として `/var/jb/usr/lib` が入っていれば、素の名前でも
そこから解決される。

また、リンク時に `-L${JB}/usr/lib` が必須となる。iOS SDK の `.tbd` スタブは
clang の既定の探索先にあり、そちらが先に当たるため、Procursus が持っている
ものでも系統が system 側へ逃げる。実測では `-llzma` がヘッダ 5.4.4 に対して
実行時 5.0.5 の system を掴み、`-lreadline` は SDK の `libreadline.tbd` 経由で
libedit になっていた。

## 4. ドライバ（make.sh）と再開オプション

`make.sh` はパッケージ側の関数を `clean` → `download` → `prepare` →
`applyPatch` → `build` → `check` → `package` → `tidy` → `makedeb` の順で呼ぶ。

ビルド作業の試行錯誤用に環境変数 `MAYFLOWER_RESUME` を備えている。

- `MAYFLOWER_RESUME=1`: `clean` / `download` / `prepare` / `applyPatch` を
  飛ばし、既にあるビルドツリーで `build` から始める。移植中に次の壁を1つずつ
  潰すための近道。素の状態から通るか分からないため、完成レシピの検証には使わない。
- `MAYFLOWER_RESUME=package`: `build` / `check` も飛ばして `package` から始める。
  中身は同じまま `.deb` の作り方だけを変えたいとき（パッケージの分割、control の
  書き換え、名前の変更など）に使う。端末で時間のかかるビルドをやり直さずに済む。
