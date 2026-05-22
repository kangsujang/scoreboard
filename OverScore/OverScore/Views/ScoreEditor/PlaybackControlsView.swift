import SwiftUI

struct PlaybackControlsView: View {
    @Bindable var playerVM: PlayerViewModel

    var body: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { playerVM.currentTime },
                    set: { playerVM.seek(to: $0) }
                ),
                in: 0...max(playerVM.duration, 1)
            )
            .tint(.accentColor)

            HStack {
                Text(TimeFormatting.format(seconds: playerVM.currentTime))
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 20) {
                    Button {
                        playerVM.skipBackward()
                    } label: {
                        Image(systemName: "gobackward.5")
                            .font(.body)
                    }

                    Button {
                        playerVM.togglePlayback()
                    } label: {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                    }

                    Button {
                        playerVM.skipForward()
                    } label: {
                        Image(systemName: "goforward.5")
                            .font(.body)
                    }
                }

                Spacer()

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
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }

                Text(TimeFormatting.format(seconds: playerVM.duration))
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}
