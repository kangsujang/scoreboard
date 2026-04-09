package com.scoreframe.util

import androidx.compose.ui.graphics.Color
import com.scoreframe.model.ScoreboardStyle

val ScoreGold = Color(1.0f, 0.843f, 0.0f)

fun parseHexColor(hex: String): Color? {
    val sanitized = hex.trimStart('#')
    if (sanitized.length != 6) return null
    val value = sanitized.toLongOrNull(16) ?: return null
    val r = ((value shr 16) and 0xFF) / 255f
    val g = ((value shr 8) and 0xFF) / 255f
    val b = (value and 0xFF) / 255f
    return Color(r, g, b)
}

fun Color.toHexString(): String {
    val r = (red * 255).toInt().coerceIn(0, 255)
    val g = (green * 255).toInt().coerceIn(0, 255)
    val b = (blue * 255).toInt().coerceIn(0, 255)
    return "#%02X%02X%02X".format(r, g, b)
}

fun scoreboardBackground(theme: ScoreboardStyle.Theme): Color {
    return when (theme) {
        ScoreboardStyle.Theme.dark -> Color.Black.copy(alpha = 0.7f)
        ScoreboardStyle.Theme.light -> Color.White.copy(alpha = 0.8f)
        ScoreboardStyle.Theme.broadcast -> Color(0.1f, 0.1f, 0.3f, 0.85f)
        ScoreboardStyle.Theme.minimal -> Color.Black.copy(alpha = 0.4f)
    }
}

fun scoreboardTextColor(theme: ScoreboardStyle.Theme): Color {
    return when (theme) {
        ScoreboardStyle.Theme.dark,
        ScoreboardStyle.Theme.broadcast,
        ScoreboardStyle.Theme.minimal -> Color.White
        ScoreboardStyle.Theme.light -> Color.Black
    }
}

fun scoreboardScoreColor(theme: ScoreboardStyle.Theme): Color {
    return when (theme) {
        ScoreboardStyle.Theme.dark,
        ScoreboardStyle.Theme.broadcast -> ScoreGold
        ScoreboardStyle.Theme.light -> Color.Blue
        ScoreboardStyle.Theme.minimal -> Color.White
    }
}

fun scoreboardTimerTextColor(theme: ScoreboardStyle.Theme): Color {
    return when (theme) {
        ScoreboardStyle.Theme.dark,
        ScoreboardStyle.Theme.broadcast,
        ScoreboardStyle.Theme.minimal -> Color.Black
        ScoreboardStyle.Theme.light -> Color.White
    }
}
