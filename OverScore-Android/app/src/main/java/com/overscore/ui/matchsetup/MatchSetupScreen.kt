package com.overscore.ui.matchsetup

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.VideoLibrary
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.overscore.R
import com.overscore.viewmodel.MatchSetupViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MatchSetupScreen(
    onNavigateToEditor: (String) -> Unit,
    onNavigateBack: () -> Unit,
    viewModel: MatchSetupViewModel = hiltViewModel()
) {
    val context = LocalContext.current
    val homeTeamName by viewModel.homeTeamName.collectAsState()
    val awayTeamName by viewModel.awayTeamName.collectAsState()
    val matchInfo by viewModel.matchInfo.collectAsState()
    val videoUris by viewModel.videoUris.collectAsState()

    val videoPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenMultipleDocuments()
    ) { uris: List<Uri> ->
        if (uris.isNotEmpty()) {
            viewModel.addVideos(context, uris)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.match_setup_title)) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.cancel))
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Spacer(modifier = Modifier.height(8.dp))

            OutlinedTextField(
                value = homeTeamName,
                onValueChange = viewModel::setHomeTeamName,
                label = { Text(stringResource(R.string.home_team)) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            OutlinedTextField(
                value = awayTeamName,
                onValueChange = viewModel::setAwayTeamName,
                label = { Text(stringResource(R.string.away_team)) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            OutlinedTextField(
                value = matchInfo,
                onValueChange = viewModel::setMatchInfo,
                label = { Text(stringResource(R.string.match_info_label)) },
                placeholder = { Text(stringResource(R.string.match_info_placeholder)) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            // Video selection
            Text(
                text = stringResource(R.string.select_videos),
                style = MaterialTheme.typography.titleSmall
            )

            OutlinedButton(
                onClick = { videoPickerLauncher.launch(arrayOf("video/*")) },
                enabled = videoUris.size < 10
            ) {
                Icon(Icons.Default.VideoLibrary, contentDescription = null)
                Text(
                    text = " ${stringResource(R.string.add_video)} (${videoUris.size}/10)",
                    modifier = Modifier.padding(start = 8.dp)
                )
            }

            videoUris.forEachIndexed { index, uri ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Video ${index + 1}",
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f)
                    )
                    IconButton(onClick = { viewModel.removeVideo(index) }) {
                        Icon(Icons.Default.Close, contentDescription = stringResource(R.string.delete_match))
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            Button(
                onClick = { viewModel.createMatch(onNavigateToEditor) },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(stringResource(R.string.next))
            }

            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}
