package com.overscore.ui.scoreeditor

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.overscore.R
import com.overscore.ui.common.ScoreboardPreviewView
import com.overscore.viewmodel.PlayerViewModel
import com.overscore.viewmodel.ScoreEditorViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScoreEditorScreen(
    matchId: String,
    onNavigateToDetail: () -> Unit,
    onNavigateBack: () -> Unit,
    viewModel: ScoreEditorViewModel = hiltViewModel()
) {
    val match by viewModel.match.collectAsState()
    val currentTime by viewModel.currentTime.collectAsState()
    val context = LocalContext.current

    val playerViewModel = remember { PlayerViewModel() }
    val isPlaying by playerViewModel.isPlaying.collectAsState()
    val positionMs by playerViewModel.currentPositionMs.collectAsState()
    val durationMs by playerViewModel.durationMs.collectAsState()

    val m = match ?: return

    // Initialize player
    LaunchedEffect(m.videoUris) {
        if (m.videoUris.isNotEmpty()) {
            playerViewModel.initialize(context, m.videoUris)
        }
    }

    // Position polling
    LaunchedEffect(Unit) {
        while (isActive) {
            playerViewModel.updatePosition()
            viewModel.setCurrentTime(playerViewModel.currentPositionMs.value / 1000.0)
            delay(100)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.score_editor_title)) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                },
                actions = {
                    Button(onClick = onNavigateToDetail) {
                        Text(stringResource(R.string.finish))
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // 上部固定: 動画プレイヤー + スコアボードプレビュー + 再生コントロール
            if (m.videoUris.isNotEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(16f / 9f)
                ) {
                    VideoPlayerView(
                        player = playerViewModel.player,
                        modifier = Modifier.fillMaxSize()
                    )
                    ScoreboardPreviewView(
                        match = m,
                        currentTime = currentTime,
                        modifier = Modifier.fillMaxSize()
                    )
                }

                PlaybackControlsView(
                    isPlaying = isPlaying,
                    positionMs = positionMs,
                    durationMs = durationMs,
                    playbackSpeed = playerViewModel.playbackSpeed.collectAsState().value,
                    onTogglePlay = { playerViewModel.togglePlayPause() },
                    onSeek = { playerViewModel.seekTo(it) },
                    onSkip = { playerViewModel.skip(it) },
                    onSpeedChange = { playerViewModel.setPlaybackSpeed(it) }
                )
            }

            // 下部スクロール: スコアコントロール + イベントリスト
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
            ) {
                Spacer(modifier = Modifier.height(8.dp))

                ScoreControlsView(
                    match = m,
                    currentTime = currentTime,
                    onAddGoal = { viewModel.addGoal(it) },
                    onUndoGoal = { viewModel.undoLastGoal(it) },
                    onSegmentStart = { viewModel.setSegmentStart(it) },
                    onTimerStart = { viewModel.startTimer(it) },
                    onTimerStop = { viewModel.stopTimer(it) },
                    onTimerClear = { viewModel.clearSegmentTimer(it) },
                    onSegmentOffsetChange = { idx, secs -> viewModel.setSegmentOffset(idx, secs) },
                    onSegmentPeriodLabel = { idx, label -> viewModel.setSegmentPeriodLabel(idx, label) },
                    onAddSegment = { viewModel.addTimerSegment(null) },
                    onAddSegmentWithRestart = { viewModel.addTimerSegmentWithRestart() },
                    onRemoveSegment = { viewModel.removeTimerSegment(it) }
                )

                Spacer(modifier = Modifier.height(16.dp))

                EventListView(
                    events = m.sortedEvents,
                    onDeleteEvent = { viewModel.deleteScoreEvent(it) }
                )

                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }
}
