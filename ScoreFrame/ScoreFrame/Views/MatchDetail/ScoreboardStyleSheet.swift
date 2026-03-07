import SwiftUI

struct ScoreboardStyleSheet: View {
    @Bindable var match: Match
    @Environment(\.dismiss) private var dismiss
    @State private var style: ScoreboardStyle
    let thumbnail: UIImage?
    let videoAspectRatio: CGFloat
    var onSave: (() -> Void)?

    // 編集対象
    enum EditTarget: CaseIterable {
        case scoreboard
        case matchInfo

        var displayName: LocalizedStringKey {
            switch self {
            case .scoreboard: return "スコアボード"
            case .matchInfo: return "試合情報"
            }
        }
    }
    @State private var editTarget: EditTarget = .scoreboard

    // ジェスチャー用ベース値（スコアボード）
    @State private var baseScale: CGFloat = 1.0
    @State private var basePosition: CGPoint = .zero

    // ジェスチャー用ベース値（試合情報）
    @State private var baseMatchInfoScale: CGFloat = 1.0
    @State private var baseMatchInfoPosition: CGPoint = .zero

    init(match: Match, thumbnail: UIImage? = nil, videoAspectRatio: CGFloat = 16.0 / 9.0, onSave: (() -> Void)? = nil) {
        self.match = match
        self.thumbnail = thumbnail
        self.videoAspectRatio = videoAspectRatio
        self.onSave = onSave
        let s = match.scoreboardStyle
        self._style = State(initialValue: s)
        self._baseScale = State(initialValue: s.scale)
        self._basePosition = State(initialValue: CGPoint(x: s.positionX, y: s.positionY))
        self._baseMatchInfoScale = State(initialValue: s.matchInfoScale)
        self._baseMatchInfoPosition = State(initialValue: CGPoint(x: s.matchInfoPositionX, y: s.matchInfoPositionY))
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
                            currentPeriodLabel: match.timerSegments.first?.periodLabel,
                            matchInfo: match.matchInfo,
                            pkKicks: match.pkKicks,
                            thumbnail: thumbnail,
                            videoAspectRatio: videoAspectRatio
                        )
                        .simultaneousGesture(dragGesture(in: geo.size))
                        .simultaneousGesture(magnificationGesture)
                    }
                    .aspectRatio(videoAspectRatio, contentMode: .fit)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text("プレビュー")
                } footer: {
                    VStack(spacing: 8) {
                        Picker("編集対象", selection: $editTarget) {
                            ForEach(EditTarget.allCases, id: \.self) { target in
                                Text(target.displayName).tag(target)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack {
                            Text("ピンチでサイズ変更・ドラッグで位置調整")
                                .font(.caption)
                            Spacer()
                            Button("リセット") {
                                if editTarget == .scoreboard {
                                    style.positionX = 0.02
                                    style.positionY = 0.02
                                    style.scale = 1.0
                                    baseScale = 1.0
                                    basePosition = CGPoint(x: 0.02, y: 0.02)
                                } else {
                                    style.matchInfoPositionX = 0.02
                                    style.matchInfoPositionY = 0.12
                                    style.matchInfoScale = 1.0
                                    baseMatchInfoScale = 1.0
                                    baseMatchInfoPosition = CGPoint(x: 0.02, y: 0.12)
                                }
                            }
                            .font(.caption)
                        }
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

                Section {
                    TextField("大会名・日程など", text: matchInfoBinding)
                } header: {
                    Text("試合情報")
                } footer: {
                    Text("スコアボード下部に表示されます")
                }

                Section("オプション") {
                    Toggle("スコア表示", isOn: $style.showScore)
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
                        onSave?()
                    }
                }
            }
        }
    }

    // MARK: - Match Info Binding

    private var matchInfoBinding: Binding<String> {
        Binding(
            get: { match.matchInfo ?? "" },
            set: { match.matchInfo = $0.isEmpty ? nil : $0 }
        )
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
                if editTarget == .scoreboard {
                    style.scale = clamp(baseScale * value, min: 0.5, max: 2.5)
                } else {
                    style.matchInfoScale = clamp(baseMatchInfoScale * value, min: 0.5, max: 2.5)
                }
            }
            .onEnded { _ in
                if editTarget == .scoreboard {
                    baseScale = style.scale
                } else {
                    baseMatchInfoScale = style.matchInfoScale
                }
            }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard size.width > 0, size.height > 0 else { return }
                let dx = value.translation.width / size.width
                let dy = value.translation.height / size.height
                if editTarget == .scoreboard {
                    style.positionX = clamp(basePosition.x + dx, min: 0, max: 0.95)
                    style.positionY = clamp(basePosition.y + dy, min: 0, max: 0.95)
                } else {
                    style.matchInfoPositionX = clamp(baseMatchInfoPosition.x + dx, min: 0, max: 0.95)
                    style.matchInfoPositionY = clamp(baseMatchInfoPosition.y + dy, min: 0, max: 0.95)
                }
            }
            .onEnded { _ in
                if editTarget == .scoreboard {
                    basePosition = CGPoint(x: style.positionX, y: style.positionY)
                } else {
                    baseMatchInfoPosition = CGPoint(x: style.matchInfoPositionX, y: style.matchInfoPositionY)
                }
            }
    }

    private func clamp(_ value: CGFloat, min minVal: CGFloat, max maxVal: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minVal), maxVal)
    }
}
