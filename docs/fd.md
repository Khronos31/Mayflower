# fd

ソースツリー: [`packages/fd`](../packages/fd)

sharkdp の `find` 代替。

## パッケージ情報

- 版: 10.5.0
- パッケージ: `fd-10` / `fd-default`
- ビルド: **端末**（Mayflower rustc 1.98 / cargo、`--offline` + `vendor.tar.gz`）
- Procursus: `fd` 8.6.0 を `fd-default` で置換

## 端末

```sh
# Mac で vendor（初回・版上げ時）
# tar xf fd-10.5.0.tar.gz && cd fd-10.5.0 && cargo vendor vendor
# tar -czf packages/fd/vendor.tar.gz vendor

./make.sh fd
sudo dpkg -i packages/fd/arm64/fd-10_*.deb packages/fd/arm64/fd-default_*.deb
fd --version
```

`vendor.tar.gz` は crates.io が端末から 403 になり得るための同梱物。
