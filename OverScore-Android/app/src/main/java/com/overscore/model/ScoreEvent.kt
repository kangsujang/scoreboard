package com.overscore.model

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "score_events",
    foreignKeys = [
        ForeignKey(
            entity = MatchEntity::class,
            parentColumns = ["id"],
            childColumns = ["matchId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("matchId")]
)
data class ScoreEvent(
    @PrimaryKey val id: String = java.util.UUID.randomUUID().toString(),
    val matchId: String,
    val teamRawValue: String,
    val timestamp: Double,
    val createdAt: Long = System.currentTimeMillis()
) {
    val team: Team
        get() = try { Team.valueOf(teamRawValue) } catch (_: Exception) { Team.home }
}
