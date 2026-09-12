# go

ソースツリー: [`packages/go`](../packages/go)

Go を rootless 脱獄 iOS 上でビルドする。

## パッケージ情報

- 版: 1.26.8-1
- パッケージ構成（Debian 流の分割）:
  - `golang-1.26-go`: GOROOT 本体（bin, pkg, api, go.env, entitlements.plist）
  - `golang-1.26-src`: src ツリー
  - `golang-default`: `/var/jb/usr/bin` に置くラッパー（`Provides: golang-go`、`Conflicts`/`Replaces: golang-go`）

### パッケージ名を分ける理由

Procursus は `/var/jb/etc/apt/preferences.d/procursus` で `Package: *` を
`Pin-Priority: 1001` に固定している。1001 は「降格してでもその版を入れる」を
意味するため、同名の `golang-go` 1.26.8-1 を出すと `apt-get -s upgrade` が
Procursus の 1.22.4 への降格を提案して戻してしまう。戻される先は出力を
署名しない Go なので端末では動かない。そのため名前を変え、`Provides: golang-go` で
golang メタパッケージの依存を満たす形にしている。

## 1.27 系を採らない理由と今後の予定

Go は 1.27 系を採らない。`ios/arm64` で起動時に作業ディレクトリが実行ファイルの
場所へ変わる退行が入っており（[golang/go#81465](https://github.com/golang/go/issues/81465)）、
`cmd/go` が `go.mod` を見つけられなくなるためである。

上流は修正を進めている。CL 830864
「runtime: keep the working directory for non-bundled ios/arm64 binaries」が
Code-Review +2・TryBot 緑で master に出ており、1.27 へのバックポートも
[golang/go#81469](https://github.com/golang/go/issues/81469) として
マイルストーン **Go1.27.2** で起票されている。`Info.plist` の有無を `chdir` の
条件に戻し、パスの取得だけ `CFBundleCopyBundleURL` に残す設計となっている。
**Go 1.27.2 が出たらそこへ移る。**

## Go の bootstrap を用意する

Go は自分自身でしかビルドできないので、先に動く Go が要る。端末に入っている
Procursus の go は使えない。無署名の実行ファイルしか吐けず、`make.bash` の
途中で実行される中間バイナリが起動できずに落ちる。

かといって `GOOS=ios` のクロスビルドもできない。`ios/arm64` は必ず外部リンクを
使う決まりで、ターゲット用の C ツールチェインが要るためである。

そのため、**`GOOS=darwin GOARCH=arm64` でクロスビルドして、iOS 用に直す**。
これは純 Go の内部リンクなので、Xcode も iOS SDK も要らない。Linux でも構わない。

```sh
# 1. 別の機械で（要 Go 1.24.6 以降）
cd <goのソース>/src
GOOS=darwin GOARCH=arm64 ./bootstrap.bash     # ../../go-darwin-arm64-bootstrap ができる

# 2. 端末へ運ぶ
tar cf - -C ../../go-darwin-arm64-bootstrap . | ssh <端末> 'mkdir -p ~/dev/go-bootstrap && tar xf - -C ~/dev/go-bootstrap'

# 3. 端末で iOS 用に直す（フレームワークのパスと署名）
~/dev/Mayflower/tools/fix-darwin-toolchain ~/dev/go-bootstrap ~/dev/Mayflower/entitlements.plist
~/dev/go-bootstrap/bin/go version     # go1.27.1 darwin/arm64 と出れば通っている
```

手順3が要るのは、macOS のフレームワークが `CoreFoundation.framework/Versions/A/…`
という階層を持つのに対し、**iOS は平坦**（`CoreFoundation.framework/CoreFoundation`）
だからである。`install_name_tool` で書き換えると署名が壊れるので、`ldid` で
付け直す。

あとは bootstrap の位置を渡してビルドする。

```sh
GOROOT_BOOTSTRAP=~/dev/go-bootstrap ./make.sh go
```

## ビルドと実行時の仕様

- **CC の指定**: `CC` は素の名前 `clang` を渡す。Go はこの値を `zdefaultcc.go` に
  焼き込むため、絶対パスのラッパーを渡すと利用者の環境に無いものを指してしまう。
  署名はリンカのパッチが行うためラッパーは不要。
- **GOROOT ラッパー**: `go` と `gofmt` は `/var/jb/usr/bin` に置くラッパーで
  GOROOT を補ってから本体を呼ぶ。iOS では `os.Executable` が失敗するため、
  go が GOROOT を実行ファイルの位置から見つける経路が効かないことへの対処である。
  利用者が環境変数で GOROOT を設定する必要はない。
- **exec における libiosexec の限界**: `exec.Command("sh", …)` と `#!/bin/sh` の
  シェバンは通るが、`exec.Command("/bin/sh", …)` のように絶対パスで封印された
  rootfs を指すと通らない。libiosexec は shebang の解釈先とシェルの探索は
  prefix 付きで行うが、直接渡された絶対パスは読み替えないためである。
  これは Procursus の go でも同様である。
