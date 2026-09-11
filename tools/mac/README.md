# Mac からのクロスビルド

Rust だけは端末で建てられない。rustc の bootstrap は LLVM を建てるので、
RAM 1.93GB の iPhone 8 では成立しない。M2 Mac mini（8コア・8GB）から
`host = ["aarch64-apple-ios"]` として建て、**梱包と署名は端末で行う**。

2020 年の Mayflower（`rust` 枝）も同じ形だった。あちらは
`x86_64-apple-darwin` で stage1 を建ててから stage0 に据え直していたが、
母艦が arm64 になった今は素の stage0 がそのまま使えるので、その手順は要らない。

## Xcode は要らない

Command Line Tools だけでよい。足りないのは iPhoneOS SDK だけで、それは
端末から持ってくる。

**Xcode が入っている機械でも、端末由来の SDK を使う。** Xcode の iPhoneOS SDK は
新しすぎる（Xcode 26.6 で SDK 26.5）。rustc の iOS 既定デプロイメントターゲットは
10.0（`base/apple/mod.rs:312`）なので 26 系でも安全ではあるが、端末の iOS と
版を揃えた方が、後で原因を追うときに変数が1つ減る。Procursus も端末の SDK で
全部を建てている。shim は `--sdk iphoneos` だけを奪い、`--sdk macosx` は Xcode の
本物へ委ねるので、同居して困らない。

> ⚠️ **ビルド中に Xcode を入れないこと。** `xcode-select` の向き先とライセンス
> 同意の状態が途中で変わり、走っているリンクが終了コード 69
> （`You have not agreed to the Xcode license agreements`）で落ちる。入れたなら
> `build/` を捨ててやり直す。ホスト側の SDK も CLT のものから Xcode のものへ
> 変わるため、混ざった木を残さない方がよい。

```sh
ssh ip8 'cd /var/jb/usr/share/SDKs && tar cf - iPhoneOS.sdk' \
  | ssh mac 'mkdir -p ~/ios-sdk && tar xf - -C ~/ios-sdk'
ssh mac 'cd ~/ios-sdk && mkdir -p iPhoneOS.platform/Developer/SDKs \
         && mv iPhoneOS.sdk iPhoneOS.platform/Developer/SDKs/'
```

**`iPhoneOS.platform/Developer/SDKs/` の下に置くこと。** Xcode と同じ形に
しておくと、rustc の `get_apple_sdk_root` がパスに `iPhoneOS.platform` を
見つけて macOS 向けのときに正しく弾く。

端末の SDK は Procursus の `build-essential` が入れたもので、版は端末の iOS に
近い（iOS 16.7 に対して SDK 16.2）。いまの Xcode を入れると SDK は 26 系に
なり、iOS 16 に無い API を掴む余地がかえって増える。

**SDK はリポジトリに入れない。deb にも入れない。** 個人の機械の間で複製する
だけにする。

## xcrun の shim を PATH に置く

`tools/mac/xcrun` を PATH の先頭へ。理由はファイル冒頭のコメントに書いた。
要点は2つで、どちらも実測:

- **グローバルな `SDKROOT` は使えない。** cc-rs の判定表が `"macosx10.15"` の
  ままで、実際に渡る `"macosx"` と一致しないため、ホスト側の C まで iOS SDK で
  建ててしまう。
- **`IPHONEOS_DEPLOYMENT_TARGET` も環境に置けない。** clang の Darwin ドライバが
  プラットフォームごと iOS を選ぶので、bootstrap がホストで実行する
  `libcxx-version` が iOS バイナリになって落ちる。

## 建てる

```sh
ssh mac
export MAYFLOWER_IOS_SDK=~/ios-sdk/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
export PATH=~/ios-tools:$PATH          # xcrun shim を置いた場所
cd ~/rust-ios/rustc-<版>-src
cp <Mayflower>/tools/mac/bootstrap.toml .
env -u SDKROOT -u IPHONEOS_DEPLOYMENT_TARGET \
  caffeinate -i nohup python3 x.py dist --stage 2 -j 4 > dist.log 2>&1 &
```

出来た tarball を端末へ渡し、`make.sh rust` の `prepare()` がそれを要求する。
Go の `GOROOT_BOOTSTRAP` と同じ扱いで、母艦の事情を `make.sh` に持ち込まない。
