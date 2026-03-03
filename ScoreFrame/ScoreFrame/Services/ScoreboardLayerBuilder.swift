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
        let scale = config.style.scale
        let padding: CGFloat = 10 * scale
        let teamFontSize: CGFloat = 18 * scale
        let scoreFontSize: CGFloat = 28 * scale
        let timerFontSize: CGFloat = 14 * scale

        let containerHeight: CGFloat = 48 * scale
        let containerWidth: CGFloat = min(config.videoSize.width * 0.55, 440 * scale)

        let container = CALayer()
        container.frame = containerFrame(
            style: config.style,
            videoSize: config.videoSize,
            containerSize: CGSize(width: containerWidth, height: containerHeight)
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

        // Score container — holds one CATextLayer per score state
        let scoreFrame = CGRect(
            x: containerWidth * 0.3,
            y: contentY,
            width: containerWidth * 0.25,
            height: scoreFontSize + 4
        )
        addScoreLayers(
            to: container,
            frame: scoreFrame,
            events: config.events,
            duration: config.videoDuration,
            fontSize: scoreFontSize,
            theme: config.style.theme
        )

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

        // Timer container — holds per-digit CATextLayers
        if config.style.showMatchTimer {
            let timerFrame = CGRect(
                x: containerWidth * 0.85,
                y: (containerHeight - timerFontSize - 4) / 2,
                width: containerWidth * 0.14,
                height: timerFontSize + 4
            )
            addTimerLayers(
                to: container,
                frame: timerFrame,
                duration: config.videoDuration,
                fontSize: timerFontSize,
                theme: config.style.theme
            )
        }

        return container
    }

    // MARK: - Position

    private static func containerFrame(
        style: ScoreboardStyle,
        videoSize: CGSize,
        containerSize: CGSize
    ) -> CGRect {
        let x = min(style.positionX * videoSize.width,
                     videoSize.width - containerSize.width)
        let y = min(style.positionY * videoSize.height,
                     videoSize.height - containerSize.height)
        return CGRect(
            origin: CGPoint(x: max(x, 0), y: max(y, 0)),
            size: containerSize
        )
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

    // MARK: - Score Animations (opacity-based layer switching)

    /// Each score state gets its own CATextLayer. Opacity animations show/hide them
    /// at the correct timestamps. This works reliably in AVVideoCompositionCoreAnimationTool
    /// unlike `CAKeyframeAnimation(keyPath: "string")`.
    private static func addScoreLayers(
        to container: CALayer,
        frame: CGRect,
        events: [ScoreEvent],
        duration: TimeInterval,
        fontSize: CGFloat,
        theme: ScoreboardStyle.Theme
    ) {
        let sorted = events.sorted { $0.timestamp < $1.timestamp }

        // Build score states: [(scoreString, startTime, endTime)]
        var states: [(string: String, start: Double, end: Double)] = []
        var home = 0
        var away = 0

        if sorted.isEmpty {
            // No events — static "0 - 0"
            states.append(("\(home) - \(away)", 0, duration))
        } else {
            // Initial state before first event
            states.append(("\(home) - \(away)", 0, sorted[0].timestamp))

            for (i, event) in sorted.enumerated() {
                switch event.team {
                case .home: home += 1
                case .away: away += 1
                }
                let start = event.timestamp
                let end = (i + 1 < sorted.count) ? sorted[i + 1].timestamp : duration
                states.append(("\(home) - \(away)", start, end))
            }
        }

        for state in states {
            let layer = makeTextLayer(
                fontSize: fontSize,
                alignment: .center,
                theme: theme,
                isScore: true
            )
            layer.string = state.string
            layer.frame = frame

            if states.count == 1 {
                // Only one state — always visible, no animation needed
                layer.opacity = 1.0
            } else {
                layer.opacity = 0.0

                let animation = CAKeyframeAnimation(keyPath: "opacity")
                let startFraction = duration > 0 ? state.start / duration : 0
                let endFraction = duration > 0 ? state.end / duration : 1

                animation.keyTimes = [
                    0.0,
                    NSNumber(value: max(0.0, startFraction)),
                    NSNumber(value: min(1.0, endFraction)),
                    1.0,
                ] as [NSNumber]
                animation.values = [
                    Float(0.0),
                    Float(1.0),
                    Float(0.0),
                    Float(0.0),
                ] as [Float]

                // First state: visible from the start
                if state.start == 0 {
                    animation.keyTimes = [
                        0.0,
                        NSNumber(value: min(1.0, endFraction)),
                        1.0,
                    ] as [NSNumber]
                    animation.values = [
                        Float(1.0),
                        Float(0.0),
                        Float(0.0),
                    ] as [Float]
                }

                // Last state: visible until the end
                if state.end >= duration {
                    animation.keyTimes = [
                        0.0,
                        NSNumber(value: max(0.0, startFraction)),
                        1.0,
                    ] as [NSNumber]
                    animation.values = [
                        Float(0.0),
                        Float(1.0),
                        Float(1.0),
                    ] as [Float]
                }

                // Only state spanning full duration
                if state.start == 0 && state.end >= duration {
                    animation.keyTimes = [0.0, 1.0] as [NSNumber]
                    animation.values = [Float(1.0), Float(1.0)] as [Float]
                }

                animation.calculationMode = .discrete
                animation.duration = duration
                animation.beginTime = AVCoreAnimationBeginTimeAtZero
                animation.isRemovedOnCompletion = false
                animation.fillMode = .forwards

                layer.add(animation, forKey: "scoreOpacity")
            }

            container.addSublayer(layer)
        }
    }

    // MARK: - Timer Animation (per-digit opacity layers)

    /// Creates per-digit CATextLayers with opacity animations for reliable timer rendering
    /// in AVVideoCompositionCoreAnimationTool export pipeline.
    ///
    /// Digit positions: [minuteTens][minuteOnes]:[secondTens][secondOnes]
    /// Each digit position has layers for each possible value (0-9 or 0-5).
    private static func addTimerLayers(
        to container: CALayer,
        frame: CGRect,
        duration: TimeInterval,
        fontSize: CGFloat,
        theme: ScoreboardStyle.Theme
    ) {
        let totalSeconds = Int(ceil(duration))
        guard totalSeconds > 0 else {
            let staticLabel = makeTextLayer(
                fontSize: fontSize,
                alignment: .center,
                theme: theme,
                isScore: false
            )
            staticLabel.string = "00:00"
            staticLabel.frame = frame
            container.addSublayer(staticLabel)
            return
        }

        // Calculate character widths for positioning
        let digitWidth = frame.width / 5.0  // 5 character slots: MM:SS
        let colonWidth = digitWidth * 0.6

        // Digit position X coordinates
        let minuteTensX = frame.origin.x
        let minuteOnesX = minuteTensX + digitWidth
        let colonX = minuteOnesX + digitWidth
        let secondTensX = colonX + colonWidth
        let secondOnesX = secondTensX + digitWidth

        // Static colon layer
        let colonLayer = makeTextLayer(
            fontSize: fontSize,
            alignment: .center,
            theme: theme,
            isScore: false
        )
        colonLayer.string = ":"
        colonLayer.frame = CGRect(x: colonX, y: frame.origin.y, width: colonWidth, height: frame.height)
        colonLayer.opacity = 1.0
        container.addSublayer(colonLayer)

        // Helper: build opacity keyframes for a digit at a given position
        // The digit should be visible (opacity 1) only when its value matches.
        func addDigitLayers(
            xPos: CGFloat,
            width: CGFloat,
            maxDigit: Int,
            digitExtractor: @escaping (Int) -> Int
        ) {
            for digit in 0...maxDigit {
                let layer = makeTextLayer(
                    fontSize: fontSize,
                    alignment: .center,
                    theme: theme,
                    isScore: false
                )
                layer.string = "\(digit)"
                layer.frame = CGRect(x: xPos, y: frame.origin.y, width: width, height: frame.height)
                layer.opacity = 0.0

                var keyTimes: [NSNumber] = []
                var values: [Float] = []

                var previousOpacity: Float = -1

                for second in 0...totalSeconds {
                    let currentDigit = digitExtractor(second)
                    let opacity: Float = (currentDigit == digit) ? 1.0 : 0.0

                    if opacity != previousOpacity {
                        let time = duration > 0 ? Double(second) / duration : 0
                        keyTimes.append(NSNumber(value: min(time, 1.0)))
                        values.append(opacity)
                        previousOpacity = opacity
                    }
                }

                // Ensure we end at time 1.0
                if let lastTime = keyTimes.last?.doubleValue, lastTime < 1.0 {
                    keyTimes.append(1.0)
                    values.append(values.last ?? 0.0)
                }

                guard keyTimes.count >= 2 else {
                    // Digit is either always visible or never visible
                    layer.opacity = values.first ?? 0.0
                    container.addSublayer(layer)
                    continue
                }

                let animation = CAKeyframeAnimation(keyPath: "opacity")
                animation.keyTimes = keyTimes
                animation.values = values
                animation.calculationMode = .discrete
                animation.duration = duration
                animation.beginTime = AVCoreAnimationBeginTimeAtZero
                animation.isRemovedOnCompletion = false
                animation.fillMode = .forwards

                layer.add(animation, forKey: "digitOpacity")
                container.addSublayer(layer)
            }
        }

        // Minute tens (0-9)
        addDigitLayers(xPos: minuteTensX, width: digitWidth, maxDigit: 9) { second in
            (second / 60) / 10
        }

        // Minute ones (0-9)
        addDigitLayers(xPos: minuteOnesX, width: digitWidth, maxDigit: 9) { second in
            (second / 60) % 10
        }

        // Second tens (0-5)
        addDigitLayers(xPos: secondTensX, width: digitWidth, maxDigit: 5) { second in
            (second % 60) / 10
        }

        // Second ones (0-9)
        addDigitLayers(xPos: secondOnesX, width: digitWidth, maxDigit: 9) { second in
            (second % 60) % 10
        }
    }
}
