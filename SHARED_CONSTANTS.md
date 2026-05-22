# OverScore 共有定数

iOS版とAndroid版で一致させるべき定数・カラー値の一覧。
変更時は両プラットフォームを同時に更新すること。

## スコアボード描画

| 定数 | 値 | iOS参照 | Android参照 |
|------|-----|---------|-------------|
| baseRatio | 0.044 | ScoreboardPreviewView.swift, ScoreboardLayerBuilder.swift | ScoreboardPreviewView.kt |
| デフォルトpositionX | 0.02 | ScoreboardStyle.swift | ScoreboardStyle.kt |
| デフォルトpositionY | 0.02 | ScoreboardStyle.swift | ScoreboardStyle.kt |
| デフォルトscale | 1.0 | ScoreboardStyle.swift | ScoreboardStyle.kt |
| matchInfo positionY | 0.12 | ScoreboardStyle.swift | ScoreboardStyle.kt |

## テーマカラー

| テーマ | 背景色 | テキスト色 | スコア色 |
|--------|--------|-----------|---------|
| Dark | black @ 0.7 | white | gold (1.0, 0.843, 0.0) |
| Light | white @ 0.8 | black | blue |
| Broadcast | (0.1, 0.1, 0.3) @ 0.85 | white | gold |
| Minimal | black @ 0.4 | white | white |

## ペナルティタイマー デフォルト秒数

- 120秒 (2分)
- 300秒 (5分)
- 600秒 (10分)

## ピリオドラベル プリセット

| 日本語 | 英語 |
|--------|------|
| 前半 | 1st Half |
| 後半 | 2nd Half |
| 延前 | ET 1st |
| 延後 | ET 2nd |
| PK | PK |
