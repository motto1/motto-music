package com.mottomusic.player

import java.lang.ref.WeakReference
import java.util.concurrent.CopyOnWriteArrayList

data class LockScreenState(
    val enabled: Boolean = false,
    val title: String? = null,
    val artist: String? = null,
    val coverUrl: String? = null,
    val currentLine: String? = null,
    val nextLine: String? = null,
    val charTimestamps: List<Map<String, Any>>? = null,
    val currentLineStartMs: Int = 0,
    val currentLineEndMs: Int = 0,
    val currentPositionMs: Int = 0,
    val isPlaying: Boolean = false
) {
    fun hasLyrics(): Boolean = !currentLine.isNullOrBlank() || !nextLine.isNullOrBlank()
    fun hasMetadata(): Boolean = !title.isNullOrBlank() || !artist.isNullOrBlank() || !coverUrl.isNullOrBlank()
    fun shouldShowLockScreen(): Boolean = enabled && isPlaying && (hasLyrics() || hasMetadata())
}

typealias LockScreenListener = (LockScreenState) -> Unit

object LockScreenStore {
    @Volatile
    private var state = LockScreenState()
    private val listeners = CopyOnWriteArrayList<WeakReference<LockScreenListener>>()

    fun currentState(): LockScreenState = state

    fun observe(listener: LockScreenListener) {
        cleanupListeners()
        listeners.add(WeakReference(listener))
        listener.invoke(state)
    }

    fun remove(listener: LockScreenListener) {
        listeners.removeAll { it.get() == null || it.get() == listener }
    }

    private fun notifyChanged() {
        cleanupListeners()
        listeners.forEach { ref ->
            ref.get()?.invoke(state)
        }
    }

    private fun cleanupListeners() {
        listeners.removeAll { it.get() == null }
    }

    fun setEnabled(enabled: Boolean) {
        state = state.copy(enabled = enabled)
        notifyChanged()
    }

    fun updateMetadata(title: String?, artist: String?, coverUrl: String?) {
        state = state.copy(title = title, artist = artist, coverUrl = coverUrl)
        notifyChanged()
    }

    fun updateLyrics(
        currentLine: String?,
        nextLine: String?,
        currentLineStartMs: Int,
        currentLineEndMs: Int,
        charTimestamps: List<Map<String, Any>>?
    ) {
        state = state.copy(
            currentLine = currentLine,
            nextLine = nextLine,
            currentLineStartMs = currentLineStartMs,
            currentLineEndMs = currentLineEndMs,
            charTimestamps = charTimestamps
        )
        notifyChanged()
    }

    fun updatePosition(positionMs: Int) {
        state = state.copy(currentPositionMs = positionMs)
        notifyChanged()
    }

    fun updatePlayState(isPlaying: Boolean) {
        state = state.copy(isPlaying = isPlaying)
        notifyChanged()
    }

    fun clear() {
        state = state.copy(
            currentLine = null,
            nextLine = null,
            charTimestamps = null,
            currentLineStartMs = 0,
            currentLineEndMs = 0,
            currentPositionMs = 0
        )
        notifyChanged()
    }
}
