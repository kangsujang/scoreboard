package com.overscore.ui.matchdetail

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.overscore.R
import com.overscore.model.Match
import com.overscore.model.ScoreboardStyle
import com.overscore.ui.common.ScoreboardPreviewView

enum class EditTarget { Scoreboard, MatchInfo }

@Composable
fun ScoreboardStyleSheet(
    match: Match,
    style: ScoreboardStyle,
    onStyleChange: (ScoreboardStyle) -> Unit,
    onDismiss: () -> Unit
) {
    var currentStyle by remember { mutableStateOf(style) }
    var editTarget by remember { mutableStateOf(EditTarget.Scoreboard) }

    // Base values for gestures
    var baseScale by remember { mutableFloatStateOf(style.scale) }
    var basePosX by remember { mutableFloatStateOf(style.positionX) }
    var basePosY by remember { mutableFloatStateOf(style.positionY) }
    var baseInfoScale by remember { mutableFloatStateOf(style.matchInfoScale) }
    var baseInfoPosX by remember { mutableFloatStateOf(style.matchInfoPositionX) }
    var baseInfoPosY by remember { mutableFloatStateOf(style.matchInfoPositionY) }

    var previewSize by remember { mutableStateOf(IntSize.Zero) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = stringResource(R.string.style_title),
            style = MaterialTheme.typography.titleLarge
        )

        // Preview with gesture support
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f)
                .background(Color.DarkGray)
                .onSizeChanged { previewSize = it }
                .pointerInput(editTarget) {
                    detectTransformGestures { _, pan, zoom, _ ->
                        val w = previewSize.width.toFloat()
                        val h = previewSize.height.toFloat()
                        if (w <= 0 || h <= 0) return@detectTransformGestures

                        if (editTarget == EditTarget.Scoreboard) {
                            // Pinch to scale
                            val newScale = (currentStyle.scale * zoom).coerceIn(0.5f, 2.5f)
                            // Drag to move
                            val newX = (currentStyle.positionX + pan.x / w).coerceIn(0f, 0.95f)
                            val newY = (currentStyle.positionY + pan.y / h).coerceIn(0f, 0.95f)
                            currentStyle = currentStyle.copy(
                                scale = newScale,
                                positionX = newX,
                                positionY = newY
                            )
                        } else {
                            val newScale = (currentStyle.matchInfoScale * zoom).coerceIn(0.5f, 2.5f)
                            val newX = (currentStyle.matchInfoPositionX + pan.x / w).coerceIn(0f, 0.95f)
                            val newY = (currentStyle.matchInfoPositionY + pan.y / h).coerceIn(0f, 0.95f)
                            currentStyle = currentStyle.copy(
                                matchInfoScale = newScale,
                                matchInfoPositionX = newX,
                                matchInfoPositionY = newY
                            )
                        }
                        onStyleChange(currentStyle)
                    }
                }
        ) {
            ScoreboardPreviewView(
                match = match.copy(scoreboardStyle = currentStyle),
                currentTime = match.sortedEvents.lastOrNull()?.timestamp ?: 0.0,
                modifier = Modifier.fillMaxSize()
            )
        }

        // Edit target selector
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            SegmentedButton(
                selected = editTarget == EditTarget.Scoreboard,
                onClick = { editTarget = EditTarget.Scoreboard },
                shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2)
            ) { Text("スコアボード") }
            SegmentedButton(
                selected = editTarget == EditTarget.MatchInfo,
                onClick = { editTarget = EditTarget.MatchInfo },
                shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2)
            ) { Text("試合情報") }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "ピンチでサイズ変更・ドラッグで位置調整",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            OutlinedButton(onClick = {
                if (editTarget == EditTarget.Scoreboard) {
                    currentStyle = currentStyle.copy(positionX = 0.02f, positionY = 0.02f, scale = 1.0f)
                    baseScale = 1.0f; basePosX = 0.02f; basePosY = 0.02f
                } else {
                    currentStyle = currentStyle.copy(matchInfoPositionX = 0.02f, matchInfoPositionY = 0.12f, matchInfoScale = 1.0f)
                    baseInfoScale = 1.0f; baseInfoPosX = 0.02f; baseInfoPosY = 0.12f
                }
                onStyleChange(currentStyle)
            }) { Text("リセット") }
        }

        // Theme selection
        Text(text = stringResource(R.string.theme), style = MaterialTheme.typography.titleSmall)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            ScoreboardStyle.Theme.entries.forEach { theme ->
                FilterChip(
                    selected = currentStyle.theme == theme,
                    onClick = {
                        currentStyle = currentStyle.copy(theme = theme)
                        onStyleChange(currentStyle)
                    },
                    label = { Text(theme.displayName) }
                )
            }
        }

        // Toggle options
        SwitchRow(
            label = stringResource(R.string.show_score),
            checked = currentStyle.showScore,
            onCheckedChange = {
                currentStyle = currentStyle.copy(showScore = it)
                onStyleChange(currentStyle)
            }
        )

        SwitchRow(
            label = stringResource(R.string.show_timer),
            checked = currentStyle.showMatchTimer,
            onCheckedChange = {
                currentStyle = currentStyle.copy(showMatchTimer = it)
                onStyleChange(currentStyle)
            }
        )

        if (currentStyle.showMatchTimer) {
            Text(text = stringResource(R.string.timer_position), style = MaterialTheme.typography.titleSmall)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = currentStyle.timerPosition == ScoreboardStyle.TimerPosition.left,
                    onClick = {
                        currentStyle = currentStyle.copy(timerPosition = ScoreboardStyle.TimerPosition.left)
                        onStyleChange(currentStyle)
                    },
                    label = { Text(stringResource(R.string.timer_left)) }
                )
                FilterChip(
                    selected = currentStyle.timerPosition == ScoreboardStyle.TimerPosition.right,
                    onClick = {
                        currentStyle = currentStyle.copy(timerPosition = ScoreboardStyle.TimerPosition.right)
                        onStyleChange(currentStyle)
                    },
                    label = { Text(stringResource(R.string.timer_right)) }
                )
            }
        }

        SwitchRow(
            label = stringResource(R.string.show_timer_options),
            checked = currentStyle.showTimerOptions,
            onCheckedChange = {
                currentStyle = currentStyle.copy(showTimerOptions = it)
                onStyleChange(currentStyle)
            }
        )

        SwitchRow(
            label = stringResource(R.string.show_penalty_timer),
            checked = currentStyle.showPenaltyTimer,
            onCheckedChange = {
                currentStyle = currentStyle.copy(showPenaltyTimer = it)
                onStyleChange(currentStyle)
            }
        )

        SwitchRow(
            label = stringResource(R.string.show_timeouts),
            checked = currentStyle.showTimeouts,
            onCheckedChange = {
                currentStyle = currentStyle.copy(showTimeouts = it)
                onStyleChange(currentStyle)
            }
        )

        // Team colors
        TeamColorPicker(
            label = stringResource(R.string.home_team_color),
            hex = currentStyle.homeTeamColorHex,
            placeholder = "#FF0000",
            onHexChange = {
                currentStyle = currentStyle.copy(homeTeamColorHex = it)
                onStyleChange(currentStyle)
            }
        )

        TeamColorPicker(
            label = stringResource(R.string.away_team_color),
            hex = currentStyle.awayTeamColorHex,
            placeholder = "#0000FF",
            onHexChange = {
                currentStyle = currentStyle.copy(awayTeamColorHex = it)
                onStyleChange(currentStyle)
            }
        )

        Spacer(modifier = Modifier.height(8.dp))

        Button(
            onClick = onDismiss,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(stringResource(R.string.done))
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}

