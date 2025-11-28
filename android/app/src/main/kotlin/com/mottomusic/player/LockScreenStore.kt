package com.mottomusic.player

/**
 * 锁屏状态数据类
 */
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
    val currentPositionMs: Int = 0
) {
    fun hasLyrics(): Boolean = !currentLine.isNullOrBlank() || !nextLine.isNullOrBlank()
    fun hasMetadata(): Boolean = !title.isNullOrBlank() || !artist.isNullOrBlank() || !coverUrl.isNullOrBlank()
    fun shouldShowLockScreen(): Boolean = enabled && (hasLyrics() || hasMetadata())
}

/**
 * 锁屏状态存储（深度混合方案 - 简化版）
 * 
 * 改动：
 * - 移除观察者模式（observe/remove/notifyChanged）
 * - 移除 updatePlayState() - Activity 直接读 MediaController
 * - 改为纯状态容器，无通知机制
 */
object LockScreenStore {
    @Volatile
    private var state = LockScreenState()

    fun currentState(): LockScreenState = state

    fun setEnabled(enabled: Boolean) {
        state = state.copy(enabled = enabled)
    }

    fun updateMetadata(title: String?, artist: String?, coverUrl: String?) {
        state = state.copy(title = title, artist = artist, coverUrl = coverUrl)
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
