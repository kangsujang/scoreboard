package com.overscore.service.gl

import android.graphics.Bitmap
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.Matrix
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * GLES2シェーダーによる動画テクスチャ描画 + スコアボードオーバーレイ合成。
 * OES external textureで動画フレームを描画し、2Dテクスチャでオーバーレイを合成。
 */
class TextureRenderer {

    // 動画用シェーダー（OES external texture）
    private val vertexShaderCode = """
        uniform mat4 uMVPMatrix;
        uniform mat4 uSTMatrix;
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;
        varying vec2 vTextureCoord;
        void main() {
            gl_Position = uMVPMatrix * aPosition;
            vTextureCoord = (uSTMatrix * aTextureCoord).xy;
        }
    """.trimIndent()

    private val fragmentShaderCode = """
        #extension GL_OES_EGL_image_external : require
        precision mediump float;
        varying vec2 vTextureCoord;
        uniform samplerExternalOES sTexture;
        void main() {
            gl_FragColor = texture2D(sTexture, vTextureCoord);
        }
    """.trimIndent()

    // オーバーレイ用シェーダー（通常2Dテクスチャ、アルファブレンド）
    private val overlayFragmentShaderCode = """
        precision mediump float;
        varying vec2 vTextureCoord;
        uniform sampler2D sTexture;
        void main() {
            gl_FragColor = texture2D(sTexture, vTextureCoord);
        }
    """.trimIndent()

    private var program = 0
    private var overlayProgram = 0
    private var overlayTextureId = 0

    private var aPositionHandle = 0
    private var aTextureCoordHandle = 0
    private var uMVPMatrixHandle = 0
    private var uSTMatrixHandle = 0

    private var overlayPositionHandle = 0
    private var overlayTextureCoordHandle = 0
    private var overlayMVPMatrixHandle = 0
    private var overlaySTMatrixHandle = 0

    private val mvpMatrix = FloatArray(16)

    // オーバーレイ用ST行列: Bitmap座標(左上原点) → OpenGLテクスチャ座標(左下原点) のY反転
    // (u, v) → (u, 1-v)
    private val overlaySTMatrix = floatArrayOf(
        1f,  0f, 0f, 0f,
        0f, -1f, 0f, 0f,
        0f,  0f, 1f, 0f,
        0f,  1f, 0f, 1f
    )

    private val triangleVerticesData = floatArrayOf(
        // positions    // texture coords
        -1.0f, -1.0f,  0.0f, 0.0f,
         1.0f, -1.0f,  1.0f, 0.0f,
        -1.0f,  1.0f,  0.0f, 1.0f,
         1.0f,  1.0f,  1.0f, 1.0f,
    )

    private val vertexBuffer: FloatBuffer = ByteBuffer
        .allocateDirect(triangleVerticesData.size * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .put(triangleVerticesData)
        .also { it.position(0) }

    fun setup() {
        // 動画用プログラム
        program = createProgram(vertexShaderCode, fragmentShaderCode)
        aPositionHandle = GLES20.glGetAttribLocation(program, "aPosition")
        aTextureCoordHandle = GLES20.glGetAttribLocation(program, "aTextureCoord")
        uMVPMatrixHandle = GLES20.glGetUniformLocation(program, "uMVPMatrix")
        uSTMatrixHandle = GLES20.glGetUniformLocation(program, "uSTMatrix")

        // オーバーレイ用プログラム
        overlayProgram = createProgram(vertexShaderCode, overlayFragmentShaderCode)
        overlayPositionHandle = GLES20.glGetAttribLocation(overlayProgram, "aPosition")
        overlayTextureCoordHandle = GLES20.glGetAttribLocation(overlayProgram, "aTextureCoord")
        overlayMVPMatrixHandle = GLES20.glGetUniformLocation(overlayProgram, "uMVPMatrix")
        overlaySTMatrixHandle = GLES20.glGetUniformLocation(overlayProgram, "uSTMatrix")

        // オーバーレイテクスチャ作成
        val texIds = IntArray(1)
        GLES20.glGenTextures(1, texIds, 0)
        overlayTextureId = texIds[0]
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, overlayTextureId)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

        Matrix.setIdentityM(mvpMatrix, 0)
    }

