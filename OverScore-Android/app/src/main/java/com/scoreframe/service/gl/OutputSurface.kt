package com.scoreframe.service.gl

import android.graphics.SurfaceTexture
import android.view.Surface

/**
 * デコーダー出力Surface用ラッパー。
 * SurfaceTextureでフレームを受け取り、OESテクスチャとして利用可能にする。
 */
class OutputSurface : SurfaceTexture.OnFrameAvailableListener {

    var textureId: Int = 0
        private set
    var surfaceTexture: SurfaceTexture? = null
        private set
    var surface: Surface? = null
        private set

    private val frameSyncObject = Object()
    private var frameAvailable = false

    fun setup(texId: Int) {
        textureId = texId
        surfaceTexture = SurfaceTexture(texId).also {
            it.setOnFrameAvailableListener(this)
        }
        surface = Surface(surfaceTexture)
    }

    fun release() {
        surface?.release()
        surface = null
        surfaceTexture?.release()
        surfaceTexture = null
    }

    /**
     * 次のフレームが来るまで待機。タイムアウト付き。
     */
    fun awaitNewImage(timeoutMs: Long = 2500) {
        synchronized(frameSyncObject) {
            while (!frameAvailable) {
                frameSyncObject.wait(timeoutMs)
                if (!frameAvailable) {
                    throw RuntimeException("Frame wait timed out")
                }
            }
            frameAvailable = false
        }
        surfaceTexture?.updateTexImage()
    }

    fun getTransformMatrix(matrix: FloatArray) {
        surfaceTexture?.getTransformMatrix(matrix)
    }

    override fun onFrameAvailable(st: SurfaceTexture?) {
        synchronized(frameSyncObject) {
            if (frameAvailable) {
                // 前のフレームが消費されていない場合でも通知
            }
            frameAvailable = true
            frameSyncObject.notifyAll()
        }
    }
}
