# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

ScoreFrame — サッカー動画にスコアボードをオーバーレイ合成するiOSアプリ。少年サッカー/草サッカーの試合動画に後からスコアボードを重ねてMP4エクスポートする。

## 技術スタック

- Swift / SwiftUI (iOS 17+)
- SwiftData (永続化)
- AVFoundation (動画合成・エクスポート)
- PhotosUI (動画選択)
- Xcodeプロジェクト: `ScoreFrame/ScoreFrame.xcodeproj`

## ビルド・実行

```bash
# Xcodeでビルド（コマンドライン）
xcodebuild -project ScoreFrame/ScoreFrame.xcodeproj -scheme ScoreFrame -destination 'platform=iOS Simulator,name=iPhone 16' build

# Xcodeで開く
open ScoreFrame/ScoreFrame.xcodeproj
```

テストスイートは未構成。

## アーキテクチャ

ソースは `ScoreFrame/ScoreFrame/` 配下。MVVM + Serviceパターン。

### 画面遷移

`Router`（`@Observable`）+ `NavigationStack` による宣言的ルーティング:
- `MatchListView` → `MatchSetupView` → `ScoreEditorView` → `MatchDetailView` → `ExportView`

`Route` enumで4画面を定義。`Router`は`@Environment`経由で全画面に共有。

### データモデル (SwiftData)

- **`Match`** — 試合。ホーム/アウェイチーム名、動画ブックマーク、スコアボードスタイル、タイマーセグメントを保持。`@Model`クラスでSwiftDataに永続化。
- **`ScoreEvent`** — 得点イベント。`Match`との`@Relationship`。チーム種別と動画内タイムスタンプを記録。
- **`ScoreboardStyle`** — スコアボードの見た目設定（テーマ、位置、スケール、チームカラー等）。`Codable`としてMatchのDataプロパティにJSON保存。
- **`TimerSegment`** — 前半/後半などのピリオド区切り。複数セグメント対応。`Codable`でJSON保存。
- **`Team`** — `.home` / `.away` のenum。

### 後方互換性

`Match`は旧形式（単一動画URL `videoBookmark`、単一タイマー `timerStartTime`/`timerStopTime`/`timerStartOffset`）と新形式（複数動画 `videoBookmarksData`、セグメント配列 `timerSegmentsData`）の両方をサポート。computed propertyで自動マイグレーション。

### 動画エクスポートパイプライン

エクスポートの中核部分は3つのServiceが連携:

1. **`VideoCompositionBuilder`** — 複数動画URLから`AVMutableComposition`を構築。回転補正（iPhone縦撮り対応）を含む。
2. **`ScoreboardLayerBuilder`** — CALayerツリーでスコアボードオーバーレイを構築。`CAKeyframeAnimation`のopacityアニメーションで得点変化・タイマー表示を実現。`AVVideoCompositionCoreAnimationTool`用のレイヤー。
3. **`VideoExportService`** — 上記2つを組み合わせて`AVAssetExportSession`でMP4出力。進捗監視付き。

### プレビューとエクスポートの一貫性

`ScoreboardPreviewView`（SwiftUI）と`ScoreboardLayerBuilder`（CALayer）は同じ`baseRatio`定数と寸法比率を共有し、画面プレビューとエクスポート結果が一致するよう設計されている。スタイル変更時は両方を同期させる必要がある。

### ViewModel層

- **`PlayerViewModel`** — `AVPlayer`のラッパー。再生/一時停止/シーク/再生速度を管理。複数動画対応（`VideoCompositionBuilder`経由）。
- **`ExportViewModel`** — エクスポート処理の状態管理。写真ライブラリへの保存も担当。

## 言語

UIテキスト・コミットメッセージは日本語。
