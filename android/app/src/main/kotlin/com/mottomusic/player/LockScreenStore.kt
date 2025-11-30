package com.mottomusic.player

/**
 * 歌词行数据类
 */
data class LyricLine(
    val text: String,
    val startMs: Int,
    val endMs: Int,
    val charTimestamps: List<Map<String, Any>>?
)

/**
 * 锁屏状态数据类
 */
data class LockScreenState(
    val enabled: Boolean = false,
    val title: String? = null,
    val artist: String? = null,
    val currentLine: String? = null,
    val nextLine: String? = null,
    val charTimestamps: List<Map<String, Any>>? = null,
    val currentLineStartMs: Int = 0,
    val currentLineEndMs: Int = 0,
    val currentPositionMs: Int = 0,
    val isPlaying: Boolean = false,
    val allLyrics: List<LyricLine> = emptyList(),
    val currentLineIndex: Int = -1
) {
    fun hasLyrics(): Boolean = !currentLine.isNullOrBlank() || !nextLine.isNullOrBlank() || allLyrics.isNotEmpty()
    fun hasMetadata(): Boolean = !title.isNullOrBlank() || !artist.isNullOrBlank()
    fun shouldShowLockScreen(): Boolean = enabled && (hasLyrics() || hasMetadata())
}

/**
 * 锁屏状态存储（深度混合方案 - 纯状态容器）
 */
object LockScreenStore {
    @Volatile
    private var state = LockScreenState()

    fun currentState(): LockScreenState = state

    fun setEnabled(enabled: Boolean) {
        state = state.copy(enabled = enabled)
    }

    fun updateMetadata(title: String?, artist: String?) {
        state = state.copy(title = title, artist = artist)
    }

    fun updatePlayState(playing: Boolean) {
        state = state.copy(isPlaying = playing)
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
    }

    fun updateAllLyrics(lyrics: List<LyricLine>, currentIndex: Int) {
        state = state.copy(
            allLyrics = lyrics,
            currentLineIndex = currentIndex
        )
    }

    fun updatePosition(positionMs: Int) {
        state = state.copy(currentPositionMs = positionMs)
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
    }
}