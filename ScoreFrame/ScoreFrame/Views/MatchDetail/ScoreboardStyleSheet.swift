import SwiftUI

struct ScoreboardStyleSheet: View {
    @Bindable var match: Match
    @Environment(\.dismiss) private var dismiss
    @State private var style: ScoreboardStyle
    let thumbnail: UIImage?

    // ジェスチャー用ベース値
    @State private var baseScale: CGFloat = 1.0
    @State private var basePosition: CGPoint = .zero

    init(match: Match, thumbnail: UIImage? = nil) {
        self.match = match
        self.thumbnail = thumbnail
        let s = match.scoreboardStyle
        self._style = State(initialValue: s)
        self._baseScale = State(initialValue: s.scale)
        self._basePosition = State(initialValue: CGPoint(x: s.positionX, y: s.positionY))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    GeometryReader { geo in
                        ScoreboardPreviewView(
                            homeTeamName: match.homeTeamName,
                            awayTeamName: match.awayTeamName,
                            homeScore: match.homeScore,
                            awayScore: match.awayScore,
                            style: style,
                            thumbnail: thumbnail
                        )
                        .simultaneousGesture(dragGesture(in: geo.size))
                        .simultaneousGesture(magnificationGesture)
                    }
                    .aspectRatio(16/9, contentMode: .fit)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text("プレビュー")
                } footer: {
                    HStack {
                        Text("ピンチでサイズ変更・ドラッグで位置調整")
                            .font(.caption)
                        Spacer()
                        Button("リセット") {
                            style.positionX = 0.02
                            style.positionY = 0.02
                            style.scale = 1.0
                            baseScale = 1.0
                            basePosition = CGPoint(x: 0.02, y: 0.02)
                        }
                        .font(.caption)
                    }
                }

                Section("テーマ") {
                    Picker("テーマ", selection: $style.theme) {
                        ForEach(ScoreboardStyle.Theme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("チームカラー") {
                    ColorPicker(
                        "ホーム: \(match.homeTeamName)",
                        selection: homeColorBinding,
                        supportsOpacity: false
                    )
                    ColorPicker(
                        "アウェイ: \(match.awayTeamName)",
                        selection: awayColorBinding,
                        supportsOpacity: false
                    )
                    if style.homeTeamColorHex != nil || style.awayTeamColorHex != nil {
                        Button("デフォルトに戻す") {
                            style.homeTeamColorHex = nil
                            style.awayTeamColorHex = nil
                        }
                    }
                }

                Section("オプション") {
                    Toggle("タイマー表示", isOn: $style.showMatchTimer)
                }
            }
            .navigationTitle("スコアボード設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        match.scoreboardStyle = style
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Color Bindings

    private var homeColorBinding: Binding<Color> {
        Binding(
            get: { style.homeTeamColor ?? Color.scoreboardText(for: style.theme) },
            set: { style.homeTeamColor = $0 }
        )
    }

    private var awayColorBinding: Binding<Color> {
        Binding(
            get: { style.awayTeamColor ?? Color.scoreboardText(for: style.theme) },
            set: { style.awayTeamColor = $0 }
        )
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                style.scale = clamp(baseScale * value, min: 0.5, max: 2.5)
            }
            .onEnded { _ in
                baseScale = style.scale
            }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard size.width > 0, size.height > 0 else { return }
                let dx = value.translation.width / size.width
                let dy = value.translation.height / size.height
                style.positionX = clamp(basePosition.x + dx, min: 0, max: 0.95)
                style.positionY = clamp(basePosition.y + dy, min: 0, max: 0.95)
            }
            .onEnded { _ in
                basePosition = CGPoint(x: style.positionX, y: style.positionY)
            }
    }

    private func clamp(_ value: CGFloat, min minVal: CGFloat, max maxVal: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minVal), maxVal)
    }
}
