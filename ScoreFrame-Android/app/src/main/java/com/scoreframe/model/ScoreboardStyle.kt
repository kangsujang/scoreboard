package com.scoreframe.model

import kotlinx.serialization.Serializable

@Serializable
data class ScoreboardStyle(
    var theme: Theme = Theme.dark,
    var showScore: Boolean = true,
    var showMatchTimer: Boolean = true,
    var timerPosition: TimerPosition = TimerPosition.left,
    var showTimerOptions: Boolean = false,
    var showPenaltyTimer: Boolean = false,
    var showTimeouts: Boolean = false,
    var periodLabel: String? = null,
    var homeTeamColorHex: String? = null,
    var awayTeamColorHex: String? = null,
    var positionX: Float = 0.02f,
    var positionY: Float = 0.02f,
    var scale: Float = 1.0f,
    var matchInfoPositionX: Float = 0.02f,
    var matchInfoPositionY: Float = 0.12f,
    var matchInfoScale: Float = 1.0f
) {
    @Serializable
    enum class Theme {
        dark,
        light,
        broadcast,
        minimal;

        val displayName: String
            get() = when (this) {
                dark -> "Dark"
                light -> "Light"
                broadcast -> "Broadcast"
                minimal -> "Minimal"
            }
    }

    @Serializable
    enum class TimerPosition {
        left,
        right;
    }
}
