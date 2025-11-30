package com.mottomusic.player

import android.app.Application
import androidx.preference.PreferenceManager

/**
 * 锁屏控制器（深度混合方案 - 简化版）
 * 
 * 改动：
 * - 移除 LockScreenService 启动/停止逻辑
 * - 移除 LockScreenStore 观察者监听
 * - 仅保留 tryShowLockScreen() 作为启动入口
 * - 配置管理简化
 */
object LockScreenController {
    private const val PREF_LOCKSCREEN_ENABLED = "lockscreen_lyrics_enabled"
    private var application: Application? = null
    private var enabled: Boolean = false

    fun initialize(app: Application) {
        application = app
        val prefs = PreferenceManager.getDefaultSharedPreferences(app)
        enabled = prefs.getBoolean(PREF_LOCKSCREEN_ENABLED, false)
        LockScreenStore.setEnabled(enabled)
    }

    fun setLockScreenEnabled(value: Boolean) {
        enabled = value
        LockScreenStore.setEnabled(value)
        val app = application ?: return
        PreferenceManager.getDefaultSharedPreferences(app)
            .edit()
            .putBoolean(PREF_LOCKSCREEN_ENABLED, value)
            .apply()
        
        if (!value) {
            LockScreenActivity.dismissActive()
        }
    }

    fun updateMetadata(title: String?, artist: String?) {
        android.util.Log.d("LockScreenController", "========== updateMetadata ==========")
        android.util.Log.d("LockScreenController", "title: $title")
        android.util.Log.d("LockScreenController", "artist: $artist")

        LockScreenStore.updateMetadata(title, artist)
    }

    fun updatePlayState(playing: Boolean) {
        LockScreenStore.updatePlayState(playing)
    }

    fun updateLyrics(
        currentLine: String?,
        nextLine: String?,
        currentLineStartMs: Int,
        currentLineEndMs: Int,
        charTimestamps: List<Map<String, Any>>?
    ) {
        LockScreenStore.updateLyrics(
            currentLine,
            nextLine,
            currentLineStartMs,
            currentLineEndMs,
            charTimestamps
        )
    }

    fun updatePosition(positionMs: Int) {
        LockScreenStore.updatePosition(positionMs)
    }

    fun updateAllLyrics(lyrics: List<LyricLine>, currentIndex: Int) {
        LockScreenStore.updateAllLyrics(lyrics, currentIndex)
    }

    fun clearLyrics() {
        LockScreenStore.clear()
        LockScreenActivity.dismissActive()
    }

    /**
     * 尝试显示锁屏界面（深度混合方案核心方法）
     * 由 Flutter 层通过 MethodChannel 调用
     */
    fun tryShowLockScreen() {
        val state = LockScreenStore.currentState()
        // 仅在启用且正在播放时显示
        if (!state.enabled || !state.isPlaying) return
        
        val app = application ?: return
        // 直接启动 Activity，依赖 showWhenLocked 属性自动显示
        LockScreenActivity.start(app)
    }
}
