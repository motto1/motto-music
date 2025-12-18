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
    val currentSongId: String? = null,  // 新增：当前歌曲ID，用于校验歌词
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
 * 锁屏状态存储（深度混合方案 - 纯状态容器 + 观察者模式）
 */
object LockScreenStore {
    @Volatile
    private var state = LockScreenState()

    // 观察者列表，用于事件驱动更新
    private val listeners = mutableListOf<() -> Unit>()

    fun currentState(): LockScreenState = state

    fun addListener(listener: () -> Unit) {
        synchronized(listeners) {
            listeners.add(listener)
        }
    }

    fun removeListener(listener: () -> Unit) {
        synchronized(listeners) {
            listeners.remove(listener)
        }
    }

    private fun notifyListeners() {
        synchronized(listeners) {
            listeners.forEach {
                try {
                    it()
                } catch (e: Exception) {
                    android.util.Log.e("LockScreenStore", "Listener error: ${e.message}")
                }
            }
        }
    }

    fun setEnabled(enabled: Boolean) {
        state = state.copy(enabled = enabled)
        notifyListeners()
    }

    /**
     * 更新元数据（标题、艺术家、歌曲ID）
     * songId 用于后续歌词校验，确保歌词与歌曲匹配
     */
    fun updateMetadata(title: String?, artist: String?, songId: String? = null) {
        val songChanged = songId != null && songId != state.currentSongId
        state = state.copy(
            title = title,
            artist = artist,
            currentSongId = songId ?: state.currentSongId,  // 保留旧值如果新值为null
            // 歌曲切换时清空歌词相关状态，避免锁屏残留旧歌词
            currentLine = if (songChanged) null else state.currentLine,
            nextLine = if (songChanged) null else state.nextLine,
            charTimestamps = if (songChanged) null else state.charTimestamps,
            currentLineStartMs = if (songChanged) 0 else state.currentLineStartMs,
            currentLineEndMs = if (songChanged) 0 else state.currentLineEndMs,
            allLyrics = if (songChanged) emptyList() else state.allLyrics,
            currentLineIndex = if (songChanged) -1 else state.currentLineIndex
        )
        notifyListeners()
    }

    fun updatePlayState(playing: Boolean) {
        state = state.copy(isPlaying = playing)
        notifyListeners()
    }

    fun updateLyrics(
        currentLine: String?,
        nextLine: String?,
        currentLineStartMs: Int,
        currentLineEndMs: Int,
        charTimestamps: List<Map<String, Any>>?,
        songId: String? = null
    ) {
        val shouldUpdate = songId == null || songId == state.currentSongId || state.currentSongId == null
        if (!shouldUpdate) {
            android.util.Log.d(
                "LockScreenStore",
                "歌词行更新songId不匹配，丢弃: received=$songId, current=${state.currentSongId}"
            )
            return
        }

        state = state.copy(
            currentLine = currentLine,
            nextLine = nextLine,
            currentLineStartMs = currentLineStartMs,
            currentLineEndMs = currentLineEndMs,
            charTimestamps = charTimestamps
        )
        notifyListeners()
    }

    /**
     * 更新完整歌词列表（带songId校验）
     * 只有当songId匹配当前歌曲时才更新，防止快速切歌时歌词错配
     */
    fun updateAllLyrics(lyrics: List<LyricLine>, currentIndex: Int, songId: String? = null) {
        // songId校验：防止歌词错配
        val shouldUpdate = when {
            songId == null -> true  // 兼容旧版本：无songId时直接更新
            songId == state.currentSongId -> true  // songId匹配时更新
            state.currentSongId == null -> true  // 当前无songId时允许更新
            else -> {
                android.util.Log.d("LockScreenStore",
                    "歌词songId不匹配，丢弃: received=$songId, current=${state.currentSongId}")
                false
            }
        }

        if (shouldUpdate) {
            state = state.copy(
                allLyrics = lyrics,
                currentLineIndex = currentIndex
            )
            notifyListeners()
        }
    }

    /**
     * 仅更新歌词行索引（带songId校验）
     */
    fun updateLyricIndex(currentIndex: Int, songId: String? = null) {
        val shouldUpdate = songId == null || songId == state.currentSongId || state.currentSongId == null
        if (shouldUpdate && currentIndex != state.currentLineIndex) {
            state = state.copy(currentLineIndex = currentIndex)
            notifyListeners()
        }
    }

    fun updatePosition(positionMs: Int) {
        state = state.copy(currentPositionMs = positionMs)
        // 位置更新高频，不触发listeners避免性能问题
    }

    fun clear() {
        state = state.copy(
            currentLine = null,
            nextLine = null,
            charTimestamps = null,
            currentLineStartMs = 0,
            currentLineEndMs = 0,
            currentPositionMs = 0,
            allLyrics = emptyList(),
            currentLineIndex = -1
        )
        notifyListeners()
    }
}
