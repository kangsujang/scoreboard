import SwiftUI

struct PlaybackControlsView: View {
    @Bindable var playerVM: PlayerViewModel

    /// 誤タップを防ぐためのタップ領域サイズ（Appleの推奨44ptを上回る値）
    private let controlWidth: CGFloat = 72
    private let controlHeight: CGFloat = 48

    var body: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { playerVM.currentTime },
                    set: { playerVM.seek(to: $0) }
                ),
                in: 0...max(playerVM.duration, 1)
            )
            .tint(.accentColor)

            // 時刻表示と再生速度（副次的な操作）を1行にまとめ、
            // 下の再生コントロール行を大きなボタンだけに使えるようにする
            HStack(spacing: 8) {
                Text(TimeFormatting.format(seconds: playerVM.currentTime))
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(TimeFormatting.format(seconds: playerVM.duration))
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                rateMenu
            }

            // 5秒戻す / 再生 / 5秒進める（間隔を空けて押し間違いを防ぐ）
            HStack(spacing: 20) {
                skipButton(
                    systemImage: "gobackward.5",
                    label: String(localized: "5秒戻す"),
                    action: { playerVM.skipBackward() }
                )

                Button {
                    playerVM.togglePlayback()
                } label: {
                    Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: controlWidth, height: controlHeight)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playerVM.isPlaying ? String(localized: "一時停止") : String(localized: "再生"))

                skipButton(
                    systemImage: "goforward.5",
                    label: String(localized: "5秒進める"),
                    action: { playerVM.skipForward() }
                )
            }
        }
        .padding(.horizontal)
    }

    private var rateMenu: some View {
        Menu {
            ForEach([1.0, 1.25, 1.5, 2.0, 4.0], id: \.self) { rate in
                Button {
                    playerVM.playbackRate = Float(rate)
                    if playerVM.isPlaying {
                        playerVM.player.rate = Float(rate)
                    }
                } label: {
                    HStack {
                        Text(rate == 1.0 ? "1x" : "\(rate, specifier: "%g")x")
                        if playerVM.playbackRate == Float(rate) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(playerVM.playbackRate == 1.0 ? "1x" : "\(Double(playerVM.playbackRate), specifier: "%g")x")
                .font(.footnote.weight(.medium))
                .frame(width: 46, height: 32)
                .contentShape(Rectangle())
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel("再生速度")
    }

    private func skipButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: controlWidth, height: controlHeight)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
