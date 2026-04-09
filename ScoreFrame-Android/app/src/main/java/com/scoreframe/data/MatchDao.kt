package com.scoreframe.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import com.scoreframe.model.MatchEntity
import com.scoreframe.model.ScoreEvent
import kotlinx.coroutines.flow.Flow

@Dao
interface MatchDao {

    @Query("SELECT * FROM matches ORDER BY createdAt DESC")
    fun getAllMatches(): Flow<List<MatchEntity>>

    @Query("SELECT * FROM matches WHERE id = :matchId")
    suspend fun getMatch(matchId: String): MatchEntity?

    @Query("SELECT * FROM matches WHERE id = :matchId")
    fun observeMatch(matchId: String): Flow<MatchEntity?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMatch(match: MatchEntity)

    @Update
    suspend fun updateMatch(match: MatchEntity)

    @Delete
    suspend fun deleteMatch(match: MatchEntity)

    // Field-specific updates to avoid read-modify-write race conditions
    @Query("UPDATE matches SET timerSegmentsJson = :json WHERE id = :matchId")
    suspend fun updateTimerSegments(matchId: String, json: String?)

    @Query("UPDATE matches SET scoreboardStyleJson = :json WHERE id = :matchId")
    suspend fun updateScoreboardStyle(matchId: String, json: String?)

    @Query("UPDATE matches SET videoUrisJson = :json WHERE id = :matchId")
    suspend fun updateVideoUris(matchId: String, json: String?)

    @Query("UPDATE matches SET pkKicksJson = :json WHERE id = :matchId")
    suspend fun updatePkKicks(matchId: String, json: String?)

    @Query("UPDATE matches SET penaltyTimersJson = :json WHERE id = :matchId")
    suspend fun updatePenaltyTimers(matchId: String, json: String?)

    @Query("UPDATE matches SET timeoutsJson = :json WHERE id = :matchId")
    suspend fun updateTimeouts(matchId: String, json: String?)

    @Query("UPDATE matches SET skipOverlay = :skip WHERE id = :matchId")
    suspend fun updateSkipOverlay(matchId: String, skip: Boolean)

    @Query("UPDATE matches SET matchInfo = :info WHERE id = :matchId")
    suspend fun updateMatchInfo(matchId: String, info: String?)

    // ScoreEvent
    @Query("SELECT * FROM score_events WHERE matchId = :matchId ORDER BY timestamp ASC")
    fun getScoreEvents(matchId: String): Flow<List<ScoreEvent>>

    @Query("SELECT * FROM score_events WHERE matchId = :matchId ORDER BY timestamp ASC")
    suspend fun getScoreEventsList(matchId: String): List<ScoreEvent>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertScoreEvent(event: ScoreEvent)

    @Delete
    suspend fun deleteScoreEvent(event: ScoreEvent)

    @Query("DELETE FROM score_events WHERE matchId = :matchId")
    suspend fun deleteAllScoreEvents(matchId: String)

    @Transaction
    suspend fun deleteMatchWithEvents(match: MatchEntity) {
        deleteAllScoreEvents(match.id)
        deleteMatch(match)
    }
}
