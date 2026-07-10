package com.overscore.viewmodel

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class PlayerViewModel : ViewModel() {

    private var _player: ExoPlayer? = null
    val player: ExoPlayer? get() = _player

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _currentPositionMs = MutableStateFlow(0L)
    val currentPositionMs: StateFlow<Long> = _currentPositionMs.asStateFlow()

    private val _durationMs = MutableStateFlow(0L)
    val durationMs: StateFlow<Long> = _durationMs.asStateFlow()

    private val _playbackSpeed = MutableStateFlow(1.0f)
    val playbackSpeed: StateFlow<Float> = _playbackSpeed.asStateFlow()

    fun initialize(context: Context, videoUris: List<String>) {
        if (_player != null) return
        val exoPlayer = ExoPlayer.Builder(context).build()
        videoUris.forEach { uriString ->
            val mediaItem = MediaItem.fromUri(Uri.parse(uriString))
            exoPlayer.addMediaItem(mediaItem)
        }
        exoPlayer.prepare()

        exoPlayer.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                _isPlaying.value = isPlaying
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_READY) {
                    _durationMs.value = exoPlayer.duration.coerceAtLeast(0)
                }
            }
        })

        _player = exoPlayer
    }

    fun updatePosition() {
        _player?.let {
            _currentPositionMs.value = it.currentPosition.coerceAtLeast(0)
            if (_durationMs.value <= 0 && it.duration > 0) {
                _durationMs.value = it.duration
            }
        }
    }

    fun play() {
        _player?.play()
    }

    fun pause() {
        _player?.pause()
    }

    fun togglePlayPause() {
        val p = _player ?: return
        if (p.isPlaying) p.pause() else p.play()
    }

    fun seekTo(positionMs: Long) {
        _player?.seekTo(positionMs)
        _currentPositionMs.value = positionMs
    }

    fun skip(deltaMs: Long) {
        val p = _player ?: return
        val newPos = (p.currentPosition + deltaMs).coerceIn(0, p.duration.coerceAtLeast(0))
        seekTo(newPos)
    }

    fun setPlaybackSpeed(speed: Float) {
        _playbackSpeed.value = speed
        _player?.setPlaybackSpeed(speed)
    }

    override fun onCleared() {
        super.onCleared()
        _player?.release()
        _player = null
    }
}
