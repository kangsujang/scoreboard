package com.scoreframe.ui.scoreeditor

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scoreframe.R
import com.scoreframe.model.Match
import com.scoreframe.model.Team
import com.scoreframe.model.TimerSegment
import com.scoreframe.util.TimeFormatting

val periodPresets = listOf("前半", "後半", "延前", "延後", "PK")

@Composable
fun ScoreControlsView(
    match: Match,
    currentTime: Double,
    onAddGoal: (Team) -> Unit,
    onUndoGoal: (Team) -> Unit,
    onSegmentStart: (Int) -> Unit,
    onTimerStart: (Int) -> Unit,
    onTimerStop: (Int) -> Unit,
    onTimerClear: (Int) -> Unit,
    onSegmentOffsetChange: (Int, Double) -> Unit,
    onSegmentPeriodLabel: (Int, String?) -> Unit,
    onAddSegment: () -> Unit,
    onAddSegmentWithRestart: () -> Unit,
    onRemoveSegment: (Int) -> Unit
) {
    val (homeScore, awayScore) = match.scoreAt(currentTime)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
    ) {
        // Score display
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = match.homeTeamName,
                    style = MaterialTheme.typography.titleSmall
                )
                Text(
                    text = "$homeScore",
                    fontSize = 48.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            Text(
                text = "-",
                fontSize = 32.sp,
                modifier = Modifier.padding(horizontal = 16.dp)
            )

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = match.awayTeamName,
                    style = MaterialTheme.typography.titleSmall
                )
                Text(
                    text = "$awayScore",
                    fontSize = 48.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Current time display
        Text(
            text = TimeFormatting.format(currentTime),
            style = MaterialTheme.typography.bodySmall,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(8.dp))

        // Goal buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Button(onClick = { onAddGoal(Team.home) }) {
                    Text(stringResource(R.string.goal))
                }
                Spacer(modifier = Modifier.height(4.dp))
                OutlinedButton(onClick = { onUndoGoal(Team.home) }) {
                    Text(stringResource(R.string.undo))
                }
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Button(onClick = { onAddGoal(Team.away) }) {
                    Text(stringResource(R.string.goal))
                }
                Spacer(modifier = Modifier.height(4.dp))
                OutlinedButton(onClick = { onUndoGoal(Team.away) }) {
                    Text(stringResource(R.string.undo))
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Segment add buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedButton(onClick = { onAddSegment() }) {
                Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.padding(end = 4.dp))
                Text("セグメント追加", fontSize = 12.sp)
            }

            if (match.timerSegments.any { it.timerStartTime != null }) {
                Spacer(modifier = Modifier.width(8.dp))
                OutlinedButton(
                    onClick = { onAddSegmentWithRestart() },
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = Color(0xFFFF9800)
                    )
                ) {
                    Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.padding(end = 4.dp))
                    Text("タイマー引き継ぎ", fontSize = 12.sp)
                }
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Segment list (newest first)
        match.timerSegments.indices.reversed().forEach { index ->
            SegmentControlRow(
                index = index,
                segment = match.timerSegments[index],
                canRemove = match.timerSegments.size > 1,
                onSegmentStart = { onSegmentStart(index) },
                onTimerStart = { onTimerStart(index) },
                onTimerStop = { onTimerStop(index) },
                onTimerClear = { onTimerClear(index) },
                onOffsetChange = { onSegmentOffsetChange(index, it) },
                onPeriodLabel = { onSegmentPeriodLabel(index, it) },
                onRemove = { onRemoveSegment(index) }
            )
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

@Composable
private fun SegmentControlRow(
    index: Int,
    segment: TimerSegment,
    canRemove: Boolean,
    onSegmentStart: () -> Unit,
    onTimerStart: () -> Unit,
    onTimerStop: () -> Unit,
    onTimerClear: () -> Unit,
    onOffsetChange: (Double) -> Unit,
    onPeriodLabel: (String?) -> Unit,
    onRemove: () -> Unit
) {
    val totalOffsetSeconds = (segment.timerStartOffset ?: 0.0).toInt()
    val offsetMinutes = totalOffsetSeconds / 60
    val offsetSeconds = totalOffsetSeconds % 60

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                RoundedCornerShape(8.dp)
            )
            .padding(12.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "セグメント ${index + 1}",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            if (canRemove) {
                IconButton(onClick = onRemove) {
                    Icon(
                        Icons.Default.Delete,
                        contentDescription = "削除",
                        tint = MaterialTheme.colorScheme.error
                    )
                }
            }
        }

        // Period label presets + custom input
        val isCustomLabel = segment.periodLabel != null && segment.periodLabel !in periodPresets
        var customText by remember(segment.id) {
            mutableStateOf(if (isCustomLabel) segment.periodLabel ?: "" else "")
        }

        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            items(periodPresets) { preset ->
                FilterChip(
                    selected = segment.periodLabel == preset,
                    onClick = {
                        onPeriodLabel(if (segment.periodLabel == preset) null else preset)
                        customText = ""
                    },
                    label = { Text(preset, fontSize = 12.sp) }
                )
            }
            item {
                OutlinedTextField(
                    value = customText,
                    onValueChange = { newValue ->
                        customText = newValue
                        onPeriodLabel(newValue.ifEmpty { null })
                    },
                    placeholder = { Text("ラベル", fontSize = 12.sp) },
                    singleLine = true,
                    textStyle = MaterialTheme.typography.bodySmall,
                    modifier = Modifier
                        .widthIn(min = 80.dp, max = 120.dp)
                        .height(40.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = MaterialTheme.colorScheme.primary,
                        unfocusedBorderColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f)
                    )
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Timer control buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            // 区切り開始
            OutlinedButton(
                onClick = onSegmentStart,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = Color(0xFF9C27B0)
                )
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("区切り開始", fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
                    segment.segmentStartTime?.let {
                        Text(
                            TimeFormatting.format(it),
                            fontSize = 9.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // キックオフ
            OutlinedButton(
                onClick = onTimerStart,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = Color(0xFF4CAF50)
                )
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("キックオフ", fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
                    segment.timerStartTime?.let {
                        Text(
                            TimeFormatting.format(it),
                            fontSize = 9.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // 試合終了
            OutlinedButton(
                onClick = onTimerStop,
                modifier = Modifier.weight(1f),
                enabled = segment.timerStartTime != null || segment.segmentStartTime != null,
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = Color(0xFFFF9800)
                )
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("試合終了", fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
                    segment.timerStopTime?.let {
                        Text(
                            TimeFormatting.format(it),
                            fontSize = 9.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // クリアボタン
            if (segment.segmentStartTime != null || segment.timerStartTime != null || segment.timerStopTime != null) {
                IconButton(onClick = onTimerClear) {
                    Icon(
                        Icons.Default.Clear,
                        contentDescription = "クリア",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        // 開始時間オフセット調整
        if (segment.timerStartTime != null) {
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "開始時間",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.weight(1f))

                // 分の調整
                TextButton(
                    onClick = {
                        onOffsetChange(((offsetMinutes - 1) * 60 + offsetSeconds).toDouble())
                    },
                    enabled = offsetMinutes > 0
                ) {
                    Text("-", fontWeight = FontWeight.Bold)
                }
                Text(
                    String.format("%02d", offsetMinutes),
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Medium
                )
                TextButton(
                    onClick = {
                        onOffsetChange(((offsetMinutes + 1) * 60 + offsetSeconds).toDouble())
                    }
                ) {
                    Text("+", fontWeight = FontWeight.Bold)
                }

                Text(":", fontWeight = FontWeight.Medium)

                // 秒の調整
                TextButton(
                    onClick = {
                        onOffsetChange((offsetMinutes * 60 + offsetSeconds - 1).toDouble())
                    },
                    enabled = totalOffsetSeconds > 0
                ) {
                    Text("-", fontWeight = FontWeight.Bold)
                }
                Text(
                    String.format("%02d", offsetSeconds),
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Medium
                )
                TextButton(
                    onClick = {
                        val newSec = offsetSeconds + 1
                        if (newSec >= 60) {
                            onOffsetChange(((offsetMinutes + 1) * 60).toDouble())
                        } else {
                            onOffsetChange((offsetMinutes * 60 + newSec).toDouble())
                        }
                    }
                ) {
                    Text("+", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}
