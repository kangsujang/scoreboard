package com.overscore.service

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.nio.ByteBuffer
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 複数動画を連結するビルダー
 * iOS版の VideoCompositionBuilder に対応
 */
@Singleton
class VideoCompositionBuilder @Inject constructor() {

    @Volatile
    private var cancelled = false

    fun cancel() {
        cancelled = true
    }

    suspend fun concatenateVideos(
        context: Context,
        videoUris: List<String>,
        outputPath: String,
        onProgress: (Float) -> Unit
    ) = withContext(Dispatchers.IO) {
        cancelled = false

        if (videoUris.size == 1) {
            // 単一動画: 直接コピー
            copyVideo(context, videoUris.first(), outputPath, onProgress)
            return@withContext
        }

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var videoTrackIndex = -1
        var audioTrackIndex = -1
        var muxerStarted = false
        var currentTimeOffsetUs = 0L
        val bufferSize = 1024 * 1024 // 1MB
        val buffer = ByteBuffer.allocate(bufferSize)
        val bufferInfo = MediaCodec.BufferInfo()

        try {
            for ((fileIndex, uriString) in videoUris.withIndex()) {
                if (cancelled) break

                val extractor = MediaExtractor()
                try {
                    val uri = Uri.parse(uriString)
                    extractor.setDataSource(context, uri, null)

                    var sourceVideoTrack = -1
                    var sourceAudioTrack = -1

                    for (i in 0 until extractor.trackCount) {
                        val format = extractor.getTrackFormat(i)
                        val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                        if (mime.startsWith("video/") && sourceVideoTrack < 0) {
                            sourceVideoTrack = i
                            if (!muxerStarted) {
                                videoTrackIndex = muxer.addTrack(format)
                            }
                        } else if (mime.startsWith("audio/") && sourceAudioTrack < 0) {
                            sourceAudioTrack = i
                            if (!muxerStarted) {
                                audioTrackIndex = muxer.addTrack(format)
                            }
                        }
                    }

                    if (!muxerStarted) {
                        muxer.start()
                        muxerStarted = true
                    }

                    var maxTimestampUs = 0L

                    // Video track
                    if (sourceVideoTrack >= 0 && videoTrackIndex >= 0) {
                        extractor.selectTrack(sourceVideoTrack)
                        while (!cancelled) {
                            val sampleSize = extractor.readSampleData(buffer, 0)
                            if (sampleSize < 0) break
                            bufferInfo.size = sampleSize
                            bufferInfo.offset = 0
                            bufferInfo.presentationTimeUs = extractor.sampleTime + currentTimeOffsetUs
                            bufferInfo.flags = extractor.sampleFlags
                            muxer.writeSampleData(videoTrackIndex, buffer, bufferInfo)
                            maxTimestampUs = maxOf(maxTimestampUs, extractor.sampleTime)
                            extractor.advance()
                        }
                        extractor.unselectTrack(sourceVideoTrack)
                    }

                    // Audio track
                    if (sourceAudioTrack >= 0 && audioTrackIndex >= 0) {
                        extractor.selectTrack(sourceAudioTrack)
                        while (!cancelled) {
                            val sampleSize = extractor.readSampleData(buffer, 0)
                            if (sampleSize < 0) break
                            bufferInfo.size = sampleSize
                            bufferInfo.offset = 0
                            bufferInfo.presentationTimeUs = extractor.sampleTime + currentTimeOffsetUs
                            bufferInfo.flags = extractor.sampleFlags
                            muxer.writeSampleData(audioTrackIndex, buffer, bufferInfo)
                            extractor.advance()
                        }
                        extractor.unselectTrack(sourceAudioTrack)
                    }

                    currentTimeOffsetUs += maxTimestampUs + 33333 // ~30fps gap

                } finally {
                    extractor.release()
                }

                onProgress((fileIndex + 1).toFloat() / videoUris.size)
            }
        } finally {
            if (muxerStarted) {
                muxer.stop()
            }
            muxer.release()
        }
    }

    private fun copyVideo(
        context: Context,
        uriString: String,
        outputPath: String,
        onProgress: (Float) -> Unit
    ) {
        val uri = Uri.parse(uriString)
        context.contentResolver.openInputStream(uri)?.use { input ->
            java.io.FileOutputStream(outputPath).use { output ->
                val buffer = ByteArray(8192)
                var bytesRead: Int
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                }
            }
        }
        onProgress(1f)
    }
}
