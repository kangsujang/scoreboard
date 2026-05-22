package com.scoreframe.service

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import com.scoreframe.model.Match
import com.scoreframe.model.ScoreboardStyle

/**
 * Bitmap/Canvas上にスコアボードを描画するレンダラー。
 * iOS版の ScoreboardLayerBuilder / ScoreboardPreviewView に対応。
 *
 * レイアウト (timerPosition == left):
 * [PeriodLabel(白bg)] [Timer(textColor bg)] [TeamA ── (0)(0) ── TeamB]
 *
 * レイアウト (timerPosition == right):
 * [TeamA ── (0)(0) ── TeamB] [Timer(textColor bg)] [PeriodLabel(白bg)]
 */
class ScoreboardRenderer {

    companion object {
        const val BASE_RATIO = 0.044f
    }

    fun render(canvas: Canvas, match: Match, videoTimeSeconds: Double) {
        val style = match.scoreboardStyle
        val canvasWidth = canvas.width.toFloat()
        val canvasHeight = canvas.height.toFloat()
        val base = canvasWidth * BASE_RATIO * style.scale

        if (!style.showScore && !style.showMatchTimer) return

        val offsetX = canvasWidth * style.positionX
        val offsetY = canvasHeight * style.positionY

        drawScoreboardBar(canvas, match, videoTimeSeconds, style, base, offsetX, offsetY)

        // Match info (独立位置)
        val info = match.matchInfo
        if (!info.isNullOrBlank()) {
            val infoBase = canvasWidth * BASE_RATIO * style.matchInfoScale
            val infoX = canvasWidth * style.matchInfoPositionX
            val infoY = canvasHeight * style.matchInfoPositionY
            drawMatchInfo(canvas, info, style, infoBase, infoX, infoY)
        }
    }

