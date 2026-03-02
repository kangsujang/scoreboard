import QuartzCore
import AVFoundation
import UIKit

struct ScoreboardLayerBuilder {

    struct Config {
        let homeTeamName: String
        let awayTeamName: String
        let events: [ScoreEvent]
        let style: ScoreboardStyle
        let videoSize: CGSize
        let videoDuration: TimeInterval
    }

    // MARK: - Public

    static func buildOverlayLayer(config: Config) -> CALayer {
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: config.videoSize)

        let container = buildContainerLayer(config: config)
        overlayLayer.addSublayer(container)

        return overlayLayer
    }

    // MARK: - Container

    private static func buildContainerLayer(config: Config) -> CALayer {
        let scale = config.style.fontSize.scaleFactor
        let padding: CGFloat = 8 * scale
        let teamFontSize: CGFloat = 14 * scale
        let scoreFontSize: CGFloat = 20 * scale
        let timerFontSize: CGFloat = 12 * scale

        let containerHeight: CGFloat = 36 * scale
        let containerWidth: CGFloat = min(config.videoSize.width * 0.45, 360 * scale)

        let container = CALayer()
        container.frame = containerFrame(
            position: config.style.position,
            videoSize: config.videoSize,
            containerSize: CGSize(width: containerWidth, height: containerHeight),
            margin: 16
        )

        applyThemeBackground(to: container, theme: config.style.theme, cornerRadius: 8)

        let contentY: CGFloat = (containerHeight - scoreFontSize) / 2

        // Home team name
        let homeLabel = makeTextLayer(
            fontSize: teamFontSize,
            alignment: .right,
            theme: config.style.theme,
            isScore: false
        )
        homeLabel.string = config.homeTeamName
        homeLabel.frame = CGRect(
            x: padding,
            y: contentY + (scoreFontSize - teamFontSize) / 2,
            width: containerWidth * 0.25,
            height: teamFontSize + 4
        )
        container.addSublayer(homeLabel)

        // Score
        let scoreLabel = makeTextLayer(
            fontSize: scoreFontSize,
            alignment: .center,
            theme: config.style.theme,
            isScore: true
        )
        scoreLabel.frame = CGRect(
            x: containerWidth * 0.3,
            y: contentY,
            width: containerWidth * 0.25,
            height: scoreFontSize + 4
        )
        addScoreAnimations(
            to: scoreLabel,
            events: config.events,
            duration: config.videoDuration
        )
        container.addSublayer(scoreLabel)

        // Away team name
        let awayLabel = makeTextLayer(
            fontSize: teamFontSize,
            alignment: .left,
            theme: config.style.theme,
            isScore: false
        )
        awayLabel.string = config.awayTeamName
        awayLabel.frame = CGRect(
            x: containerWidth * 0.6,
            y: contentY + (scoreFontSize - teamFontSize) / 2,
            width: containerWidth * 0.25,
            height: teamFontSize + 4
        )
        container.addSublayer(awayLabel)

        // Timer
        if config.style.showMatchTimer {
            let timerLabel = makeTextLayer(
                fontSize: timerFontSize,
                alignment: .center,
                theme: config.style.theme,
                isScore: false
            )
            timerLabel.frame = CGRect(
                x: containerWidth * 0.85,
                y: (containerHeight - timerFontSize - 4) / 2,
                width: containerWidth * 0.14,
                height: timerFontSize + 4
            )
            addTimerAnimation(
                to: timerLabel,
                duration: config.videoDuration
            )
            container.addSublayer(timerLabel)
        }

        return container
    }

    // MARK: - Position

    private static func containerFrame(
        position: ScoreboardStyle.Position,
        videoSize: CGSize,
        containerSize: CGSize,
        margin: CGFloat
    ) -> CGRect {
        let y = margin
        let x: CGFloat
        switch position {
        case .topLeft:
            x = margin
        case .topCenter:
            x = (videoSize.width - containerSize.width) / 2
        case .topRight:
            x = videoSize.width - containerSize.width - margin
        }
        return CGRect(origin: CGPoint(x: x, y: y), size: containerSize)
    }

    // MARK: - Theme

    private static func applyThemeBackground(to layer: CALayer, theme: ScoreboardStyle.Theme, cornerRadius: CGFloat) {
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = true

        switch theme {
        case .dark:
            layer.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
        case .light:
            layer.backgroundColor = UIColor.white.withAlphaComponent(0.8).cgColor
        case .broadcast:
            layer.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 0.85).cgColor
        case .minimal:
            layer.backgroundColor = UIColor.black.withAlphaComponent(0.4).cgColor
        }
    }

    private static func textColor(for theme: ScoreboardStyle.Theme) -> CGColor {
        switch theme {
        case .dark, .broadcast, .minimal:
            return UIColor.white.cgColor
        case .light:
            return UIColor.black.cgColor
        }
    }

    private static func scoreColor(for theme: ScoreboardStyle.Theme) -> CGColor {
        switch theme {
        case .dark:
            return UIColor(red: 1.0, green: 0.843, blue: 0.0, alpha: 1.0).cgColor // #FFD700
        case .light:
            return UIColor.systemBlue.cgColor
        case .broadcast:
            return UIColor(red: 1.0, green: 0.843, blue: 0.0, alpha: 1.0).cgColor
        case .minimal:
            return UIColor.white.cgColor
        }
    }

    // MARK: - Text Layers

    private static func makeTextLayer(
        fontSize: CGFloat,
        alignment: CATextLayerAlignmentMode,
        theme: ScoreboardStyle.Theme,
        isScore: Bool
    ) -> CATextLayer {
        let layer = CATextLayer()
        layer.fontSize = fontSize
        layer.font = UIFont.systemFont(
            ofSize: fontSize,
            weight: isScore ? .bold : .medium
        )
        layer.foregroundColor = isScore ? scoreColor(for: theme) : textColor(for: theme)
        layer.alignmentMode = alignment
        layer.contentsScale = UIScreen.main.scale
        layer.truncationMode = .end
        return layer
    }

    // MARK: - Score Animations

    private static func addScoreAnimations(
        to layer: CATextLayer,
        events: [ScoreEvent],
        duration: TimeInterval
    ) {
        let sorted = events.sorted { $0.timestamp < $1.timestamp }

        guard !sorted.isEmpty else {
            layer.string = "0 - 0"
            return
        }

        var keyTimes: [NSNumber] = [0.0]
        var values: [String] = ["0 - 0"]

        var home = 0
        var away = 0

        for event in sorted {
            switch event.team {
            case .home: home += 1
            case .away: away += 1
            }
            let normalizedTime = duration > 0 ? event.timestamp / duration : 0
            keyTimes.append(NSNumber(value: max(0.001, min(normalizedTime, 0.999))))
            values.append("\(home) - \(away)")
        }

        // Hold final score
        keyTimes.append(1.0)
        values.append("\(home) - \(away)")

        let animation = CAKeyframeAnimation(keyPath: "string")
        animation.values = values
        animation.keyTimes = keyTimes
        animation.calculationMode = .discrete
        animation.duration = duration
        animation.beginTime = AVCoreAnimationBeginTimeAtZero
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards

        layer.add(animation, forKey: "scoreChange")
        layer.string = "0 - 0"
    }

    // MARK: - Timer Animation

    private static func addTimerAnimation(
        to layer: CATextLayer,
        duration: TimeInterval
    ) {
        let totalSeconds = Int(ceil(duration))
        guard totalSeconds > 0 else {
            layer.string = "00:00"
            return
        }

        var values: [String] = []
        var keyTimes: [NSNumber] = []

        for second in 0...totalSeconds {
            let minutes = second / 60
            let secs = second % 60
            values.append(String(format: "%02d:%02d", minutes, secs))
            keyTimes.append(NSNumber(value: Double(second) / duration))
        }

        let animation = CAKeyframeAnimation(keyPath: "string")
        animation.values = values
        animation.keyTimes = keyTimes
        animation.calculationMode = .discrete
        animation.duration = duration
        animation.beginTime = AVCoreAnimationBeginTimeAtZero
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards

        layer.add(animation, forKey: "timer")
        layer.string = "00:00"
    }
}
