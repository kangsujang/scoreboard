package com.scoreframe.ui.scoreeditor

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.Player
import androidx.media3.ui.PlayerView

@Composable
fun VideoPlayerView(
    player: Player?,
    modifier: Modifier = Modifier
) {
    AndroidView(
        factory = { context ->
            PlayerView(context).apply {
                useController = false
                this.player = player
            }
        },
        update = { view ->
            view.player = player
        },
        modifier = modifier
    )
}
