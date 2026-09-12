# siano-userland

ソースツリー: [`packages/siano-userland`](../packages/siano-userland)

[siano-userland](https://github.com/Khronos31/siano-userland) v0.1.5。
Siano RIO 系 USB チューナー（PLEX PX-S1UD など）向けのユーザー空間 ISDB-T
選局・MPEG-TS 出力。

## パッケージ情報

- ディレクトリ / `Package:`: `siano-userland`
- Sileo の `Name:`: Siano Driver
- バイナリ: `siano-ts`
- 版: 0.1.5-2
- Depends: `libusb-1.0-0`
- バイナリ: `/var/jb/usr/bin/siano-ts`
- ファームウェア: `/var/jb/usr/share/siano-ts/isdbt_rio.inp`（および `/var/jb/lib/firmware/isdbt_rio.inp`）

## ライセンス

二つのライセンスが同居する。

| 対象 | ライセンス | 置き場所（インストール後） |
|---|---|---|
| `siano-ts` 本体 | GPL-2.0-or-later | `/var/jb/usr/share/licenses/siano-ts/COPYING` |
| ファームウェア `isdbt_rio.inp` | Siano 再配布許諾（`LICENCE.siano`） | `/var/jb/usr/share/licenses/siano-ts/LICENCE.siano` ほか |

### ファームウェア（`LICENCE.siano`）

Copyright (c) 2005-2014 Siano Mobile Silicon Ltd. All rights reserved.

- **改変しないバイナリ形式**での再配布・利用が許される
- 再配布物には、上記著作権表示と許諾文（ディスクレーマ含む）を
  ドキュメントまたは付属資料として必ず添える
- Siano および供給者の名を、許諾なく宣伝に使ってはならない
- **リバースエンジニアリング、逆コンパイル、逆アセンブルは禁止**

Mayflower の `.deb` は上流の配布アーカイブ方針に合わせ、ファームを
**同梱する**。Git のソースツリーには blob を置かない。

同梱時の表示:

- `DEBIAN/control` の Description に著作権と禁止事項の要約
- `/var/jb/usr/share/doc/siano-ts/copyright`（Debian copyright 形式）
- `/var/jb/usr/share/siano-ts/LICENCE.siano` と `NOTICE`（ファームの隣）
- `/var/jb/usr/share/licenses/siano-ts/LICENCE.siano`（ライセンス集約）

apt / GitHub Pages で `.deb` を再配布する場合も、パッケージ内のこれらの
ファイルが「付属資料」になる。リポジトリ説明で Siano を宣伝文句に使わないこと。

## ビルドの要点

### USB entitlements

ルートの `entitlements.plist`（`platform-application` のみ）では足りない。
`packages/siano-userland/entitlements.plist` に Theos 実機と同じ USB / IOKit
user-client 系を置き、`make.sh` の `prepare` / `build` / `package` で
`ENTFILE` をそこに向け直す（ルート `make.sh` が薄い方へ上書きするため）。

### ファームウェアの取得

上流ソースには含まれない。SHA-256
`054520642d5d09cb7ab7d08dbd6fd9ba9365de56adf2e7d7d06927f9845ff818`。
`packages/siano-userland/firmware/isdbt_rio.inp` があればそれを使い、無ければ
linux-firmware の固定 revision から取得して検証する。blob は gitignore。
`firmware/NOTICE` はコミットする。

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
