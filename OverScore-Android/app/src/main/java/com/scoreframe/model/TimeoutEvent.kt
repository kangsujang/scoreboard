package com.scoreframe.model

import kotlinx.serialization.Serializable
import kotlin.math.max

@Serializable
data class TimeoutEvent(
    val id: String = java.util.UUID.randomUUID().toString(),
    val team: Team,
    val timestamp: Double,
    var endTimestamp: Double? = null
) {
    fun isActive(videoTime: Double): Boolean {
        if (videoTime < timestamp) return false
        val end = endTimestamp ?: return true
        return videoTime < end
    }

    fun elapsedSeconds(videoTime: Double): Double? {
        if (videoTime < timestamp) return null
        val end = endTimestamp
        if (end != null && videoTime >= end) return null
        return videoTime - timestamp
    }

    fun pausedSeconds(kickoff: Double, videoTime: Double): Double {
        val overlapStart = max(timestamp, kickoff)
        val overlapEnd = if (endTimestamp != null) {
            minOf(endTimestamp!!, videoTime)
        } else {
            videoTime
        }
        return max(0.0, overlapEnd - overlapStart)
    }
}
