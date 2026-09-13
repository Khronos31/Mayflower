# sd

ソースツリー: [`packages/sd`](../packages/sd)

直感的な find & replace（`sed` 代替）。

## パッケージ情報

- 版: 1.1.0（GitHub タグ。Cargo workspace 表記は 1.0.0）
- パッケージ: `sd`
- ビルド: **端末**（Mayflower rustc、`--offline` + `vendor.tar.gz`）
- Procursus: 無し

## 端末

```sh
./make.sh sd
sudo dpkg -i packages/sd/arm64/sd_*.deb
sd --version
```
