package com.scoreframe.ui.scoreeditor

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.scoreframe.R
import com.scoreframe.model.ScoreEvent
import com.scoreframe.model.Team
import com.scoreframe.util.TimeFormatting

@Composable
fun EventListView(
    events: List<ScoreEvent>,
    onDeleteEvent: (ScoreEvent) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
    ) {
        Text(
            text = stringResource(R.string.events),
            style = MaterialTheme.typography.titleSmall
        )

        if (events.isEmpty()) {
            Text(
                text = stringResource(R.string.no_events),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(vertical = 8.dp)
            )
        } else {
            events.forEach { event ->
                HorizontalDivider()
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val icon = if (event.team == Team.home) "\u26BD" else "\u26BD"
                    val teamLabel = if (event.team == Team.home) "HOME" else "AWAY"
                    Text(
                        text = "$icon $teamLabel  ${TimeFormatting.format(event.timestamp)}",
                        style = MaterialTheme.typography.bodyMedium
                    )
                    IconButton(onClick = { onDeleteEvent(event) }) {
                        Icon(
                            Icons.Default.Close,
                            contentDescription = stringResource(R.string.delete_match),
                            tint = MaterialTheme.colorScheme.error
                        )
                    }
                }
            }
        }
    }
}
