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
        let timerStartTime: TimeInterval?
        let timerStopTime: TimeInterval?
        let timerStartOffset: TimeInterval?
        let homeTeamColor: CGColor?
        let awayTeamColor: CGColor?
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
        let scoreFontSize: CGFloat = 24 * scale
        let timerFontSize: CGFloat = 14 * scale
        let accentHeight: CGFloat = 3 * scale
        let circleSize: CGFloat = 34 * scale
        let circleGap: CGFloat = 4 * scale

        let containerHeight: CGFloat = 48 * scale
        let containerWidth: CGFloat = min(config.videoSize.width * 0.55, 480 * scale)

        let container = CALayer()
        container.frame = containerFrame(
            style: config.style,
            videoSize: config.videoSize,
            containerSize: CGSize(width: containerWidth, height: containerHeight)
        )

        applyThemeBackground(to: container, theme: config.style.theme, cornerRadius: 6)

        let theme = config.style.theme
        let showTimer = config.style.showMatchTimer
        let timerWidth: CGFloat = showTimer ? containerWidth * 0.22 : 0

        // ── Timer section (LEFT, inverted background) ──
        if showTimer {
            let timerBg = CALayer()
            timerBg.frame = CGRect(x: 0, y: 0, width: timerWidth, height: containerHeight)
            timerBg.backgroundColor = textColor(for: theme)
            container.addSublayer(timerBg)

            let timerFrame = CGRect(
                x: 0,
                y: (containerHeight - timerFontSize - 4) / 2,
                width: timerWidth,
                height: timerFontSize + 4
            )
            addTimerLayers(
                to: container,
                frame: timerFrame,
                duration: config.videoDuration,
                fontSize: timerFontSize,
                timerTextColor: invertedTextColor(for: theme),
                timerStartTime: config.timerStartTime,
                timerStopTime: config.timerStopTime,
                timerStartOffset: config.timerStartOffset
            )
        }

        // ── Main content area (team names + score circles) ──
        let mainX = timerWidth
        let mainWidth = containerWidth - timerWidth
        let contentY: CGFloat = (containerHeight - accentHeight - circleSize) / 2

        // Home team name (always theme text color)
        let homeLabel = makeTextLayer(
            fontSize: teamFontSize,
            alignment: .right,
            color: textColor(for: theme),
            weight: .semibold
        )
        homeLabel.string = config.homeTeamName
        homeLabel.frame = CGRect(
            x: mainX + padding,
            y: (containerHeight - accentHeight - teamFontSize - 4) / 2,
            width: mainWidth * 0.30,
            height: teamFontSize + 4
        )
        container.addSublayer(homeLabel)

        // Score circles — centered in main area
        let circlesWidth = circleSize * 2 + circleGap
        let circlesCenterX = mainX + mainWidth / 2
        let homeCircleX = circlesCenterX - circlesWidth / 2
        let awayCircleX = homeCircleX + circleSize + circleGap

        // Home score circle
        let homeCircleBg = CALayer()
        homeCircleBg.frame = CGRect(x: homeCircleX, y: contentY, width: circleSize, height: circleSize)
        homeCircleBg.backgroundColor = textColor(for: theme)
        homeCircleBg.cornerRadius = circleSize / 2
        container.addSublayer(homeCircleBg)

        let homeScoreFrame = CGRect(
            x: homeCircleX,
            y: contentY + (circleSize - scoreFontSize - 4) / 2,
            width: circleSize,
            height: scoreFontSize + 4
        )
        addSingleTeamScoreLayers(
            to: container,
            frame: homeScoreFrame,
            events: config.events,
            team: .home,
            duration: config.videoDuration,
            fontSize: scoreFontSize,
            textColor: invertedTextColor(for: theme)
        )

        // Away score circle
        let awayCircleBg = CALayer()
        awayCircleBg.frame = CGRect(x: awayCircleX, y: contentY, width: circleSize, height: circleSize)
        awayCircleBg.backgroundColor = textColor(for: theme)
        awayCircleBg.cornerRadius = circleSize / 2
        container.addSublayer(awayCircleBg)

        let awayScoreFrame = CGRect(
            x: awayCircleX,
            y: contentY + (circleSize - scoreFontSize - 4) / 2,
            width: circleSize,
            height: scoreFontSize + 4
        )
        addSingleTeamScoreLayers(
            to: container,
            frame: awayScoreFrame,
            events: config.events,
            team: .away,
            duration: config.videoDuration,
            fontSize: scoreFontSize,
            textColor: invertedTextColor(for: theme)
        )

        // Away team name (always theme text color)
        let awayLabel = makeTextLayer(
            fontSize: teamFontSize,
            alignment: .left,
            color: textColor(for: theme),
            weight: .semibold
        )
        awayLabel.string = config.awayTeamName
        awayLabel.frame = CGRect(
            x: containerWidth - mainWidth * 0.30 - padding,
            y: (containerHeight - accentHeight - teamFontSize - 4) / 2,
            width: mainWidth * 0.30,
            height: teamFontSize + 4
        )
        container.addSublayer(awayLabel)

        // ── Accent lines under team names only ──
        let homeAccent = CALayer()
        homeAccent.frame = CGRect(
            x: homeLabel.frame.origin.x,
            y: containerHeight - accentHeight,
            width: homeLabel.frame.width,
            height: accentHeight
        )
        homeAccent.backgroundColor = config.homeTeamColor ?? scoreColor(for: theme)
        container.addSublayer(homeAccent)

        let awayAccent = CALayer()
        awayAccent.frame = CGRect(
            x: awayLabel.frame.origin.x,
            y: containerHeight - accentHeight,
            width: awayLabel.frame.width,
            height: accentHeight
        )
        awayAccent.backgroundColor = config.awayTeamColor ?? scoreColor(for: theme)
        container.addSublayer(awayAccent)

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

    /// Inverted text color (for timer section and score circle text)
    private static func invertedTextColor(for theme: ScoreboardStyle.Theme) -> CGColor {
        switch theme {
        case .dark, .broadcast, .minimal:
            return UIColor.black.cgColor
        case .light:
            return UIColor.white.cgColor
        }
    }

    private static func scoreColor(for theme: ScoreboardStyle.Theme) -> CGColor {
        switch theme {
        case .dark:
            return UIColor(red: 1.0, green: 0.843, blue: 0.0, alpha: 1.0).cgColor
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
        color: CGColor,
        weight: UIFont.Weight = .medium
    ) -> CATextLayer {
        let layer = CATextLayer()
        layer.fontSize = fontSize
        layer.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        layer.foregroundColor = color
        layer.alignmentMode = alignment
        layer.contentsScale = UIScreen.main.scale
        layer.truncationMode = .end
        return layer
    }

    // MARK: - Single-Team Score Animation

    /// Creates opacity-animated text layers for one team's score.
    private static func addSingleTeamScoreLayers(
        to container: CALayer,
        frame: CGRect,
        events: [ScoreEvent],
        team: Team,
        duration: TimeInterval,
        fontSize: CGFloat,
        textColor: CGColor
    ) {
        let sorted = events.sorted { $0.timestamp < $1.timestamp }
        var states: [(string: String, start: Double, end: Double)] = []
        var score = 0

        // Collect timestamps where this team scored
        var teamTimestamps: [(timestamp: Double, newScore: Int)] = []
        for event in sorted where event.team == team {
            score += 1
            teamTimestamps.append((event.timestamp, score))
        }

        if teamTimestamps.isEmpty {
            states.append(("0", 0, duration))
        } else {
            states.append(("0", 0, teamTimestamps[0].timestamp))
            for (i, ts) in teamTimestamps.enumerated() {
                let end = (i + 1 < teamTimestamps.count) ? teamTimestamps[i + 1].timestamp : duration
                states.append(("\(ts.newScore)", ts.timestamp, end))
            }
        }

        addOpacityAnimatedTextLayers(
            to: container,
            frame: frame,
            states: states,
            duration: duration,
            fontSize: fontSize,
            textColor: textColor,
            fontWeight: .bold
        )
    }

    // MARK: - Opacity Animation Helper

    /// Creates opacity-animated text layers from a sequence of timed states.
    private static func addOpacityAnimatedTextLayers(
        to container: CALayer,
        frame: CGRect,
        states: [(string: String, start: Double, end: Double)],
        duration: TimeInterval,
        fontSize: CGFloat,
        textColor: CGColor,
        fontWeight: UIFont.Weight = .bold
    ) {
        for state in states {
            let layer = CATextLayer()
            layer.fontSize = fontSize
            layer.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
            layer.foregroundColor = textColor
            layer.alignmentMode = .center
            layer.contentsScale = UIScreen.main.scale
            layer.truncationMode = .end
            layer.string = state.string
            layer.frame = frame

            if states.count == 1 {
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

                if state.start == 0 && state.end >= duration {
                    animation.keyTimes = [0.0, 1.0] as [NSNumber]
                    animation.values = [Float(1.0), Float(1.0)] as [Float]
                }

                animation.calculationMode = .discrete
                animation.duration = duration
                animation.beginTime = AVCoreAnimationBeginTimeAtZero
                animation.isRemovedOnCompletion = false
                animation.fillMode = .forwards

                layer.add(animation, forKey: "textOpacity")
            }

            container.addSublayer(layer)
        }
    }

    // MARK: - Timer Animation (per-digit opacity layers)

    /// Creates per-digit CATextLayers with opacity animations for reliable timer rendering
    /// in AVVideoCompositionCoreAnimationTool export pipeline.
    private static func addTimerLayers(
        to container: CALayer,
        frame: CGRect,
        duration: TimeInterval,
        fontSize: CGFloat,
        timerTextColor: CGColor,
        timerStartTime: TimeInterval? = nil,
        timerStopTime: TimeInterval? = nil,
        timerStartOffset: TimeInterval? = nil
    ) {
        let startOffset = timerStartTime ?? 0
        let initialTime = Int(timerStartOffset ?? 0)
        let maxMatchTime: Int? = if let stop = timerStopTime {
            Int(ceil(stop - startOffset)) + initialTime
        } else {
            nil
        }

        let totalSeconds = Int(ceil(duration))
        guard totalSeconds > 0 else {
            let staticLabel = makeTextLayer(
                fontSize: fontSize,
                alignment: .center,
                color: timerTextColor,
                weight: .semibold
            )
            staticLabel.string = "00:00"
            staticLabel.frame = frame
            container.addSublayer(staticLabel)
            return
        }

        // Calculate character widths for positioning
        let digitWidth = frame.width / 5.0
        let colonWidth = digitWidth * 0.6

        let minuteTensX = frame.origin.x
        let minuteOnesX = minuteTensX + digitWidth
        let colonX = minuteOnesX + digitWidth
        let secondTensX = colonX + colonWidth
        let secondOnesX = secondTensX + digitWidth

        // Static colon layer
        let colonLayer = makeTextLayer(
            fontSize: fontSize,
            alignment: .center,
            color: timerTextColor,
            weight: .semibold
        )
        colonLayer.string = ":"
        colonLayer.frame = CGRect(x: colonX, y: frame.origin.y, width: colonWidth, height: frame.height)
        colonLayer.opacity = 1.0
        container.addSublayer(colonLayer)

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
                    color: timerTextColor,
                    weight: .semibold
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

                if let lastTime = keyTimes.last?.doubleValue, lastTime < 1.0 {
                    keyTimes.append(1.0)
                    values.append(values.last ?? 0.0)
                }

                guard keyTimes.count >= 2 else {
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

        func matchSecond(from videoSecond: Int) -> Int {
            var s = max(0, videoSecond - Int(startOffset)) + initialTime
            if let cap = maxMatchTime { s = min(s, cap) }
            return s
        }

        addDigitLayers(xPos: minuteTensX, width: digitWidth, maxDigit: 9) { second in
            (matchSecond(from: second) / 60) / 10
        }

        addDigitLayers(xPos: minuteOnesX, width: digitWidth, maxDigit: 9) { second in
            (matchSecond(from: second) / 60) % 10
        }

        addDigitLayers(xPos: secondTensX, width: digitWidth, maxDigit: 5) { second in
            (matchSecond(from: second) % 60) / 10
        }

        addDigitLayers(xPos: secondOnesX, width: digitWidth, maxDigit: 9) { second in
            (matchSecond(from: second) % 60) % 10
        }
    }
}
