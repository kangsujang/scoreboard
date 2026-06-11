package com.overscore.ui.export

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.FileProvider
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.overscore.R
import com.overscore.viewmodel.ExportState
import com.overscore.viewmodel.ExportViewModel
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExportScreen(
    matchId: String,
    onNavigateToList: () -> Unit,
    onNavigateBack: () -> Unit,
    viewModel: ExportViewModel = hiltViewModel()
) {
    val context = LocalContext.current
    val match by viewModel.match.collectAsState()
    val state by viewModel.state.collectAsState()
    val progress by viewModel.progress.collectAsState()
    val outputPath by viewModel.outputPath.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()

    // Auto-start export
    LaunchedEffect(match) {
        if (match != null && state == ExportState.Idle) {
            viewModel.startExport(context)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.export_title)) },
                navigationIcon = {
                    IconButton(onClick = {
                        if (state == ExportState.Exporting) viewModel.cancel()
                        onNavigateBack()
                    }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                }
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentAlignment = Alignment.Center
        ) {
            when (state) {
                ExportState.Idle -> {
                    CircularProgressIndicator()
                }

                ExportState.Exporting -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                        modifier = Modifier.padding(32.dp)
                    ) {
                        Text(
                            text = stringResource(R.string.exporting),
                            style = MaterialTheme.typography.titleMedium
                        )

                        match?.let { m ->
                            Text(
                                text = "${m.homeTeamName}  ${m.homeScore} - ${m.awayScore}  ${m.awayTeamName}",
                                style = MaterialTheme.typography.titleLarge
                            )
                        }

                        LinearProgressIndicator(
                            progress = { progress },
                            modifier = Modifier.fillMaxWidth()
                        )

                        Text(
                            text = "${(progress * 100).toInt()}%",
                            style = MaterialTheme.typography.bodyMedium
                        )

                        OutlinedButton(onClick = {
                            viewModel.cancel()
                            onNavigateBack()
                        }) {
                            Text(stringResource(R.string.cancel))
                        }
                    }
                }

                ExportState.Complete -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp)
                    ) {
                        Text(
                            text = stringResource(R.string.export_complete),
                            style = MaterialTheme.typography.titleLarge
                        )

                        // Video player preview
                        outputPath?.let { path ->
                            ExportedVideoPlayer(
                                filePath = path,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .aspectRatio(16f / 9f)
                            )
                        }

                        Spacer(modifier = Modifier.height(4.dp))

                        Button(
                            onClick = {
                                outputPath?.let { path ->
                                    val file = File(path)
                                    val uri = FileProvider.getUriForFile(
                                        context,
                                        "${context.packageName}.fileprovider",
                                        file
                                    )
                                    val intent = Intent(Intent.ACTION_SEND).apply {
                                        type = "video/mp4"
                                        putExtra(Intent.EXTRA_STREAM, uri)
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    }
                                    context.startActivity(Intent.createChooser(intent, null))
                                }
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(stringResource(R.string.share))
                        }

                        OutlinedButton(
                            onClick = { viewModel.saveToGallery(context) },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(stringResource(R.string.save_to_gallery))
                        }

                        OutlinedButton(
                            onClick = onNavigateToList,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(stringResource(R.string.back_to_list))
                        }
                    }
                }

                ExportState.Failed -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                        modifier = Modifier.padding(32.dp)
                    ) {
                        Text(
                            text = stringResource(R.string.export_failed),
                            style = MaterialTheme.typography.titleLarge,
                            color = MaterialTheme.colorScheme.error
                        )

                        errorMessage?.let {
                            Text(
                                text = it,
                                style = MaterialTheme.typography.bodyMedium,
                                textAlign = TextAlign.Center
                            )
                        }

                        Button(onClick = { viewModel.startExport(context) }) {
                            Text(stringResource(R.string.retry))
                        }

                        OutlinedButton(onClick = onNavigateBack) {
                            Text(stringResource(R.string.cancel))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ExportedVideoPlayer(
    filePath: String,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val player = remember {
        ExoPlayer.Builder(context).build().apply {
            setMediaItem(MediaItem.fromUri(Uri.fromFile(File(filePath))))
            prepare()
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            player.release()
        }
    }

    AndroidView(
        factory = { ctx ->
            PlayerView(ctx).apply {
                this.player = player
                useController = true
            }
        },
        modifier = modifier.background(Color.Black)
    )
}
