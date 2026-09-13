# px4-userland

ソースツリー: [`packages/px4-userland`](../packages/px4-userland)

[px4-userland](https://github.com/Khronos31/px4-userland) v0.1.3。
PLEX PX-Q3U4（USB ID `0511:084a`）向けのユーザー空間ドライバ。
カーネルモジュールは使わず、libusb で 8 チューナーと内蔵 IC カードリーダーを制御する。

## パッケージ情報

- ディレクトリ / `Package:`: `px4-userland`
- Sileo の `Name:`: PX4 Driver
- バイナリ: `px4d` / `px4-ts` / `px4ctl`
- 版: 0.1.3-2
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

未署名の Mach-O は起動時 SIGKILL（rc 137）。空の USB バスでは
`libusb_init` / `get_device_list` は薄い entitlements でも 0 件で成功する。
デバイスを **開く** ときに IOKit user-client が要る。

### libc++ `__libcpp_verbose_abort`

上流は `-fno-exceptions -fno-rtti`。Clang 19 の libc++ ヘッダは、その組み合わせで
`std::__1::__libcpp_verbose_abort` を呼ぶ。iOS 16.7 の `/usr/lib/libc++.1.dylib` には
このシンボルが無い。`files/libcpp_verbose_abort.cpp` をオブジェクトとしてリンクする。

### CMake

`PX4_BUILD_TESTS=OFF`、`PX4_BUILD_TOOLS=OFF`、`PX4_BUILD_PCSC_IFD=ON`。
IFD は macOS bundle ではなく `libpx4-userland-ifd.dylib`。pcsc-lite の
`dlopen` が読む。`ifdhandler.h` はビルド時に `libpcsclite-dev` から取る。
開発用 `px4-usb-probe` はパッケージに入れない。

リンクは `-lusb-1.0`、`-framework IOKit -framework CoreFoundation -framework Security`、
`-Wl,-stack_size,0x800000`（Siano と同じ）。`LDFLAGS` の `-rpath ${JB}/usr/lib` は
ドライバ側で付く。

## 使い方（端末）

iOS には `XDG_RUNTIME_DIR` が無い。必ず `--runtime-dir` を付ける。

```sh
runtime_dir=$(mktemp -d /tmp/px4-XXXXXX)
px4d --device '<14-digit-base-serial>' \
  --firmware /path/to/firmware.bin \
  --runtime-dir "$runtime_dir"

px4ctl --device '<14-digit-base-serial>' --runtime-dir "$runtime_dir" list
px4-ts --device '<14-digit-base-serial>' --runtime-dir "$runtime_dir" \
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
