package com.scoreframe.model

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "matches")
data class MatchEntity(
    @PrimaryKey val id: String = java.util.UUID.randomUUID().toString(),
    val homeTeamName: String,
    val awayTeamName: String,
    val createdAt: Long = System.currentTimeMillis(),
    val scoreboardStyleJson: String? = null,
    val timerSegmentsJson: String? = null,
    val matchInfo: String? = null,
    val pkKicksJson: String? = null,
    val penaltyTimersJson: String? = null,
    val timeoutsJson: String? = null,
    val videoUrisJson: String? = null,
    val skipOverlay: Boolean = false
)
