package com.overscore.data

import com.overscore.model.Match
import com.overscore.model.MatchEntity
import com.overscore.model.PKKick
import com.overscore.model.PenaltyTimer
import com.overscore.model.ScoreEvent
import com.overscore.model.ScoreboardStyle
import com.overscore.model.TimeoutEvent
import com.overscore.model.TimerSegment
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

private val repoJson = Json { ignoreUnknownKeys = true }

@Singleton
class MatchRepository @Inject constructor(
    private val matchDao: MatchDao
) {
    fun getAllMatches(): Flow<List<Match>> {
        return matchDao.getAllMatches().map { entities ->
            entities.map { entity ->
                val events = matchDao.getScoreEventsList(entity.id)
                Match.fromEntity(entity, events)
            }
        }
    }

    fun observeMatch(matchId: String): Flow<Match?> {
        return combine(
            matchDao.observeMatch(matchId),
            matchDao.getScoreEvents(matchId)
        ) { entity, events ->
            entity?.let { Match.fromEntity(it, events) }
        }
    }

    suspend fun getMatch(matchId: String): Match? {
        val entity = matchDao.getMatch(matchId) ?: return null
        val events = matchDao.getScoreEventsList(matchId)
        return Match.fromEntity(entity, events)
    }

    suspend fun insertMatch(match: Match) {
        matchDao.insertMatch(match.toEntity())
    }

    suspend fun updateMatch(match: Match) {
        matchDao.updateMatch(match.toEntity())
    }

    suspend fun deleteMatch(match: Match) {
        matchDao.deleteMatchWithEvents(match.toEntity())
    }

    // Field-specific updates — avoids read-modify-write race conditions
    suspend fun updateTimerSegments(matchId: String, segments: List<TimerSegment>) {
        val json = repoJson.encodeToString(ListSerializer(TimerSegment.serializer()), segments)
        matchDao.updateTimerSegments(matchId, json)
    }

    suspend fun updateScoreboardStyle(matchId: String, style: ScoreboardStyle) {
        val json = repoJson.encodeToString(ScoreboardStyle.serializer(), style)
        matchDao.updateScoreboardStyle(matchId, json)
    }

    suspend fun updateVideoUris(matchId: String, uris: List<String>) {
        val json = repoJson.encodeToString(ListSerializer(String.serializer()), uris)
        matchDao.updateVideoUris(matchId, json)
    }

    suspend fun updatePkKicks(matchId: String, kicks: List<PKKick>) {
        val json = repoJson.encodeToString(ListSerializer(PKKick.serializer()), kicks)
        matchDao.updatePkKicks(matchId, json)
    }

    suspend fun updatePenaltyTimers(matchId: String, timers: List<PenaltyTimer>) {
        val json = repoJson.encodeToString(ListSerializer(PenaltyTimer.serializer()), timers)
        matchDao.updatePenaltyTimers(matchId, json)
    }

    suspend fun updateTimeouts(matchId: String, timeouts: List<TimeoutEvent>) {
        val json = repoJson.encodeToString(ListSerializer(TimeoutEvent.serializer()), timeouts)
        matchDao.updateTimeouts(matchId, json)
    }

    suspend fun updateSkipOverlay(matchId: String, skip: Boolean) {
        matchDao.updateSkipOverlay(matchId, skip)
    }

    suspend fun addScoreEvent(matchId: String, event: ScoreEvent) {
        matchDao.insertScoreEvent(event)
    }

    suspend fun deleteScoreEvent(event: ScoreEvent) {
        matchDao.deleteScoreEvent(event)
    }
}
