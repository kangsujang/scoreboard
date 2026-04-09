package com.scoreframe.viewmodel

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.scoreframe.data.MatchRepository
import com.scoreframe.model.Match
import com.scoreframe.model.PenaltyTimer
import com.scoreframe.model.ScoreEvent
import com.scoreframe.model.ScoreboardStyle
import com.scoreframe.model.Team
import com.scoreframe.model.TimeoutEvent
import com.scoreframe.model.TimerSegment
import com.scoreframe.model.PKKick
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ScoreEditorViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repository: MatchRepository
) : ViewModel() {

    private val matchId: String = savedStateHandle["matchId"] ?: ""

    private val _match = MutableStateFlow<Match?>(null)
    val match: StateFlow<Match?> = _match.asStateFlow()

    private val _currentTime = MutableStateFlow(0.0)
    val currentTime: StateFlow<Double> = _currentTime.asStateFlow()

    init {
        viewModelScope.launch {
            repository.observeMatch(matchId).collect {
                _match.value = it
                // 初回ロード時にセグメントがなければ1つ作成
                if (it != null && it.timerSegments.isEmpty()) {
                    ensureAtLeastOneSegment(it)
                }
            }
        }
    }

    private fun ensureAtLeastOneSegment(m: Match) {
        viewModelScope.launch {
            repository.updateTimerSegments(m.id, listOf(TimerSegment()))
        }
    }

    fun setCurrentTime(time: Double) {
        _currentTime.value = time
    }

    fun addGoal(team: Team) {
        val m = _match.value ?: return
        viewModelScope.launch {
            val event = ScoreEvent(
                matchId = m.id,
                teamRawValue = team.name,
                timestamp = _currentTime.value
            )
            repository.addScoreEvent(m.id, event)
        }
    }

    fun undoLastGoal(team: Team) {
        val m = _match.value ?: return
        val lastEvent = m.scoreEvents
            .filter { it.team == team }
            .maxByOrNull { it.timestamp } ?: return
        viewModelScope.launch {
            repository.deleteScoreEvent(lastEvent)
        }
    }

    fun deleteScoreEvent(event: ScoreEvent) {
        viewModelScope.launch {
            repository.deleteScoreEvent(event)
        }
    }

    fun updateTimerSegments(segments: List<TimerSegment>) {
        val m = _match.value ?: return
        viewModelScope.launch {
            repository.updateTimerSegments(m.id, segments)
        }
    }

    fun addTimerSegment(label: String?) {
        val m = _match.value ?: return
        val segment = TimerSegment(periodLabel = label)
        viewModelScope.launch {
            repository.updateTimerSegments(m.id, m.timerSegments + segment)
        }
    }

    fun addTimerSegmentWithRestart() {
        val m = _match.value ?: return
        val segments = m.timerSegments.toMutableList()
        val currentTime = _currentTime.value

        var lastTimerValue = 0.0
        if (segments.isNotEmpty()) {
            val lastIdx = segments.lastIndex
            val prev = segments[lastIdx]
            val kickoff = prev.timerStartTime ?: prev.effectiveStartTime ?: 0.0
            val stop = prev.timerStopTime ?: currentTime
            val elapsed = maxOf(0.0, stop - kickoff)
            val offset = prev.timerStartOffset ?: 0.0
            lastTimerValue = elapsed + offset
            segments[lastIdx] = segments[lastIdx].copy(timerStopTime = currentTime)
        }

        val newSegment = TimerSegment(
            segmentStartTime = currentTime,
            timerStartTime = currentTime,
            timerStartOffset = lastTimerValue
        )
        segments.add(newSegment)

        viewModelScope.launch {
            repository.updateTimerSegments(m.id, segments)
        }
    }

    fun removeTimerSegment(index: Int) {
        val m = _match.value ?: return
        val segments = m.timerSegments.toMutableList()
        if (segments.size <= 1 || index !in segments.indices) return
        segments.removeAt(index)
        viewModelScope.launch {
            repository.updateTimerSegments(m.id, segments)
        }
    }

    fun setSegmentStart(segmentIndex: Int) {
        val m = _match.value ?: return
        val segments = m.timerSegments.toMutableList()
        if (segmentIndex !in segments.indices) return
        val time = _currentTime.value
        segments[segmentIndex] = segments[segmentIndex].copy(segmentStartTime = time)
        val kickoff = segments[segmentIndex].timerStartTime
        if (kickoff != null && kickoff < time) {
            segments[segmentIndex] = segments[segmentIndex].copy(timerStartTime = null)
        }
        viewModelScope.launch {
            repository.updateTimerSegments(m.id, segments)
        }
    }

    fun startTimer(segmentIndex: Int) {
        val m = _match.value ?: return
        val segments = m.timerSegments.toMutableList()
        if (segmentIndex !in segments.indices) return
        val time = _currentTime.value
        segments[segmentIndex] = segments[segmentIndex].copy(timerStartTime = time)
        val stop = segments[segmentIndex].timerStopTime
        if (stop != null && stop <= time) {
            segments[segmentIndex] = segments[segmentIndex].copy(timerStopTime = null)
        }
        viewModelScope.launch {
            repository.updateTimerSegments(m.id, segments)
        }
    }

    fun stopTimer(segmentIndex: Int) {
        val m = _match.value ?: return
        val segments = m.timerSegments.toMutableList()
        if (segmentIndex !in segments.indices) return
        val time = _currentTime.value
        val start = segments[segmentIndex].timerStartTime ?: return
        if (time <= start) return
        segments[segmentIndex] = segments[segmentIndex].copy(timerStopTime = time)
        viewModelScope.launch {
            repository.updateTimerSegments(m.id, segments)
        }
    }

    fun clearSegmentTimer(segmentIndex: Int) {
        val m = _match.value ?: return
        val segments = m.timerSegments.toMutableList()
        if (segmentIndex !in segments.indices) return
        segments[segmentIndex] = segments[segmentIndex].copy(
            segmentStartTime = null,
            timerStartTime = null,
            timerStopTime = null,
            timerStartOffset = null
        )
        viewModelScope.launch {
            repository.updateTimerSegments(m.id, segments)
        }
    }

    fun setSegmentOffset(segmentIndex: Int, seconds: Double) {
        val m = _match.value ?: return
        val segments = m.timerSegments.toMutableList()
        if (segmentIndex !in segments.indices) return
        val clamped = maxOf(0.0, seconds)
        segments[segmentIndex] = segments[segmentIndex].copy(
            timerStartOffset = if (clamped > 0) clamped else null
        )
        viewModelScope.launch {
            repository.updateTimerSegments(m.id, segments)
        }
    }

    fun setSegmentPeriodLabel(segmentIndex: Int, label: String?) {
        val m = _match.value ?: return
        val segments = m.timerSegments.toMutableList()
        if (segmentIndex !in segments.indices) return
        segments[segmentIndex] = segments[segmentIndex].copy(periodLabel = label)
        viewModelScope.launch {
            repository.updateTimerSegments(m.id, segments)
        }
    }

    fun setSegmentShowPlusPrefix(segmentIndex: Int, value: Boolean) {
        val m = _match.value ?: return
        val segments = m.timerSegments.toMutableList()
        if (segmentIndex !in segments.indices) return
        segments[segmentIndex] = segments[segmentIndex].copy(showPlusPrefix = value)
        viewModelScope.launch {
            repository.updateTimerSegments(m.id, segments)
        }
    }

    fun setSegmentTimerColor(segmentIndex: Int, hex: String?) {
        val m = _match.value ?: return
        val segments = m.timerSegments.toMutableList()
        if (segmentIndex !in segments.indices) return
        segments[segmentIndex] = segments[segmentIndex].copy(timerColorHex = hex)
        viewModelScope.launch {
            repository.updateTimerSegments(m.id, segments)
        }
    }

    fun addPenaltyTimer(team: Team, durationSeconds: Double) {
        val m = _match.value ?: return
        val timer = PenaltyTimer(
            team = team,
            timestamp = _currentTime.value,
            durationSeconds = durationSeconds
        )
        viewModelScope.launch {
            repository.updatePenaltyTimers(m.id, m.penaltyTimers + timer)
        }
    }

    fun removePenaltyTimer(timerId: String) {
        val m = _match.value ?: return
        viewModelScope.launch {
            repository.updatePenaltyTimers(m.id, m.penaltyTimers.filter { it.id != timerId })
        }
    }

    fun startTimeout(team: Team) {
        val m = _match.value ?: return
        val timeout = TimeoutEvent(
            team = team,
            timestamp = _currentTime.value
        )
        viewModelScope.launch {
            repository.updateTimeouts(m.id, m.timeouts + timeout)
        }
    }

    fun endTimeout(timeoutId: String) {
        val m = _match.value ?: return
        val updated = m.timeouts.map {
            if (it.id == timeoutId) it.copy(endTimestamp = _currentTime.value) else it
        }
        viewModelScope.launch {
            repository.updateTimeouts(m.id, updated)
        }
    }

    fun removeTimeout(timeoutId: String) {
        val m = _match.value ?: return
        viewModelScope.launch {
            repository.updateTimeouts(m.id, m.timeouts.filter { it.id != timeoutId })
        }
    }

    fun addPKKick(team: Team, isGoal: Boolean) {
        val m = _match.value ?: return
        val existingKicks = m.pkKicks.filter { it.team == team }
        val kick = PKKick(
            team = team,
            order = existingKicks.size,
            isGoal = isGoal,
            timestamp = _currentTime.value
        )
        viewModelScope.launch {
            repository.updatePkKicks(m.id, m.pkKicks + kick)
        }
    }

    fun removePKKick(kickId: String) {
        val m = _match.value ?: return
        viewModelScope.launch {
            repository.updatePkKicks(m.id, m.pkKicks.filter { it.id != kickId })
        }
    }

    fun updateScoreboardStyle(style: ScoreboardStyle) {
        val m = _match.value ?: return
        viewModelScope.launch {
            repository.updateScoreboardStyle(m.id, style)
        }
    }
}
