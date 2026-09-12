<!--
題名: Add <Package> <version>  または  Update <Package> <version>
枝:   <package>-<version>（packages/ のディレクトリ名と pkgver）
先:   main
apt（gh-pages）はこの PR の範囲外。
-->

- [ ] 枝名は `packages/` のディレクトリ名と `pkgver` に一致する
- [ ] `packages/<package>/` を追加または更新した
- [ ] `docs/<package>.md` を追加または更新した
- [ ] README の収録表を更新した
- [ ] 端末で `./make.sh <package>` が通った
- [ ] 出来た `.deb` を実機で `dpkg -i` した
