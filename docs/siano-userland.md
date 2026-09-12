# siano-userland（siano-ts）

ソースツリー: [`packages/siano-userland`](../packages/siano-userland)

[siano-userland](https://github.com/Khronos31/siano-userland) v0.1.5。
Siano RIO 系 USB チューナー（PLEX PX-S1UD など）向けのユーザー空間 ISDB-T
選局・MPEG-TS 出力。ディレクトリ名は上流リポジトリに合わせ `siano-userland`、
インストールする deb / バイナリ名は `siano-ts`。

## パッケージ情報

- ディレクトリ: `packages/siano-userland`
- deb Package: `siano-ts`（Procursus に無い）
- 版: 0.1.5-1
- Depends: `libusb-1.0-0`
- バイナリ: `/var/jb/usr/bin/siano-ts`
- ファームウェア: `/var/jb/usr/share/siano-ts/isdbt_rio.inp`（および `/var/jb/lib/firmware/isdbt_rio.inp`）

## ビルドの要点

### USB entitlements

ルートの `entitlements.plist`（`platform-application` のみ）では足りない。
`packages/siano-userland/entitlements.plist` に Theos 実機と同じ USB / IOKit
user-client 系を置き、`make.sh` の `prepare` / `build` / `package` で
`ENTFILE` をそこに向け直す（ルート `make.sh` が薄い方へ上書きするため）。

### ファームウェア

上流ソースには含まれない。SHA-256
`054520642d5d09cb7ab7d08dbd6fd9ba9365de56adf2e7d7d06927f9845ff818`。
`packages/siano-userland/firmware/isdbt_rio.inp` があればそれを使い、無ければ
linux-firmware の固定 revision から取得して検証する。blob は gitignore。

端末に既に `~/dev/siano-ts/firmware/isdbt_rio.inp` があるなら:

```sh
mkdir -p packages/siano-userland/firmware
cp ~/dev/siano-ts/firmware/isdbt_rio.inp packages/siano-userland/firmware/
```

### ファームウェア探索パス（パッチ）

`patches/firmware-jb-paths.patch` で `/var/jb/lib/firmware/...` と
`/var/jb/usr/share/siano-ts/...` を追加。rootless 以外にも有用なので
上流 PR 候補。

### リンク

`-lusb-1.0`、`-framework IOKit -framework CoreFoundation -framework Security`、
`-Wl,-stack_size,0x800000`（Theos Makefile 相当）。`LDFLAGS` の
`-rpath ${JB}/usr/lib` はドライバ側で付く。

## 使い方（端末）

```sh
siano-ts --list
siano-ts -c 27 -t 30 -o /tmp/ch27.ts
```
