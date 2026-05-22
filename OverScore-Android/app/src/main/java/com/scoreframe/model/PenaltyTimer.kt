package com.scoreframe.model

import kotlinx.serialization.Serializable
import kotlin.math.abs

@Serializable
data class PenaltyTimer(
    val id: String = java.util.UUID.randomUUID().toString(),
    val team: Team,
    val timestamp: Double,
    val durationSeconds: Double
) {
    val expiresAt: Double
        get() = timestamp + durationSeconds

    fun remainingSeconds(videoTime: Double): Double? {
        if (videoTime < timestamp) return null
        val remaining = durationSeconds - (videoTime - timestamp)
        return if (remaining > 0) remaining else null
    }

    fun remainingSeconds(videoTime: Double, timeouts: List<TimeoutEvent>): Double? {
        if (videoTime < timestamp) return null
        var paused = 0.0
        for (timeout in timeouts) {
            paused += timeout.pausedSeconds(kickoff = timestamp, videoTime = videoTime)
        }
        val effectiveElapsed = (videoTime - timestamp) - paused
        val remaining = durationSeconds - effectiveElapsed
        return if (remaining > 0) remaining else null
    }

    fun effectiveExpiresAt(timeouts: List<TimeoutEvent>): Double {
        var end = expiresAt
        repeat(10) {
            val totalPaused = timeouts.sumOf { it.pausedSeconds(kickoff = timestamp, videoTime = end) }
            val newEnd = timestamp + durationSeconds + totalPaused
            if (abs(newEnd - end) < 0.001) return newEnd
            end = newEnd
        }
        return end
    }
}