    private fun drawScoreboardBar(
        canvas: Canvas,
        match: Match,
        videoTime: Double,
        style: ScoreboardStyle,
        base: Float,
        offsetX: Float,
        offsetY: Float
    ) {
        val theme = style.theme
        val bgColor = themeBackground(theme)
        val textColor = themeTextColor(theme)
        val timerTextColor = themeTimerTextColor(theme)
        val isPK = match.currentPeriodLabel(videoTime)?.lowercase() == "pk"

        // --- 寸法計算 ---
        val scoreCircleH = base * 1.4f
        val vertPad = base * 0.3125f
        val containerH = scoreCircleH + vertPad * 2
        val cornerRadius = base * 0.375f
        val mainGap = base * 0.375f
        val mainPadH = base * 0.5f

        val teamPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.DEFAULT_BOLD
            textSize = base * 0.65f
        }
        val scorePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.DEFAULT_BOLD
            textSize = base * 0.85f
        }
        val timerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.DEFAULT_BOLD
            textSize = base * 0.6f
        }
        val periodPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.DEFAULT_BOLD
            textSize = base * 0.55f
        }
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)

        // チーム名
        val homeNameW = teamPaint.measureText(match.homeTeamName)
        val awayNameW = teamPaint.measureText(match.awayTeamName)
        val teamPadEach = base * 0.65f * 2
        val homeTeamW = homeNameW + teamPadEach
        val awayTeamW = awayNameW + teamPadEach

        // スコア丸
        val (homeScore, awayScore) = match.scoreAt(videoTime)
        val homeScoreStr = "$homeScore"
        val awayScoreStr = "$awayScore"
        fun circleW(digitCount: Int) = if (digitCount <= 2) scoreCircleH else scoreCircleH + (digitCount - 2) * base * 0.7f
        val homeCircleW = circleW(homeScoreStr.length)
        val awayCircleW = circleW(awayScoreStr.length)
        val scoreW = if (style.showScore) homeCircleW + mainGap + awayCircleW else 0f

        // メインセクション幅
        val mainContentW = homeTeamW + mainGap + scoreW + mainGap + awayTeamW
        val mainSectionW = mainPadH + mainContentW + mainPadH

        // ピリオドラベル
        val periodLabel = match.currentPeriodLabel(videoTime)
        val periodTextW = if (!periodLabel.isNullOrEmpty()) periodPaint.measureText(periodLabel) else 0f
        val periodSectionW = if (periodTextW > 0) periodTextW + base * 0.375f * 2 else 0f

        // タイマー
        val timerText = getTimerText(match, videoTime, style, isPK)
        val timerTextW = if (timerText != null) timerPaint.measureText(timerText) else 0f
        val timerSectionW = if (timerTextW > 0) timerTextW + base * 0.5f * 2 else 0f

        // 全体幅
        val totalW = periodSectionW + timerSectionW + mainSectionW

        // --- 描画 ---
        val barRect = RectF(offsetX, offsetY, offsetX + totalW, offsetY + containerH)

        // クリップ
        canvas.save()
        val clipPath = Path().apply { addRoundRect(barRect, cornerRadius, cornerRadius, Path.Direction.CW) }
        canvas.clipPath(clipPath)

        // 1. メイン背景
        fillPaint.color = bgColor
        canvas.drawRect(barRect, fillPaint)

        var curX = offsetX
        val isLeft = style.timerPosition == ScoreboardStyle.TimerPosition.left

        // 左側セクション
        if (isLeft) {
            // ピリオドラベル背景
            if (periodSectionW > 0) {
                fillPaint.color = Color.WHITE
                canvas.drawRect(curX, offsetY, curX + periodSectionW, offsetY + containerH, fillPaint)
                periodPaint.color = Color.BLACK
                val py = offsetY + (containerH - periodPaint.descent() + periodPaint.ascent()) / 2f - periodPaint.ascent()
                canvas.drawText(periodLabel!!, curX + base * 0.375f, py, periodPaint)
                curX += periodSectionW
            }
            // タイマー背景
            if (timerSectionW > 0) {
                fillPaint.color = textColor
                canvas.drawRect(curX, offsetY, curX + timerSectionW, offsetY + containerH, fillPaint)
                val segment = match.activeTimerSegment(videoTime)
                val tColor = segment?.timerColorHex?.let { parseColor(it) } ?: timerTextColor
                timerPaint.color = tColor
                val ty = offsetY + (containerH - timerPaint.descent() + timerPaint.ascent()) / 2f - timerPaint.ascent()
                canvas.drawText(timerText!!, curX + base * 0.5f, ty, timerPaint)
                curX += timerSectionW
            }
        }

        // メインセクション
        val mainStartX = curX + mainPadH
        var mx = mainStartX

        // チーム名のY位置（アンダーライン含めた中央揃え）
        val teamMetrics = teamPaint.fontMetrics
        val teamTextH = -teamMetrics.ascent + teamMetrics.descent
        val underlineH = base * 0.125f
        val teamBlockH = teamTextH + base * 0.125f + underlineH  // text + gap + underline
        val nameY = offsetY + (containerH - teamBlockH) / 2f - teamMetrics.ascent
        val underlineY = nameY + teamMetrics.descent + base * 0.125f / 2f

        // ホームチーム名 + アンダーライン
        val homeColor = style.homeTeamColorHex?.let { parseColor(it) } ?: themeScoreColor(theme)
        teamPaint.color = textColor
        val homeTextX = mx + (homeTeamW - homeNameW) / 2f
        canvas.drawText(match.homeTeamName, homeTextX, nameY, teamPaint)
        fillPaint.color = homeColor
        canvas.drawRect(mx, underlineY, mx + homeTeamW, underlineY + underlineH, fillPaint)
        mx += homeTeamW + mainGap

        // スコア丸
        if (style.showScore) {
            fun drawScoreCircle(scoreStr: String, circleW: Float) {
                val cy = offsetY + vertPad
                // カプセル背景
                fillPaint.color = textColor
                val capsuleRect = RectF(mx, cy, mx + circleW, cy + scoreCircleH)
                canvas.drawRoundRect(capsuleRect, scoreCircleH / 2f, scoreCircleH / 2f, fillPaint)
                // スコア数字
                scorePaint.color = timerTextColor
                val scoreMetrics = scorePaint.fontMetrics
                val scoreTextW = scorePaint.measureText(scoreStr)
                val sx = mx + (circleW - scoreTextW) / 2f
                val sy = cy + (scoreCircleH - scoreMetrics.ascent - scoreMetrics.descent) / 2f
                canvas.drawText(scoreStr, sx, sy, scorePaint)
                mx += circleW + mainGap
            }
            drawScoreCircle(homeScoreStr, homeCircleW)
            drawScoreCircle(awayScoreStr, awayCircleW)
        }

        // アウェイチーム名 + アンダーライン
        val awayColor = style.awayTeamColorHex?.let { parseColor(it) } ?: themeScoreColor(theme)
        teamPaint.color = textColor
        val awayTextX = mx + (awayTeamW - awayNameW) / 2f
        canvas.drawText(match.awayTeamName, awayTextX, nameY, teamPaint)
        fillPaint.color = awayColor
        canvas.drawRect(mx, underlineY, mx + awayTeamW, underlineY + underlineH, fillPaint)
        mx += awayTeamW

        // 右側セクション
        if (!isLeft) {
            curX = offsetX + mainSectionW
            // タイマー背景
            if (timerSectionW > 0) {
                fillPaint.color = textColor
                canvas.drawRect(curX, offsetY, curX + timerSectionW, offsetY + containerH, fillPaint)
                val segment = match.activeTimerSegment(videoTime)
                val tColor = segment?.timerColorHex?.let { parseColor(it) } ?: timerTextColor
                timerPaint.color = tColor
                val ty = offsetY + (containerH - timerPaint.descent() + timerPaint.ascent()) / 2f - timerPaint.ascent()
                canvas.drawText(timerText!!, curX + base * 0.5f, ty, timerPaint)
                curX += timerSectionW
            }
            // ピリオドラベル背景
            if (periodSectionW > 0) {
                fillPaint.color = Color.WHITE
                canvas.drawRect(curX, offsetY, curX + periodSectionW, offsetY + containerH, fillPaint)
                periodPaint.color = Color.BLACK
                val py = offsetY + (containerH - periodPaint.descent() + periodPaint.ascent()) / 2f - periodPaint.ascent()
                canvas.drawText(periodLabel!!, curX + base * 0.375f, py, periodPaint)
            }
        }

        canvas.restore()
    }

    private fun drawMatchInfo(
        canvas: Canvas,
        info: String,
        style: ScoreboardStyle,
        base: Float,
        offsetX: Float,
        offsetY: Float
    ) {
        val bgColor = themeBackground(style.theme)
        val textColor = themeTextColor(style.theme)
        val fontSize = base * 0.45f
        val padH = base * 0.5f
        val padV = base * 0.2f
        val cornerRadius = base * 0.375f

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.DEFAULT
            textSize = fontSize
        }
        val textW = paint.measureText(info)
        val metrics = paint.fontMetrics
        val textH = -metrics.ascent + metrics.descent

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bgColor }
        val rect = RectF(offsetX, offsetY, offsetX + textW + padH * 2, offsetY + textH + padV * 2)
        canvas.drawRoundRect(rect, cornerRadius, cornerRadius, fillPaint)

        paint.color = textColor
        canvas.drawText(info, offsetX + padH, offsetY + padV - metrics.ascent, paint)
    }

    /**
     * iOS版 currentMatchSeconds() と同じロジック。
     * タイムアウト分を差し引いた試合経過秒数を計算。
     */
    private fun getTimerText(match: Match, videoTime: Double, style: ScoreboardStyle, isPK: Boolean): String? {
        if (!style.showMatchTimer) return null
        if (isPK) return null
        if (match.timerSegments.isEmpty()) return null

        var lastMatchSecond = 0

        for (seg in match.timerSegments) {
            val effStart = seg.effectiveStartTime ?: continue
            val kickoff = seg.timerStartTime ?: effStart
            val segStart = effStart
            val stop = seg.timerStopTime ?: videoTime
            val offset = (seg.timerStartOffset ?: 0.0).toInt()

            if (videoTime >= segStart && videoTime <= stop) {
                if (videoTime < kickoff) {
                    return formatTimer(offset, seg.showPlusPrefix)
                }
                val elapsed = videoTime - kickoff
                val paused = match.timeouts.sumOf { it.pausedSeconds(kickoff, videoTime) }
                val seconds = maxOf(0, (elapsed - paused).toInt()) + offset
                return formatTimer(seconds, seg.showPlusPrefix)
            } else if (videoTime > stop) {
                val elapsed = stop - kickoff
                val paused = match.timeouts.sumOf { it.pausedSeconds(kickoff, stop) }
                lastMatchSecond = maxOf(0, (elapsed - paused).toInt()) + offset
            } else {
                break
            }
        }

        return if (lastMatchSecond > 0) formatTimer(lastMatchSecond, false) else null
    }

    private fun formatTimer(totalSeconds: Int, showPlus: Boolean): String {
        val mm = totalSeconds / 60
        val ss = totalSeconds % 60
        return if (showPlus) String.format("+%02d:%02d", mm, ss)
        else String.format("%02d:%02d", mm, ss)
    }

    private fun themeBackground(theme: ScoreboardStyle.Theme): Int {
        return when (theme) {
            ScoreboardStyle.Theme.dark -> Color.argb(178, 0, 0, 0)
            ScoreboardStyle.Theme.light -> Color.argb(204, 255, 255, 255)
            ScoreboardStyle.Theme.broadcast -> Color.argb(217, 26, 26, 77)
            ScoreboardStyle.Theme.minimal -> Color.argb(102, 0, 0, 0)
        }
    }

    private fun themeTextColor(theme: ScoreboardStyle.Theme): Int {
        return when (theme) {
            ScoreboardStyle.Theme.dark,
            ScoreboardStyle.Theme.broadcast,
            ScoreboardStyle.Theme.minimal -> Color.WHITE
            ScoreboardStyle.Theme.light -> Color.BLACK
        }
    }

    private fun themeScoreColor(theme: ScoreboardStyle.Theme): Int {
        return when (theme) {
            ScoreboardStyle.Theme.dark,
            ScoreboardStyle.Theme.broadcast -> Color.rgb(255, 215, 0)
            ScoreboardStyle.Theme.light -> Color.BLUE
            ScoreboardStyle.Theme.minimal -> Color.WHITE
        }
    }

    private fun themeTimerTextColor(theme: ScoreboardStyle.Theme): Int {
        return when (theme) {
            ScoreboardStyle.Theme.dark,
            ScoreboardStyle.Theme.broadcast,
            ScoreboardStyle.Theme.minimal -> Color.BLACK
            ScoreboardStyle.Theme.light -> Color.WHITE
        }
    }

    private fun parseColor(hex: String): Int? {
        return try {
            val sanitized = hex.trimStart('#')
            if (sanitized.length != 6) return null
            Color.parseColor("#$sanitized")
        } catch (_: Exception) {
            null
        }
    }
}
