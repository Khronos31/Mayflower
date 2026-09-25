# px4-userland

ソースツリー: [`packages/px4-userland`](../packages/px4-userland)

[px4-userland](https://github.com/Khronos31/px4-userland) v0.1.6。
PLEX PX-Q3U4、PLEX PX-MLT5PE、e-Better DTV02A-5TS-P 向けのユーザー空間ドライバ。
カーネルモジュールは使わず、libusb でチューナーと内蔵 IC カードリーダーを制御する。

対応機種:
- PLEX PX-Q3U4: USB ID `0511:084a`、8 チューナーと内蔵 IC カードリーダー
- PLEX PX-MLT5PE: USB ID `0511:024e`、5 チューナーと内蔵 IC カードリーダー
- e-Better DTV02A-5TS-P: USB ID `0511:924e`（PX-MLT5PE のリブランドで、USB Product ID だけが違う）

v0.1.6 では PX-W3U4 / PX-W3PE4 / PX-Q3PE4 / PX-W3PE5 / PX-Q3PE5 /
PX-MLT8PE3 / PX-MLT8PE5 / PX-M1UR / PX-S1UR / DTV02-1T1S-U /
DTV02A-1T1S-U / DTV02A-4TS-P / DTV03A-1TU を識別対象に追加した
（いずれも実機未検証）。同一 lease 内の再選局と、px4d 不在・切断時の
IFD 耐性も入る。

## パッケージ情報

- ディレクトリ / `Package:`: `px4-userland`
- Sileo の `Name:`: PX4 Driver
- バイナリ: `px4d` / `px4-ts` / `px4ctl` / `px4-usb-probe`
- 版: 0.1.6-1
- Depends: `libusb-1.0-0`（Recommends: `pcscd`）
- 置き場所: `/var/jb/usr/bin/px4d` ほか

Siano Driver（`siano-userland` / `siano-ts`）と対になる命名。
PX4 はデーモン（`px4d`）が筐体を所有し、`px4-ts` が IPC で選局して TS を出す。

## ライセンス

本体は GPL-2.0-only。IT930x ファームウェアは **同梱しない**
（上流と同じ。権利と取得方法は別整理）。

受理条件（上流 SPEC）: 2,169 バイト、SHA-256
`5213a5a38872661277a2cc1b2dfdfe88faf06f41205f460f3b51857f0568b484`。
`px4d --firmware PATH` で渡す。

## ビルドの要点

### USB entitlements

ルートの `entitlements.plist`（`platform-application` のみ）では足りない。
`packages/px4-userland/entitlements.plist` は Siano Driver と同じ IOKit USB
user-client 列。`prepare` / `build` / `check` / `package` で `ENTFILE` を
そこに向け直す（ルート `make.sh` が薄い方へ上書きするため）。

未署名の Mach-O は起動時 SIGKILL（rc 137）。薄い entitlements では
`libusb_get_device_list` がデバイス有りでも 0 件で成功する。
シリアル確認は `px4-usb-probe`（同じ USB entitlements）。
デバイスを **開く** ときも IOKit user-client が要る。

### libc++ `__libcpp_verbose_abort`

上流は `-fno-exceptions -fno-rtti`。Clang 19 の libc++ ヘッダは、その組み合わせで
`std::__1::__libcpp_verbose_abort` を呼ぶ。iOS 16.7 の `/usr/lib/libc++.1.dylib` には
このシンボルが無い。`files/libcpp_verbose_abort.cpp` をオブジェクトとしてリンクする。

### CMake

`PX4_BUILD_TESTS=OFF`、`PX4_BUILD_TOOLS=ON`、`PX4_BUILD_PCSC_IFD=ON`。
IFD は macOS bundle ではなく `libpx4-userland-ifd.dylib`。pcsc-lite の
`dlopen` が読む。`ifdhandler.h` はビルド時に `libpcsclite-dev` から取る。
`px4-usb-probe` は USB entitlements 付きで `/var/jb/usr/bin` に入れる。

リンクは `-lusb-1.0`、`-framework IOKit -framework CoreFoundation -framework Security`、
`-Wl,-stack_size,0x800000`（Siano と同じ）。`LDFLAGS` の `-rpath ${JB}/usr/lib` は
ドライバ側で付く。

## 使い方（端末）

PATH の `px4d` / `px4-ts` / `px4ctl` は Mach-O ラッパー。`--runtime-dir` を
省略すると `$HOME/.px4-userland` を 0700 で作り、渡す
（validate_directory はこれ以外を INVALID_ARGUMENT にする）。
実体は `${JB}/usr/lib/px4-userland/`。`--firmware` 省略時、
`${JB}/usr/share/px4-userland/it930x-firmware.bin` があれば px4d だけが使う
（パッケージはファームを同梱しない。置くのは運用側）。

シリアルは Q3U4 の 14 桁 base serial、または MLT5 系の 15 桁 USB serial。
`px4-usb-probe` は PX-Q3U4 のシリアルを出す（それ以外の機種は上流が UNSUPPORTED で拒否する）。

```sh
px4-usb-probe
px4d --device '<serial>'
px4ctl --device '<serial>' list
px4-ts --device '<serial>' \
  --receiver 2 --system isdb-t --frequency-khz 527143 \
  --output - --duration-seconds 5
```

`--help` はチューナー未接続でも動く。

内蔵カードを PC/SC にするときは、`pcscd`（launchd、root）と同じユーザーで
`px4d` を上げてから登録する。ソケットは `access=user`（0600）。

```sh
sudo px4d --device '<serial>' --firmware /path/to/firmware.bin \
  --runtime-dir "$runtime_dir"
sudo px4-pcsc-register '<serial>' "$runtime_dir"
```

conf は `/var/jb/etc/reader.conf.d/px4-userland.conf`。serial と runtime-dir は
plist に焼かない。
