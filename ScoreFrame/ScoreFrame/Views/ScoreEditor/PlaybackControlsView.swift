import SwiftUI

struct PlaybackControlsView: View {
    @Bindable var playerVM: PlayerViewModel

    var body: some View {
        VStack(spacing: 8) {
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
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 24) {
                    Button {
                        playerVM.skipBackward()
                    } label: {
                        Image(systemName: "gobackward.5")
                            .font(.title3)
                    }

                    Button {
                        playerVM.togglePlayback()
                    } label: {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }

                    Button {
                        playerVM.skipForward()
                    } label: {
                        Image(systemName: "goforward.5")
                            .font(.title3)
                    }
                }

                Spacer()

                Text(TimeFormatting.format(seconds: playerVM.duration))
                    .monospacedDigit()
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}
