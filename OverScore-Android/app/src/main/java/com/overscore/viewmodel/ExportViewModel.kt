package com.overscore.viewmodel

import android.content.Context
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.overscore.data.MatchRepository
import com.overscore.model.Match
import com.overscore.service.ExportForegroundService
import com.overscore.service.VideoExportService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

enum class ExportState {
    Idle,
    Exporting,
    Complete,
    Failed
}

@HiltViewModel
class ExportViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repository: MatchRepository,
    private val exportService: VideoExportService
) : ViewModel() {

    private val matchId: String = savedStateHandle["matchId"] ?: ""

    private val _match = MutableStateFlow<Match?>(null)
    val match: StateFlow<Match?> = _match.asStateFlow()

    private val _state = MutableStateFlow(ExportState.Idle)
    val state: StateFlow<ExportState> = _state.asStateFlow()

    private val _progress = MutableStateFlow(0f)
    val progress: StateFlow<Float> = _progress.asStateFlow()

    private val _outputPath = MutableStateFlow<String?>(null)
    val outputPath: StateFlow<String?> = _outputPath.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    init {
        viewModelScope.launch {
            _match.value = repository.getMatch(matchId)
        }
    }

    fun startExport(context: Context) {
        val m = _match.value ?: return
        if (_state.value == ExportState.Exporting) return

        _state.value = ExportState.Exporting
        _progress.value = 0f
        _errorMessage.value = null

        ExportForegroundService.start(context)

        viewModelScope.launch {
            try {
                val output = exportService.export(
                    context = context,
                    match = m,
                    onProgress = { _progress.value = it }
                )
                _outputPath.value = output
                _state.value = ExportState.Complete
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Export failed"
                _state.value = ExportState.Failed
            } finally {
                ExportForegroundService.stop(context)
            }
        }
    }

    fun saveToGallery(context: Context) {
        val path = _outputPath.value ?: return
        viewModelScope.launch {
            exportService.saveToGallery(context, path)
        }
    }

    fun cancel() {
        exportService.cancel()
        _state.value = ExportState.Idle
    }
}