    fun createOESTexture(): Int {
        val texIds = IntArray(1)
        GLES20.glGenTextures(1, texIds, 0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texIds[0])
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        return texIds[0]
    }

    /**
     * 動画フレームを描画
     */
    fun drawVideoFrame(textureId: Int, stMatrix: FloatArray) {
        GLES20.glUseProgram(program)
        checkGlError("glUseProgram")

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)

        vertexBuffer.position(0)
        GLES20.glVertexAttribPointer(aPositionHandle, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        GLES20.glEnableVertexAttribArray(aPositionHandle)

        vertexBuffer.position(2)
        GLES20.glVertexAttribPointer(aTextureCoordHandle, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        GLES20.glEnableVertexAttribArray(aTextureCoordHandle)

        GLES20.glUniformMatrix4fv(uMVPMatrixHandle, 1, false, mvpMatrix, 0)
        GLES20.glUniformMatrix4fv(uSTMatrixHandle, 1, false, stMatrix, 0)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        checkGlError("glDrawArrays")

        GLES20.glDisableVertexAttribArray(aPositionHandle)
        GLES20.glDisableVertexAttribArray(aTextureCoordHandle)
    }

    /**
     * オーバーレイBitmapを合成描画（アルファブレンド）
     */
    fun drawOverlay(overlayBitmap: Bitmap) {
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)

        // Bitmapをテクスチャにアップロード
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, overlayTextureId)
        android.opengl.GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, overlayBitmap, 0)

        GLES20.glUseProgram(overlayProgram)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, overlayTextureId)

        vertexBuffer.position(0)
        GLES20.glVertexAttribPointer(overlayPositionHandle, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        GLES20.glEnableVertexAttribArray(overlayPositionHandle)

        vertexBuffer.position(2)
        GLES20.glVertexAttribPointer(overlayTextureCoordHandle, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        GLES20.glEnableVertexAttribArray(overlayTextureCoordHandle)

        GLES20.glUniformMatrix4fv(overlayMVPMatrixHandle, 1, false, mvpMatrix, 0)
        GLES20.glUniformMatrix4fv(overlaySTMatrixHandle, 1, false, overlaySTMatrix, 0)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        checkGlError("drawOverlay")

        GLES20.glDisableVertexAttribArray(overlayPositionHandle)
        GLES20.glDisableVertexAttribArray(overlayTextureCoordHandle)
        GLES20.glDisable(GLES20.GL_BLEND)
    }

    fun release() {
        if (overlayTextureId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(overlayTextureId), 0)
            overlayTextureId = 0
        }
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
        if (overlayProgram != 0) {
            GLES20.glDeleteProgram(overlayProgram)
            overlayProgram = 0
        }
    }

    private fun createProgram(vertexSource: String, fragmentSource: String): Int {
        val vertexShader = loadShader(GLES20.GL_VERTEX_SHADER, vertexSource)
        val fragmentShader = loadShader(GLES20.GL_FRAGMENT_SHADER, fragmentSource)
        val prog = GLES20.glCreateProgram()
        GLES20.glAttachShader(prog, vertexShader)
        GLES20.glAttachShader(prog, fragmentShader)
        GLES20.glLinkProgram(prog)
        val linkStatus = IntArray(1)
        GLES20.glGetProgramiv(prog, GLES20.GL_LINK_STATUS, linkStatus, 0)
        if (linkStatus[0] != GLES20.GL_TRUE) {
            val log = GLES20.glGetProgramInfoLog(prog)
            GLES20.glDeleteProgram(prog)
            throw RuntimeException("Could not link program: $log")
        }
        return prog
    }

    private fun loadShader(type: Int, source: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)
        val compiled = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
        if (compiled[0] == 0) {
            val log = GLES20.glGetShaderInfoLog(shader)
            GLES20.glDeleteShader(shader)
            throw RuntimeException("Could not compile shader: $log")
        }
        return shader
    }

    private fun checkGlError(op: String) {
        val error = GLES20.glGetError()
        if (error != GLES20.GL_NO_ERROR) {
            throw RuntimeException("$op: glError 0x${Integer.toHexString(error)}")
        }
    }
}