private val PresetTeamColors: List<Pair<String, Color>> = listOf(
    "#E53935" to Color(0xFFE53935), // 赤
    "#1E88E5" to Color(0xFF1E88E5), // 青
    "#FDD835" to Color(0xFFFDD835), // 黄
    "#43A047" to Color(0xFF43A047), // 緑
    "#FB8C00" to Color(0xFFFB8C00), // 橙
    "#8E24AA" to Color(0xFF8E24AA), // 紫
    "#00ACC1" to Color(0xFF00ACC1), // 水
    "#EC407A" to Color(0xFFEC407A), // 桃
    "#6D4C41" to Color(0xFF6D4C41), // 茶
    "#000000" to Color(0xFF000000), // 黒
    "#FFFFFF" to Color(0xFFFFFFFF), // 白
)

private fun parseHexColor(hex: String?): Color? {
    if (hex.isNullOrBlank()) return null
    return try {
        val clean = hex.trim().removePrefix("#")
        val value = when (clean.length) {
            6 -> ("FF$clean").toLong(16)
            8 -> clean.toLong(16)
            else -> return null
        }
        Color(value)
    } catch (_: Exception) { null }
}

@Composable
private fun TeamColorPicker(
    label: String,
    hex: String?,
    placeholder: String,
    onHexChange: (String?) -> Unit
) {
    val currentColor = parseHexColor(hex)
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(text = label, style = MaterialTheme.typography.titleSmall)
            Box(
                modifier = Modifier
                    .size(20.dp)
                    .background(currentColor ?: Color.Transparent, CircleShape)
                    .border(1.dp, Color.Gray, CircleShape)
            )
        }
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(vertical = 4.dp)
        ) {
            items(PresetTeamColors) { item ->
                val presetHex = item.first
                val presetColor = item.second
                val selected = hex?.equals(presetHex, ignoreCase = true) == true
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .background(presetColor, CircleShape)
                        .border(
                            width = if (selected) 3.dp else 1.dp,
                            color = if (selected) MaterialTheme.colorScheme.primary else Color.Gray,
                            shape = CircleShape
                        )
                        .clickable { onHexChange(presetHex) }
                )
            }
        }
        OutlinedTextField(
            value = hex ?: "",
            onValueChange = { onHexChange(it.ifBlank { null }) },
            placeholder = { Text(placeholder) },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )
    }
}

@Composable
private fun SwitchRow(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = label, style = MaterialTheme.typography.bodyLarge)
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
