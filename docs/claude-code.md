# claude-code

ソースツリー: [`packages/claude-code`](../packages/claude-code)

Anthropic Claude Code を、脱獄 iOS（iphoneos-arm64）向けに非公式移植したパッケージ。
公式の `@anthropic-ai/claude-code-darwin-arm64` を取得し、Mac 上でパッチ・署名して `.deb` にする。

上流: [anthropics/claude-code](https://github.com/anthropics/claude-code) / npm `@anthropic-ai/claude-code-darwin-arm64`

非公式であり Anthropic とは無関係。バイナリ改変・再配布は上流の規約に反しうる。
`NOTICE` と上流 `LICENSE` は `/var/jb/usr/share/licenses/claude-code/` に同梱する。

## パッケージ情報

- 版: 2.1.282-1
- `Package:` `claude-code` / Sileo `Name:` `Claude Code`
- `Depends:` `libiosexec1 (>= 1.2.2)`, `apple-a14`
- `Recommends:` `git-2.55 | git-default | git`
- `/var/jb/usr/bin/claude` … ラッパー
- `/var/jb/usr/libexec/claude-code/claude.bin` … パッチ済み本体
- `/var/jb/usr/libexec/claude-code/libsystemshim.dylib` … 不足シンボル用 shim

## ビルド

**ビルドは Mac。** `vtool` / `install_name_tool` / `clang` / `ldid` が要る。
端末の `./make.sh` ではパッチ工程が落ちる。

```sh
# Mac（bash 5+。Homebrew の bash 可）
./make.sh claude-code
# => packages/claude-code/arm64/claude-code_2.1.282-1_iphoneos-arm64.deb
```

`scripts/patch-ios.sh` がまとめて当てる内容の概略:

- SharedArrayBuffer を使う sleep を busy-wait に置換（`BUN_JSC_useCodeCache=0` と併用）
- CoreFoundation / CoreServices の macOS 版パスを iOS 向けに書き換え
- 資格情報ストアを Keychain 合成ではなく plaintext（`.credentials.json`）に固定
- Mach-O の platform を iOS にし、`libSystem` を shim 経由に差し替え
- `ldid` で署名


## busy-wait（SharedArrayBuffer sleep 置換）

上流は原子待ち `Atomics.wait` で短い sleep をしている。iOS では
`SharedArrayBuffer` が使えないため、同じ長さの busy-wait に差し替えている。

2.1.282 ではこの sleep 関数（`Ae`）を呼ぶのは同期リトライ `EFr` の catch
（定数 `se=50` = 50ms）だけ。しかもリトライ判定 `ce` が常に `false` のため、
現行ビルドではその経路自体が死んでおり、実運用で CPU を回し続ける心配は
ほぼ無い。上流が `ce` を戻したり呼び出しを増やしたりしたら要再確認。

## ラッパーと自動更新

ラッパーは次を export する。

- `BUN_JSC_useCodeCache=0`
- `DISABLE_UPDATES=1`
- `DISABLE_AUTOUPDATER=1`
- `DISABLE_INSTALLATION_CHECKS=1`

公式の native インストーラは起動時に `~/.local/bin/claude` を作り直し、自動更新も掛ける。
`~/.claude.json` の `autoUpdates: false` は、`installMethod` が `native` かつ
`autoUpdatesProtectedForNative` が true のとき無視される。版上げは apt / Mayflower の
`.deb` で行う。

実機では `installMethod` を `package` にし、`autoUpdatesProtectedForNative` を false に
しておくと安全。
