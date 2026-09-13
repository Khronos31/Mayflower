# pcsc-lite

ソースツリー: [`packages/pcsc-lite`](../packages/pcsc-lite)

[pcsc-lite](https://pcsclite.apdu.fr/) 2.5.1 を、rootless 脱獄 iOS 上でセルフビルドする。

## パッケージ情報

- 版: 2.5.1-3
- `libpcsclite1`: `libpcsclite.1.dylib`
- `pcscd`: デーモン `/usr/sbin/pcscd`
- `libpcsclite-dev`: `PCSC/*.h` と `libpcsclite.pc`

Procursus に同名は無い。recisdb は `pkg-config --libs libpcsclite` を見る。

## ビルドの要点

meson + ninja + flex。meson は `pip` で `BUILDROOT/pydeps` に入れる（システムには置かない）。

Procursus の `ninja` は `posix_spawn("/bin/sh")` するため rootless では即死する。
ビルド中だけコピーを `/tmp/sh`（`/var/jb/bin/sh` へのリンク）に差し替えて使う。

```
-Dlibsystemd=false -Dlibudev=false -Dlibusb=false -Dpolkit=false
-Dusb=true -Dserial=true
-Dipcdir=/var/jb/var/run/pcscd
-Dusbdropdir=/var/jb/usr/lib/pcsc/drivers
-Dserialconfdir=/var/jb/etc/reader.conf.d
```

USB ホットプラグは切る。`reader.conf.d` 経由の IFD（px4-userland）が先。
uname が Darwin なので meson は macOS 用 `hotplug_macosx.c` を足そうとするが、
iOS SDK に `IOCFPlugIn.h` が無い。IFD は `dyn_unix.c` の `dlopen`。

## 端末

```sh
sudo apt install flex
./make.sh pcsc-lite
sudo dpkg -i packages/pcsc-lite/arm64/libpcsclite1_*.deb \
  packages/pcsc-lite/arm64/pcscd_*.deb \
  packages/pcsc-lite/arm64/libpcsclite-dev_*.deb
pcscd --version
```

`pcscd` は systemd ではなく launchd（`fr.apdu.pcscd`、`--foreground`）。
plist は `/var/jb/Library/LaunchDaemons/`。postinst が `launchctl bootstrap system` する。
ログは `/var/jb/var/log/pcscd.log`。

クライアントは Linux SONAME `libpcsclite_real.so.1` を `dlopen` するので、
Darwin の `libpcsclite_real.1.dylib` へ symlink を置く。

Q3U4 内蔵リーダーは、このあと px4-userland の IFD を ON にして `reader.conf.d` に載せる。
