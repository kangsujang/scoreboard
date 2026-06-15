package com.overscore.ui.common

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import com.overscore.model.Match
import com.overscore.service.ScoreboardRenderer

/**
 * Compose上のスコアボードプレビュー。
 * エクスポートと同一の ScoreboardRenderer を使って描画することで、
 * プレビューとエクスポート結果のピクセル単位の一致を保証する。
 */
@Composable
fun ScoreboardPreviewView(
    match: Match,
    currentTime: Double,
    modifier: Modifier = Modifier
) {
    val renderer = remember { ScoreboardRenderer() }

    Canvas(modifier = modifier) {
        drawIntoCanvas { canvas ->
            renderer.render(canvas.nativeCanvas, match, currentTime)
        }
    }
}
