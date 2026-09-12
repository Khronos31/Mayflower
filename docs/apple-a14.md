# apple-a14

ソースツリー: [`packages/apple-a14`](../packages/apple-a14)

中身の無いゲートパッケージ。A14（ARMv8.5-A）未満では apt / Sileo が入れない。

## パッケージ情報

- `Package:` `apple-a14`
- Sileo の `Name:` `A14 (ARMv8.5-A)`
- 版: 1.0-1
- `Depends: cy+model.iphone (>= 13.1) | cy+model.ipad (>= 13.1)`

Cydia / Procursus の `firmware.sh` は `hw.machine`（例: `iPhone13,1`）のカンマを
ドットにしたものを `cy+model.iphone` の版にする。iPhone 8 は `iPhone10,1` →
`cy+model.iphone` 10.1。iPhone 12 mini は `iPhone13,1` → 13.1。iPad Air
（第4世代）は `iPad13,1` → `cy+model.ipad` 13.1。どちらも A14。

Claude Code（darwin-arm64、v8.5 命令を含む）はこのパッケージに Depends する。
