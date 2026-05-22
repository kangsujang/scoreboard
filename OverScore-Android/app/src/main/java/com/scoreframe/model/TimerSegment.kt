package com.scoreframe.model

import kotlinx.serialization.Serializable

@Serializable
data class TimerSegment(
    val id: String = java.util.UUID.randomUUID().toString(),
    var periodLabel: String? = null,
    var segmentStartTime: Double? = null,
    var timerStartTime: Double? = null,
    var timerStopTime: Double? = null,
    var timerStartOffset: Double? = null,
    var showPlusPrefix: Boolean = false,
    var timerColorHex: String? = null
) {
    val effectiveStartTime: Double?
        get() = segmentStartTime ?: timerStartTime
}
