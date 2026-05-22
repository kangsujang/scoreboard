package com.scoreframe.service

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import com.scoreframe.model.Match
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileInputStream
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 動画エクスポートサービス。
 * iOS版の VideoExportService に対応。
 * オーバーレイあり/なしの両モードをサポート。
 */
@Singleton
class VideoExportService @Inject constructor(
    private val compositionBuilder: VideoCompositionBuilder,
    private val overlayPipeline: OverlayExportPipeline
) {
    @Volatile
    private var cancelled = false

    suspend fun export(
        context: Context,
        match: Match,
        onProgress: (Float) -> Unit
    ): String = withContext(Dispatchers.IO) {
        cancelled = false

        val exportDir = File(context.cacheDir, "export")
        if (!exportDir.exists()) exportDir.mkdirs()
        val outputFile = File(exportDir, "ScoreFrame_${System.currentTimeMillis()}.mp4")

        if (match.videoUris.isEmpty()) {
            throw IllegalStateException("No videos to export")
        }

        if (match.skipOverlay) {
            // オーバーレイなし: 連結のみ
            compositionBuilder.concatenateVideos(
                context = context,
                videoUris = match.videoUris,
                outputPath = outputFile.absolutePath,
                onProgress = onProgress
            )
        } else {
            // オーバーレイあり
            if (match.videoUris.size == 1) {
                // 単一動画: 直接オーバーレイ処理
                val uri = Uri.parse(match.videoUris.first())
                val inputFile = uriToTempFile(context, uri)
                try {
                    overlayPipeline.exportWithOverlay(
                        context = context,
                        match = match,
                        inputPath = inputFile.absolutePath,
                        outputPath = outputFile.absolutePath,
                        onProgress = onProgress
                    )
                } finally {
                    inputFile.delete()
                }
            } else {
                // 複数動画: まず連結→オーバーレイ
                val tempConcat = File(exportDir, "concat_temp_${System.currentTimeMillis()}.mp4")
                try {
                    compositionBuilder.concatenateVideos(
                        context = context,
                        videoUris = match.videoUris,
                        outputPath = tempConcat.absolutePath,
                        onProgress = { onProgress(it * 0.3f) } // 連結は全体の30%
                    )

                    overlayPipeline.exportWithOverlay(
                        context = context,
                        match = match,
                        inputPath = tempConcat.absolutePath,
                        outputPath = outputFile.absolutePath,
                        onProgress = { onProgress(0.3f + it * 0.7f) } // オーバーレイは70%
                    )
                } finally {
                    tempConcat.delete()
                }
            }
        }

        if (cancelled) {
            outputFile.delete()
            throw IllegalStateException("Export cancelled")
        }

        outputFile.absolutePath
    }

    fun cancel() {
        cancelled = true
        compositionBuilder.cancel()
        overlayPipeline.cancel()
    }

    suspend fun saveToGallery(context: Context, filePath: String) = withContext(Dispatchers.IO) {
        val file = File(filePath)
        if (!file.exists()) return@withContext

        val contentValues = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, file.name)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/ScoreFrame")
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
        }

        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, contentValues)
            ?: return@withContext

        resolver.openOutputStream(uri)?.use { output ->
            FileInputStream(file).use { input ->
                input.copyTo(output)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            contentValues.clear()
            contentValues.put(MediaStore.Video.Media.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)
        }
    }

    fun shareVideo(context: Context, filePath: String) {
        val file = File(filePath)
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

    private fun uriToTempFile(context: Context, uri: Uri): File {
        val tempFile = File(context.cacheDir, "export_input_${System.currentTimeMillis()}.mp4")
        context.contentResolver.openInputStream(uri)?.use { input ->
            tempFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }
        return tempFile
    }
}
