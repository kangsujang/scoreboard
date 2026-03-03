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

                Text(TimeFormatting.format(seconds: playerVM.duration))
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}
