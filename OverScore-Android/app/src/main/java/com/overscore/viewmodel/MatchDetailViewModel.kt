package com.overscore.viewmodel

import android.content.Context
import android.net.Uri
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.overscore.data.MatchRepository
import com.overscore.model.Match
import com.overscore.model.ScoreboardStyle
import com.overscore.service.VideoImportService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class MatchDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repository: MatchRepository,
    private val videoImportService: VideoImportService
) : ViewModel() {

    private val matchId: String = savedStateHandle["matchId"] ?: ""

    private val _match = MutableStateFlow<Match?>(null)
    val match: StateFlow<Match?> = _match.asStateFlow()

    init {
        viewModelScope.launch {
            repository.observeMatch(matchId).collect { _match.value = it }
        }
    }

    fun updateStyle(style: ScoreboardStyle) {
        val m = _match.value ?: return
        viewModelScope.launch {
            repository.updateScoreboardStyle(m.id, style)
        }
    }

    fun updateSkipOverlay(skip: Boolean) {
        val m = _match.value ?: return
        viewModelScope.launch {
            repository.updateSkipOverlay(m.id, skip)
        }
    }

    fun addVideos(context: Context, uris: List<Uri>) {
        val m = _match.value ?: return
        viewModelScope.launch {
            val imported = uris.mapNotNull { uri ->
                videoImportService.importVideo(context, uri)
            }
            repository.updateVideoUris(m.id, m.videoUris + imported)
        }
    }

    fun removeVideo(index: Int) {
        val m = _match.value ?: return
        val uris = m.videoUris.toMutableList()
        if (index in uris.indices) {
            uris.removeAt(index)
            viewModelScope.launch {
                repository.updateVideoUris(m.id, uris)
            }
        }
    }

    fun moveVideo(fromIndex: Int, toIndex: Int) {
        val m = _match.value ?: return
        val uris = m.videoUris.toMutableList()
        if (fromIndex in uris.indices && toIndex in uris.indices) {
            val item = uris.removeAt(fromIndex)
            uris.add(toIndex, item)
            viewModelScope.launch {
                repository.updateVideoUris(m.id, uris)
            }
        }
    }
}
