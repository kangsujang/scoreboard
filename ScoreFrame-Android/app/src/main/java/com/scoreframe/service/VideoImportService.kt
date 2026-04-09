package com.scoreframe.service

import android.content.Context
import android.net.Uri
import java.io.File
import java.io.FileOutputStream
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class VideoImportService @Inject constructor() {

    fun importVideo(context: Context, uri: Uri): String? {
        return try {
            val videosDir = File(context.filesDir, "Videos")
            if (!videosDir.exists()) videosDir.mkdirs()

            val fileName = "video_${System.currentTimeMillis()}.mp4"
            val destFile = File(videosDir, fileName)

            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }

            // 永続的なURI権限を取得
            try {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            } catch (_: Exception) {
                // 権限取得できない場合はコピーしたファイルを使う
            }

            Uri.fromFile(destFile).toString()
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    fun cleanupOrphanedVideos(context: Context, activeUris: Set<String>) {
        val videosDir = File(context.filesDir, "Videos")
        if (!videosDir.exists()) return

        videosDir.listFiles()?.forEach { file ->
            val fileUri = Uri.fromFile(file).toString()
            if (fileUri !in activeUris) {
                file.delete()
            }
        }
    }

    fun cleanupTempFiles(context: Context) {
        val tempDir = File(context.cacheDir, "export")
        tempDir.listFiles()?.forEach { it.delete() }
    }
}
