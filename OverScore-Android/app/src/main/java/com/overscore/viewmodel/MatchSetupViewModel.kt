package com.overscore.viewmodel

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.overscore.data.MatchRepository
import com.overscore.model.Match
import com.overscore.service.VideoImportService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class MatchSetupViewModel @Inject constructor(
    private val repository: MatchRepository,
    private val videoImportService: VideoImportService
) : ViewModel() {

    private val _homeTeamName = MutableStateFlow("")
    val homeTeamName: StateFlow<String> = _homeTeamName.asStateFlow()

    private val _awayTeamName = MutableStateFlow("")
    val awayTeamName: StateFlow<String> = _awayTeamName.asStateFlow()

    private val _matchInfo = MutableStateFlow("")
    val matchInfo: StateFlow<String> = _matchInfo.asStateFlow()

    private val _videoUris = MutableStateFlow<List<String>>(emptyList())
    val videoUris: StateFlow<List<String>> = _videoUris.asStateFlow()

    fun setHomeTeamName(name: String) { _homeTeamName.value = name }
    fun setAwayTeamName(name: String) { _awayTeamName.value = name }
    fun setMatchInfo(info: String) { _matchInfo.value = info }

    fun addVideos(context: Context, uris: List<Uri>) {
        viewModelScope.launch {
            val imported = uris.mapNotNull { uri ->
                videoImportService.importVideo(context, uri)
            }
            _videoUris.value = _videoUris.value + imported
        }
    }

    fun removeVideo(index: Int) {
        val current = _videoUris.value.toMutableList()
        if (index in current.indices) {
            current.removeAt(index)
            _videoUris.value = current
        }
    }

    fun moveVideo(fromIndex: Int, toIndex: Int) {
        val current = _videoUris.value.toMutableList()
        if (fromIndex in current.indices && toIndex in current.indices) {
            val item = current.removeAt(fromIndex)
            current.add(toIndex, item)
            _videoUris.value = current
        }
    }

    fun createMatch(onCreated: (String) -> Unit) {
        viewModelScope.launch {
            val match = Match(
                homeTeamName = _homeTeamName.value.ifBlank { "Home" },
                awayTeamName = _awayTeamName.value.ifBlank { "Away" },
                matchInfo = _matchInfo.value.ifBlank { null },
                videoUris = _videoUris.value
            )
            repository.insertMatch(match)
            onCreated(match.id)
        }
    }
}
