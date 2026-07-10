package com.overscore.model

import kotlinx.serialization.Serializable

@Serializable
enum class Team {
    home,
    away;
}

@Serializable
data class PKKick(
    val id: String = java.util.UUID.randomUUID().toString(),
    val team: Team,
    val order: Int,
    val isGoal: Boolean,
    val timestamp: Double
)
