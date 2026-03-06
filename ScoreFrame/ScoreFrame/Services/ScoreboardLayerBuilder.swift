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
        let timerSegments: [TimerSegment]
        let homeTeamColor: CGColor?
        let awayTeamColor: CGColor?
        let matchInfo: String?
        let pkKicks: [PKKick]
    }

    // MARK: - Public

    static func buildOverlayLayer(config: Config) -> CALayer {
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: config.videoSize)

        let container = buildContainerLayer(config: config)
        overlayLayer.addSublayer(container)

        // PK overlay (positioned below main scoreboard)
        if !config.pkKicks.isEmpty {
            let pkLayer = buildPKLayer(config: config, mainContainerFrame: container.frame)
            overlayLayer.addSublayer(pkLayer)
        }

        // Match info (independent position & scale)
        if let info = config.matchInfo, !info.isEmpty {
            let base = config.videoSize.width * ScoreboardPreviewView.baseRatio * config.style.matchInfoScale
            let infoLayer = buildMatchInfoLayer(
                info: info,
                base: base,
                theme: config.style.theme,
                style: config.style,
                videoSize: config.videoSize
            )
            overlayLayer.addSublayer(infoLayer)
        }

        return overlayLayer
    }

    // MARK: - Container

    private static func buildContainerLayer(config: Config) -> CALayer {
        // ScoreboardPreviewView と同じ baseRatio を使用して縮尺を統一
        // Preview: base = containerWidth * baseRatio → .scaleEffect(style.scale)
        // Export:  base = videoWidth   * baseRatio * style.scale
        let base = config.videoSize.width * ScoreboardPreviewView.baseRatio * config.style.scale

        // フォントサイズ（プレビューと同じ倍率）
        let periodFontSize = base * 0.55
        let timerFontSize  = base * 0.6
        let teamFontSize   = base * 0.65
        let scoreFontSize  = base * 0.85

        // レイアウト寸法（プレビューと同じ倍率）
        let circleSize   = base * 1.4
        let accentHeight = base * 0.125
        let gap          = base * 0.375   // メインセクション要素間隔
        let mainPaddingH = base * 0.5
        let mainPaddingV = base * 0.3125
        let cornerRadius = base * 0.375

        let theme = config.style.theme
        let showTimer = config.style.showMatchTimer
        let segments = config.timerSegments

        // ピリオド表記: 全セグメントのラベルから最長を基準に幅を決定
        let periodLabels = segments.compactMap { $0.periodLabel }.filter { !$0.isEmpty }
        let showPeriod = !periodLabels.isEmpty

        // ── セクション幅の計算 ──
        let periodPaddingH = base * 0.375
        let periodWidth: CGFloat
        if showPeriod {
            let maxLabelWidth = periodLabels.map { estimateTextWidth($0, fontSize: periodFontSize) }.max() ?? 0
            periodWidth = maxLabelWidth + periodPaddingH * 2
        } else {
            periodWidth = 0
        }

        let timerPaddingH = base * 0.5
        let timerTextWidth = estimateTextWidth("00:00", fontSize: timerFontSize, monospaced: true)
        let allSegmentsPK = !segments.isEmpty && segments.allSatisfy { ($0.periodLabel ?? "").lowercased() == "pk" }
        let timerWidth: CGFloat = (showTimer && !allSegmentsPK) ? timerTextWidth + timerPaddingH * 2 : 0

        let homeTextWidth = estimateTextWidth(config.homeTeamName, fontSize: teamFontSize)
        let awayTextWidth = estimateTextWidth(config.awayTeamName, fontSize: teamFontSize)
        let teamNamePadding = teamFontSize * 2  // 2文字分の余白（片側）
        let homeAreaWidth = homeTextWidth + teamNamePadding * 2
        let awayAreaWidth = awayTextWidth + teamNamePadding * 2
        let showScore = config.style.showScore
        let vsFontSize = base * 0.6
        let vsTextWidth = estimateTextWidth("vs", fontSize: vsFontSize)
        let mainContentWidth: CGFloat
        if showScore {
            mainContentWidth = homeAreaWidth + gap + circleSize + gap + circleSize + gap + awayAreaWidth
        } else {
            mainContentWidth = homeAreaWidth + gap + vsTextWidth + gap + awayAreaWidth
        }
        let mainWidth = mainContentWidth + mainPaddingH * 2

        // ── コンテナサイズ ──
        let containerWidth = periodWidth + timerWidth + mainWidth
        let containerHeight = circleSize + mainPaddingV * 2

        let container = CALayer()
        container.frame = containerFrame(
            style: config.style,
            videoSize: config.videoSize,
            containerSize: CGSize(width: containerWidth, height: containerHeight)
        )

        applyThemeBackground(to: container, theme: theme, cornerRadius: cornerRadius)

        // ── Period label section (leftmost, white bg / black text) ──
        if showPeriod {
            let periodBg = CALayer()
            periodBg.frame = CGRect(x: 0, y: 0, width: periodWidth, height: containerHeight)
            periodBg.backgroundColor = UIColor.white.cgColor
            container.addSublayer(periodBg)

            let periodLabelFrame = CGRect(
                x: 0,
                y: (containerHeight - periodFontSize - 4) / 2,
                width: periodWidth,
                height: periodFontSize + 4
            )

            addPeriodLabelLayers(
                to: container,
                frame: periodLabelFrame,
                segments: segments,
                duration: config.videoDuration,
                fontSize: periodFontSize
            )
        }

        // ── Timer section (inverted background, after period label) ──
        // 全セグメントPKの場合は timerWidth=0 で既にスキップ済み
        if showTimer && !allSegmentsPK {
            let timerWrapper = CALayer()
            timerWrapper.frame = CGRect(x: periodWidth, y: 0, width: timerWidth, height: containerHeight)

            let timerBg = CALayer()
            timerBg.frame = CGRect(x: 0, y: 0, width: timerWidth, height: containerHeight)
            timerBg.backgroundColor = textColor(for: theme)
            timerWrapper.addSublayer(timerBg)

            let timerFrame = CGRect(
                x: 0,
                y: (containerHeight - timerFontSize - 4) / 2,
                width: timerWidth,
                height: timerFontSize + 4
            )
            addTimerLayers(
                to: timerWrapper,
                frame: timerFrame,
                duration: config.videoDuration,
                fontSize: timerFontSize,
                timerTextColor: invertedTextColor(for: theme),
                segments: segments
            )

            // PKセグメントが混在する場合、PK区間でタイマーを非表示
            if segments.contains(where: { ($0.periodLabel ?? "").lowercased() == "pk" }) {
                addPKHideAnimation(to: timerWrapper, segments: segments, duration: config.videoDuration)
            }

            container.addSublayer(timerWrapper)
        }

        // ── Main content area (team names + score circles) ──
        // 垂直位置の計算
        let centerY = containerHeight / 2
        let circleY = centerY - circleSize / 2

        let teamTextFrameH = teamFontSize + 4
        let vStackSpacing = base * 0.125
        let teamVStackH = teamTextFrameH + vStackSpacing + accentHeight
        let teamVStackY = centerY - teamVStackH / 2
        let accentY = teamVStackY + teamTextFrameH + vStackSpacing

        // 左から順に X 座標を進める
        var x = periodWidth + timerWidth + mainPaddingH

        // Home team name（左右に teamNamePadding 分の余白）
        x += teamNamePadding
        let homeLabel = makeTextLayer(
            fontSize: teamFontSize,
            alignment: .center,
            color: textColor(for: theme),
            weight: .semibold
        )
        homeLabel.string = config.homeTeamName
        homeLabel.frame = CGRect(x: x, y: teamVStackY, width: homeTextWidth, height: teamTextFrameH)
        container.addSublayer(homeLabel)

        let homeAccent = CALayer()
        homeAccent.frame = CGRect(x: x, y: accentY, width: homeTextWidth, height: accentHeight)
        homeAccent.backgroundColor = config.homeTeamColor ?? scoreColor(for: theme)
        container.addSublayer(homeAccent)

        x += homeTextWidth + teamNamePadding + gap

        if showScore {
            // Home score circle
            let homeCircleWrapper = CALayer()
            homeCircleWrapper.frame = CGRect(x: x, y: circleY, width: circleSize, height: circleSize)

            let homeCircleBg = CALayer()
            homeCircleBg.frame = CGRect(x: 0, y: 0, width: circleSize, height: circleSize)
            homeCircleBg.backgroundColor = textColor(for: theme)
            homeCircleBg.cornerRadius = circleSize / 2
            homeCircleWrapper.addSublayer(homeCircleBg)

            let homeScoreFrame = CGRect(
                x: 0,
                y: (circleSize - scoreFontSize - 4) / 2,
                width: circleSize,
                height: scoreFontSize + 4
            )
            addSingleTeamScoreLayers(
                to: homeCircleWrapper,
                frame: homeScoreFrame,
                events: config.events,
                team: .home,
                duration: config.videoDuration,
                fontSize: scoreFontSize,
                textColor: invertedTextColor(for: theme)
            )

            addScorePulseAnimation(
                to: homeCircleWrapper,
                events: config.events,
                team: .home,
                duration: config.videoDuration
            )
            container.addSublayer(homeCircleWrapper)

            x += circleSize + gap

            // Away score circle
            let awayCircleWrapper = CALayer()
            awayCircleWrapper.frame = CGRect(x: x, y: circleY, width: circleSize, height: circleSize)

            let awayCircleBg = CALayer()
            awayCircleBg.frame = CGRect(x: 0, y: 0, width: circleSize, height: circleSize)
            awayCircleBg.backgroundColor = textColor(for: theme)
            awayCircleBg.cornerRadius = circleSize / 2
            awayCircleWrapper.addSublayer(awayCircleBg)

            let awayScoreFrame = CGRect(
                x: 0,
                y: (circleSize - scoreFontSize - 4) / 2,
                width: circleSize,
                height: scoreFontSize + 4
            )
            addSingleTeamScoreLayers(
                to: awayCircleWrapper,
                frame: awayScoreFrame,
                events: config.events,
                team: .away,
                duration: config.videoDuration,
                fontSize: scoreFontSize,
                textColor: invertedTextColor(for: theme)
            )

            addScorePulseAnimation(
                to: awayCircleWrapper,
                events: config.events,
                team: .away,
                duration: config.videoDuration
            )
            container.addSublayer(awayCircleWrapper)

            x += circleSize + gap
        } else {
            // "vs" separator
            let vsLayer = makeTextLayer(
                fontSize: vsFontSize,
                alignment: .center,
                color: textColor(for: theme),
                weight: .semibold
            )
            vsLayer.string = "vs"
            vsLayer.opacity = 0.6
            let vsFrameH = vsFontSize + 4
            vsLayer.frame = CGRect(
                x: x,
                y: centerY - vsFrameH / 2,
                width: vsTextWidth,
                height: vsFrameH
            )
            container.addSublayer(vsLayer)
            x += vsTextWidth + gap
        }

        // Away team name（左右に teamNamePadding 分の余白）
        x += teamNamePadding
        let awayLabel = makeTextLayer(
            fontSize: teamFontSize,
            alignment: .center,
            color: textColor(for: theme),
            weight: .semibold
        )
        awayLabel.string = config.awayTeamName
        awayLabel.frame = CGRect(x: x, y: teamVStackY, width: awayTextWidth, height: teamTextFrameH)
        container.addSublayer(awayLabel)

        let awayAccent = CALayer()
        awayAccent.frame = CGRect(x: x, y: accentY, width: awayTextWidth, height: accentHeight)
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

    // MARK: - Match Info

    private static func buildMatchInfoLayer(
        info: String,
        base: CGFloat,
        theme: ScoreboardStyle.Theme,
        style: ScoreboardStyle,
        videoSize: CGSize
    ) -> CALayer {
        let fontSize = base * 0.45
        let paddingH = base * 0.5
        let paddingV = base * 0.2
        let cornerRadius = base * 0.375

        let textWidth = estimateTextWidth(info, fontSize: fontSize)
        let layerWidth = textWidth + paddingH * 2
        let layerHeight = fontSize + 4 + paddingV * 2

        let x = min(style.matchInfoPositionX * videoSize.width,
                     videoSize.width - layerWidth)
        let y = min(style.matchInfoPositionY * videoSize.height,
                     videoSize.height - layerHeight)

        let infoContainer = CALayer()
        infoContainer.frame = CGRect(
            x: max(x, 0),
            y: max(y, 0),
            width: layerWidth,
            height: layerHeight
        )
        applyThemeBackground(to: infoContainer, theme: theme, cornerRadius: cornerRadius)

        let textLayer = makeTextLayer(
            fontSize: fontSize,
            alignment: .natural,
            color: textColor(for: theme),
            weight: .medium
        )
        textLayer.string = info
        textLayer.frame = CGRect(
            x: paddingH,
            y: paddingV,
            width: textWidth,
            height: fontSize + 4
        )
        infoContainer.addSublayer(textLayer)

        return infoContainer
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

    // MARK: - Text Measurement

    private static func estimateTextWidth(_ text: String, fontSize: CGFloat, monospaced: Bool = false) -> CGFloat {
        let font = monospaced
            ? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
            : UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        return ceil(size.width)
    }

    // MARK: - Text Layers

    private static func makeTextLayer(
        fontSize: CGFloat,
        alignment: CATextLayerAlignmentMode,
        color: CGColor,
        weight: UIFont.Weight = .medium,
        monospaced: Bool = false
    ) -> CATextLayer {
        let layer = CATextLayer()
        layer.fontSize = fontSize
        if monospaced {
            layer.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: weight)
        } else {
            layer.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        }
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

    // MARK: - Score Pulse Animation

    /// Adds a scale pulse animation to the score circle wrapper at each goal timestamp.
    private static func addScorePulseAnimation(
        to layer: CALayer,
        events: [ScoreEvent],
        team: Team,
        duration: TimeInterval
    ) {
        let teamEvents = events.filter { $0.team == team }.sorted { $0.timestamp < $1.timestamp }
        guard !teamEvents.isEmpty, duration > 0 else { return }

        let pulseDuration: TimeInterval = 0.3
        var keyTimes: [NSNumber] = [0.0]
        var values: [Float] = [1.0]

        for event in teamEvents {
            let startFrac = event.timestamp / duration
            let peakFrac = (event.timestamp + pulseDuration * 0.4) / duration
            let endFrac = (event.timestamp + pulseDuration) / duration

            guard startFrac < 1.0 else { continue }

            keyTimes.append(NSNumber(value: min(startFrac, 1.0)))
            values.append(1.0)
            keyTimes.append(NSNumber(value: min(peakFrac, 1.0)))
            values.append(1.2)
            keyTimes.append(NSNumber(value: min(endFrac, 1.0)))
            values.append(1.0)
        }

        if let lastTime = keyTimes.last?.doubleValue, lastTime < 1.0 {
            keyTimes.append(1.0)
            values.append(1.0)
        }

        guard keyTimes.count >= 3 else { return }

        // anchorPoint を中心に設定してスケールが中心基点になるようにする
        let bounds = layer.bounds
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(
            x: layer.frame.origin.x + bounds.width / 2,
            y: layer.frame.origin.y + bounds.height / 2
        )

        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.keyTimes = keyTimes
        animation.values = values
        animation.calculationMode = .linear
        animation.duration = duration
        animation.beginTime = AVCoreAnimationBeginTimeAtZero
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards

        layer.add(animation, forKey: "scorePulse")
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
    /// Supports multiple timer segments with independent start/stop/offset.
    private static func addTimerLayers(
        to container: CALayer,
        frame: CGRect,
        duration: TimeInterval,
        fontSize: CGFloat,
        timerTextColor: CGColor,
        segments: [TimerSegment]
    ) {
        let totalSeconds = Int(ceil(duration))
        guard totalSeconds > 0 else {
            let staticLabel = makeTextLayer(
                fontSize: fontSize,
                alignment: .center,
                color: timerTextColor,
                weight: .semibold,
                monospaced: true
            )
            staticLabel.string = "00:00"
            staticLabel.frame = frame
            container.addSublayer(staticLabel)
            return
        }

        // モノスペースフォントの実測値から文字幅を算出し、フレーム中央に配置
        let textWidth = estimateTextWidth("00:00", fontSize: fontSize, monospaced: true)
        let charWidth = textWidth / 5.0
        let textStartX = frame.origin.x + (frame.width - textWidth) / 2

        let minuteTensX = textStartX
        let minuteOnesX = textStartX + charWidth
        let colonX = textStartX + charWidth * 2
        let secondTensX = textStartX + charWidth * 3
        let secondOnesX = textStartX + charWidth * 4

        // Static colon layer
        let colonLayer = makeTextLayer(
            fontSize: fontSize,
            alignment: .center,
            color: timerTextColor,
            weight: .semibold,
            monospaced: true
        )
        colonLayer.string = ":"
        colonLayer.frame = CGRect(x: colonX, y: frame.origin.y, width: charWidth, height: frame.height)
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
                    weight: .semibold,
                    monospaced: true
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

        /// マルチセグメント対応: 動画秒数 → 試合経過秒数
        /// effectiveStartTime〜timerStartTime の間はオフセット値（初期値）を表示
        /// timerStartTime 以降はタイマー計測を開始
        /// セグメント外の区間はフリーズ（直前セグメントの最終値を維持）
        func matchSecond(from videoSecond: Int) -> Int {
            let videoTime = TimeInterval(videoSecond)
            var lastMatchSecond = 0

            for seg in segments {
                let effStart = seg.effectiveStartTime
                guard let kickoff = seg.timerStartTime ?? effStart else { continue }
                let segStart = effStart ?? kickoff
                let stop = seg.timerStopTime ?? duration
                let offset = Int(seg.timerStartOffset ?? 0)

                if videoTime >= segStart && videoTime <= stop {
                    if videoTime < kickoff {
                        // 区切り開始〜キックオフ前: オフセット値（初期値）を表示
                        return offset
                    }
                    // キックオフ以降: タイマー計測
                    let elapsed = max(0, videoSecond - Int(kickoff))
                    return elapsed + offset
                } else if videoTime > stop {
                    // このセグメントを通過済み → 最終値を記録
                    let elapsed = max(0, Int(stop) - Int(kickoff))
                    lastMatchSecond = elapsed + offset
                } else {
                    break
                }
            }

            return lastMatchSecond
        }

        addDigitLayers(xPos: minuteTensX, width: charWidth, maxDigit: 9) { second in
            (matchSecond(from: second) / 60) / 10
        }

        addDigitLayers(xPos: minuteOnesX, width: charWidth, maxDigit: 9) { second in
            (matchSecond(from: second) / 60) % 10
        }

        addDigitLayers(xPos: secondTensX, width: charWidth, maxDigit: 5) { second in
            (matchSecond(from: second) % 60) / 10
        }

        addDigitLayers(xPos: secondOnesX, width: charWidth, maxDigit: 9) { second in
            (matchSecond(from: second) % 60) % 10
        }
    }

    // MARK: - Period Label Animation (multi-segment)

    /// Creates opacity-animated CATextLayers for period labels, switching based on segment time ranges.
    private static func addPeriodLabelLayers(
        to container: CALayer,
        frame: CGRect,
        segments: [TimerSegment],
        duration: TimeInterval,
        fontSize: CGFloat
    ) {
        // 各セグメントのラベルに対してテキストレイヤーを作成し、
        // そのセグメントの時間範囲でのみ表示する
        struct LabelSpan {
            let label: String
            let start: TimeInterval
            let end: TimeInterval
        }

        var spans: [LabelSpan] = []
        for (i, seg) in segments.enumerated() {
            guard let label = seg.periodLabel, !label.isEmpty else { continue }
            let start = seg.effectiveStartTime ?? 0
            // 次のセグメントの実効開始時刻、または動画終了まで
            let end: TimeInterval
            if i + 1 < segments.count, let nextStart = segments[i + 1].effectiveStartTime {
                end = nextStart
            } else {
                end = duration
            }
            spans.append(LabelSpan(label: label, start: start, end: end))
        }

        // 最初のセグメント開始前の表示: 最初のスパンのラベルを使う
        if let first = spans.first, first.start > 0 {
            spans[0] = LabelSpan(label: first.label, start: 0, end: first.end)
        }

        let states = spans.map { (string: $0.label, start: $0.start, end: $0.end) }

        addOpacityAnimatedTextLayers(
            to: container,
            frame: frame,
            states: states,
            duration: duration,
            fontSize: fontSize,
            textColor: UIColor.black.cgColor,
            fontWeight: .bold
        )
    }

    // MARK: - PK Overlay Layer

    private static func buildPKLayer(config: Config, mainContainerFrame: CGRect) -> CALayer {
        let base = config.videoSize.width * ScoreboardPreviewView.baseRatio * config.style.scale
        let teamFontSize = base * 0.5
        let markSize = base * 0.55
        let markWidth = base * 0.7
        let markSpacing = base * 0.15
        let rowSpacing = base * 0.2
        let paddingH = base * 0.4
        let paddingV = base * 0.25
        let cornerRadius = base * 0.375

        let homePK = config.pkKicks.filter { $0.team == .home }.sorted { $0.order < $1.order }
        let awayPK = config.pkKicks.filter { $0.team == .away }.sorted { $0.order < $1.order }
        let maxKicks = max(homePK.count, awayPK.count, 1)

        let teamNameWidth = max(
            estimateTextWidth(config.homeTeamName, fontSize: teamFontSize),
            estimateTextWidth(config.awayTeamName, fontSize: teamFontSize)
        )

        let marksWidth = CGFloat(maxKicks) * (markWidth + markSpacing)
        let containerWidth = paddingH + teamNameWidth + markSpacing + marksWidth + paddingH
        let rowHeight = markSize + 4
        let containerHeight = paddingV + rowHeight + rowSpacing + rowHeight + paddingV

        let gap = base * 0.25
        let containerX = mainContainerFrame.origin.x
        let containerY = mainContainerFrame.maxY + gap

        let container = CALayer()
        container.frame = CGRect(x: containerX, y: containerY, width: containerWidth, height: containerHeight)
        applyThemeBackground(to: container, theme: config.style.theme, cornerRadius: cornerRadius)

        // Home row
        buildPKRow(
            in: container, teamName: config.homeTeamName, kicks: homePK,
            y: paddingV, teamFontSize: teamFontSize, markSize: markSize,
            markWidth: markWidth, markSpacing: markSpacing, paddingH: paddingH,
            teamNameWidth: teamNameWidth, theme: config.style.theme,
            videoDuration: config.videoDuration
        )

        // Away row
        buildPKRow(
            in: container, teamName: config.awayTeamName, kicks: awayPK,
            y: paddingV + rowHeight + rowSpacing, teamFontSize: teamFontSize,
            markSize: markSize, markWidth: markWidth, markSpacing: markSpacing,
            paddingH: paddingH, teamNameWidth: teamNameWidth,
            theme: config.style.theme, videoDuration: config.videoDuration
        )

        // PKセグメント開始時のみ表示
        addPKShowAnimation(to: container, segments: config.timerSegments, duration: config.videoDuration)

        return container
    }

    private static func buildPKRow(
        in container: CALayer,
        teamName: String,
        kicks: [PKKick],
        y: CGFloat,
        teamFontSize: CGFloat,
        markSize: CGFloat,
        markWidth: CGFloat,
        markSpacing: CGFloat,
        paddingH: CGFloat,
        teamNameWidth: CGFloat,
        theme: ScoreboardStyle.Theme,
        videoDuration: TimeInterval
    ) {
        let nameLayer = makeTextLayer(
            fontSize: teamFontSize, alignment: .natural,
            color: textColor(for: theme), weight: .semibold
        )
        nameLayer.string = teamName
        nameLayer.frame = CGRect(x: paddingH, y: y, width: teamNameWidth, height: markSize + 4)
        container.addSublayer(nameLayer)

        for (i, kick) in kicks.enumerated() {
            let x = paddingH + teamNameWidth + markSpacing + CGFloat(i) * (markWidth + markSpacing)
            let markText = kick.isGoal ? "◯" : "✗"
            let markColor = kick.isGoal
                ? UIColor.systemGreen.cgColor
                : UIColor.systemRed.cgColor

            let markLayer = makeTextLayer(
                fontSize: markSize, alignment: .center,
                color: markColor, weight: .bold
            )
            markLayer.string = markText
            markLayer.frame = CGRect(x: x, y: y, width: markWidth, height: markSize + 4)
            markLayer.opacity = 0

            let fraction = videoDuration > 0 ? kick.timestamp / videoDuration : 0
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            animation.keyTimes = [0.0, NSNumber(value: max(0, fraction)), 1.0]
            animation.values = [Float(0), Float(1), Float(1)] as [Float]
            animation.calculationMode = .discrete
            animation.duration = videoDuration
            animation.beginTime = AVCoreAnimationBeginTimeAtZero
            animation.isRemovedOnCompletion = false
            animation.fillMode = .forwards
            markLayer.add(animation, forKey: "markAppear")

            container.addSublayer(markLayer)
        }
    }

    /// PKセグメント中のみPKオーバーレイを表示するアニメーション
    private static func addPKShowAnimation(
        to layer: CALayer,
        segments: [TimerSegment],
        duration: TimeInterval
    ) {
        guard duration > 0, !segments.isEmpty else { return }

        struct Span {
            let start: TimeInterval
            let end: TimeInterval
            let isPK: Bool
        }

        var spans: [Span] = []
        for (i, seg) in segments.enumerated() {
            let start = seg.effectiveStartTime ?? 0
            let end: TimeInterval
            if i + 1 < segments.count, let nextStart = segments[i + 1].effectiveStartTime {
                end = nextStart
            } else {
                end = duration
            }
            let isPK = (seg.periodLabel ?? "").lowercased() == "pk"
            spans.append(Span(start: start, end: end, isPK: isPK))
        }

        if spans[0].start > 0 {
            spans[0] = Span(start: 0, end: spans[0].end, isPK: spans[0].isPK)
        }

        var keyTimes: [NSNumber] = []
        var values: [Float] = []

        for span in spans {
            let startFrac = span.start / duration
            keyTimes.append(NSNumber(value: min(startFrac, 1.0)))
            values.append(span.isPK ? 1.0 : 0.0)
        }

        if let lastTime = keyTimes.last?.doubleValue, lastTime < 1.0 {
            keyTimes.append(1.0)
            values.append(values.last ?? 0.0)
        }

        guard keyTimes.count >= 2 else { return }

        layer.opacity = 0
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.keyTimes = keyTimes
        animation.values = values
        animation.calculationMode = .discrete
        animation.duration = duration
        animation.beginTime = AVCoreAnimationBeginTimeAtZero
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        layer.add(animation, forKey: "pkShow")
    }

    // MARK: - PK Hide Animation

    /// PKセグメント中はタイマーセクション全体を非表示にするopacityアニメーションを追加
    private static func addPKHideAnimation(
        to layer: CALayer,
        segments: [TimerSegment],
        duration: TimeInterval
    ) {
        guard duration > 0, !segments.isEmpty else { return }

        struct Span {
            let start: TimeInterval
            let end: TimeInterval
            let isPK: Bool
        }

        var spans: [Span] = []
        for (i, seg) in segments.enumerated() {
            let start = seg.effectiveStartTime ?? 0
            let end: TimeInterval
            if i + 1 < segments.count, let nextStart = segments[i + 1].effectiveStartTime {
                end = nextStart
            } else {
                end = duration
            }
            let isPK = (seg.periodLabel ?? "").lowercased() == "pk"
            spans.append(Span(start: start, end: end, isPK: isPK))
        }

        // 最初のスパン開始前は最初のスパンの状態を使う
        if spans[0].start > 0 {
            spans[0] = Span(start: 0, end: spans[0].end, isPK: spans[0].isPK)
        }

        var keyTimes: [NSNumber] = []
        var values: [Float] = []

        for span in spans {
            let startFrac = span.start / duration
            keyTimes.append(NSNumber(value: min(startFrac, 1.0)))
            values.append(span.isPK ? 0.0 : 1.0)
        }

        if let lastTime = keyTimes.last?.doubleValue, lastTime < 1.0 {
            keyTimes.append(1.0)
            values.append(values.last ?? 1.0)
        }

        guard keyTimes.count >= 2 else { return }

        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.keyTimes = keyTimes
        animation.values = values
        animation.calculationMode = .discrete
        animation.duration = duration
        animation.beginTime = AVCoreAnimationBeginTimeAtZero
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards

        layer.add(animation, forKey: "pkHideTimer")
    }
}
