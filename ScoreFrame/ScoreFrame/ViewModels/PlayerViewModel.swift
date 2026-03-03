import AVFoundation

@MainActor
@Observable
final class PlayerViewModel {
    let player: AVPlayer
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isPlaying = false

    // nonisolated(unsafe) needed for deinit access from @MainActor @Observable class
    private nonisolated(unsafe) var timeObserver: Any?
    private nonisolated(unsafe) var statusObservation: NSKeyValueObservation?
    private nonisolated(unsafe) var rateObservation: NSKeyValueObservation?

    init(url: URL) {
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: item)

        setupObservers()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        statusObservation?.invalidate()
        rateObservation?.invalidate()
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to seconds: TimeInterval) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func skipForward(_ seconds: TimeInterval = 5) {
        let target = min(currentTime + seconds, duration)
        seek(to: target)
    }

    func skipBackward(_ seconds: TimeInterval = 5) {
        let target = max(currentTime - seconds, 0)
        seek(to: target)
    }

    private func setupObservers() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.safeSeconds
            }
        }

        statusObservation = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .readyToPlay {
                Task { @MainActor in
                    self?.duration = item.duration.safeSeconds
                }
            }
        }

        rateObservation = player.observe(\.rate, options: [.new]) { [weak self] _, change in
            Task { @MainActor in
                self?.isPlaying = (change.newValue ?? 0) > 0
            }
        }
    }
}
