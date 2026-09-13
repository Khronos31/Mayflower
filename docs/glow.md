# glow

ソースツリー: [`packages/glow`](../packages/glow)

Charmbracelet のターミナル Markdown ビューア。

## パッケージ情報

- 版: 3.0.0
- パッケージ: `glow`
- ビルド: **端末**（Mayflower `golang-default` / Go 1.26+、`CGO_ENABLED=1`）
- ビルド依存: `golang-default`, `libiosexec-dev`, `clang`（Mayflower clang-19 可）, `git`
- 実行時 Depends: `libiosexec1`
- Procursus: 無し（新規）

## 端末

```sh
sudo apt install golang-default libiosexec-dev
# clang は Mayflower clang-19 / clang-default で可

./make.sh glow
sudo dpkg -i packages/glow/arm64/glow_*.deb
glow --version
glow README.md
```

`ios/arm64` は外部リンク必須のため cgo が要る。リンカは `-liosexec` を付けるので
`libiosexec-dev`（`libiosexec.dylib` → `.1`）が必要。

モジュール取得にネットワーク（`GOPROXY`）が要る。オフライン化する場合は
`go mod vendor` 同梱を別途検討。

作業一時ディレクトリは `$HOME/tmp` を使う（jb の `/tmp` は SIGKILL されやすい）。
