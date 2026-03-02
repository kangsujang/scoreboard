import SwiftUI

struct ScoreboardStyleSheet: View {
    @Bindable var match: Match
    @Environment(\.dismiss) private var dismiss
    @State private var style: ScoreboardStyle

    init(match: Match) {
        self.match = match
        self._style = State(initialValue: match.scoreboardStyle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("プレビュー") {
                    ScoreboardPreviewView(
                        homeTeamName: match.homeTeamName,
                        awayTeamName: match.awayTeamName,
                        homeScore: match.homeScore,
                        awayScore: match.awayScore,
                        style: style
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("位置") {
                    Picker("表示位置", selection: $style.position) {
                        ForEach(ScoreboardStyle.Position.allCases, id: \.self) { position in
                            Text(position.displayName).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("テーマ") {
                    Picker("テーマ", selection: $style.theme) {
                        ForEach(ScoreboardStyle.Theme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("フォントサイズ") {
                    Picker("フォントサイズ", selection: $style.fontSize) {
                        ForEach(ScoreboardStyle.FontSize.allCases, id: \.self) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
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
}
