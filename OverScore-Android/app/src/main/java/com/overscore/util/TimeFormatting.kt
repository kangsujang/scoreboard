package com.overscore.util

import kotlin.math.max

object TimeFormatting {
    fun format(seconds: Double): String {
        val totalSeconds = max(0.0, seconds).toInt()
        val minutes = totalSeconds / 60
        val secs = totalSeconds % 60
        return "%02d:%02d".format(minutes, secs)
    }

    fun formatMillis(millis: Long): String {
        if (millis <= 0) return "00:00"
        return format(millis / 1000.0)
    }
}
