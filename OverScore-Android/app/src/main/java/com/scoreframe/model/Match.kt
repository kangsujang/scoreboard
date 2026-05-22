package com.scoreframe.model

import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json

private val json = Json { ignoreUnknownKeys = true }

data class Match(
    val id: String = java.util.UUID.randomUUID().toString(),
    var homeTeamName: String,
    var awayTeamName: String,
    val createdAt: Long = System.currentTimeMillis(),
    var scoreboardStyle: ScoreboardStyle = ScoreboardStyle(),
    var timerSegments: List<TimerSegment> = emptyList(),
    var matchInfo: String? = null,
    var pkKicks: List<PKKick> = emptyList(),
    var penaltyTimers: List<PenaltyTimer> = emptyList(),
    var timeouts: List<TimeoutEvent> = emptyList(),
    var videoUris: List<String> = emptyList(),
    var skipOverlay: Boolean = false,
    var scoreEvents: List<ScoreEvent> = emptyList()
) {
    val homeScore: Int
        get() = scoreEvents.count { it.team == Team.home }

    val awayScore: Int
        get() = scoreEvents.count { it.team == Team.away }

    val sortedEvents: List<ScoreEvent>
        get() = scoreEvents.sortedBy { it.timestamp }

    val homePKKicks: List<PKKick>
        get() = pkKicks.filter { it.team == Team.home }.sortedBy { it.order }

    val awayPKKicks: List<PKKick>
        get() = pkKicks.filter { it.team == Team.away }.sortedBy { it.order }

    val homePKScore: Int
        get() = pkKicks.count { it.team == Team.home && it.isGoal }

    val awayPKScore: Int
        get() = pkKicks.count { it.team == Team.away && it.isGoal }

    fun scoreAt(time: Double): Pair<Int, Int> {
        var home = 0
        var away = 0
        for (event in sortedEvents) {
            if (event.timestamp > time) break
            when (event.team) {
                Team.home -> home++
                Team.away -> away++
            }
        }
        return home to away
    }

    fun pkKicksAt(time: Double): List<PKKick> {
        return pkKicks.filter { it.timestamp <= time }
    }

    fun segmentIndex(videoTime: Double): Int? {
        for ((i, seg) in timerSegments.withIndex()) {
            val start = seg.effectiveStartTime ?: continue
            val end = seg.timerStopTime ?: Double.MAX_VALUE
            if (videoTime in start..end) return i
        }
        return null
    }

    fun currentPeriodLabel(videoTime: Double): String? {
        val idx = segmentIndex(videoTime)
        if (idx != null) return timerSegments[idx].periodLabel
        var lastLabel: String? = null
        for (seg in timerSegments) {
            val start = seg.effectiveStartTime ?: continue
            if (start <= videoTime) lastLabel = seg.periodLabel
        }
        return lastLabel
    }

    fun activeTimerSegment(videoTime: Double): TimerSegment? {
        val idx = segmentIndex(videoTime)
        if (idx != null) return timerSegments[idx]
        var lastSeg: TimerSegment? = null
        for (seg in timerSegments) {
            val start = seg.effectiveStartTime ?: continue
            if (start <= videoTime) lastSeg = seg
        }
        return lastSeg
    }

    fun activePenaltyTimers(videoTime: Double, forTeam: Team): List<PenaltyTimer> {
        return penaltyTimers
            .filter { it.team == forTeam && it.remainingSeconds(videoTime) != null }
            .sortedBy { it.timestamp }
    }

    fun timeoutCount(forTeam: Team, videoTime: Double): Int {
        return timeouts.count { it.team == forTeam && it.timestamp <= videoTime }
    }

    fun isTimeoutActive(videoTime: Double): Boolean {
        return timeouts.any { it.isActive(videoTime) }
    }

    fun toEntity(): MatchEntity = MatchEntity(
        id = id,
        homeTeamName = homeTeamName,
        awayTeamName = awayTeamName,
        createdAt = createdAt,
        scoreboardStyleJson = json.encodeToString(ScoreboardStyle.serializer(), scoreboardStyle),
        timerSegmentsJson = json.encodeToString(ListSerializer(TimerSegment.serializer()), timerSegments),
        matchInfo = matchInfo,
        pkKicksJson = json.encodeToString(ListSerializer(PKKick.serializer()), pkKicks),
        penaltyTimersJson = json.encodeToString(ListSerializer(PenaltyTimer.serializer()), penaltyTimers),
        timeoutsJson = json.encodeToString(ListSerializer(TimeoutEvent.serializer()), timeouts),
        videoUrisJson = json.encodeToString(ListSerializer(String.serializer()), videoUris),
        skipOverlay = skipOverlay
    )

    companion object {
        fun fromEntity(entity: MatchEntity, events: List<ScoreEvent> = emptyList()): Match {
            return Match(
                id = entity.id,
                homeTeamName = entity.homeTeamName,
                awayTeamName = entity.awayTeamName,
                createdAt = entity.createdAt,
                scoreboardStyle = entity.scoreboardStyleJson?.let {
                    try { json.decodeFromString(ScoreboardStyle.serializer(), it) } catch (_: Exception) { null }
                } ?: ScoreboardStyle(),
                timerSegments = entity.timerSegmentsJson?.let {
                    try { json.decodeFromString(ListSerializer(TimerSegment.serializer()), it) } catch (_: Exception) { null }
                } ?: emptyList(),
                matchInfo = entity.matchInfo,
                pkKicks = entity.pkKicksJson?.let {
                    try { json.decodeFromString(ListSerializer(PKKick.serializer()), it) } catch (_: Exception) { null }
                } ?: emptyList(),
                penaltyTimers = entity.penaltyTimersJson?.let {
                    try { json.decodeFromString(ListSerializer(PenaltyTimer.serializer()), it) } catch (_: Exception) { null }
                } ?: emptyList(),
                timeouts = entity.timeoutsJson?.let {
                    try { json.decodeFromString(ListSerializer(TimeoutEvent.serializer()), it) } catch (_: Exception) { null }
                } ?: emptyList(),
                videoUris = entity.videoUrisJson?.let {
                    try { json.decodeFromString(ListSerializer(String.serializer()), it) } catch (_: Exception) { null }
                } ?: emptyList(),
                skipOverlay = entity.skipOverlay,
                scoreEvents = events
            )
        }
    }
}
