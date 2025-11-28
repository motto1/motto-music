package com.mottomusic.player

import android.app.Application
import android.content.Intent
import androidx.core.content.ContextCompat
import androidx.preference.PreferenceManager

object LockScreenController {
    private const val PREF_LOCKSCREEN_ENABLED = "lockscreen_lyrics_enabled"
    private var application: Application? = null
    private val storeListener: LockScreenListener = { state ->
        if (!state.shouldShowLockScreen()) {
            LockScreenActivity.dismissActive()
        }
    }

    fun initialize(app: Application) {
        application = app
        LockScreenStore.observe(storeListener)
        val prefs = PreferenceManager.getDefaultSharedPreferences(app)
        val enabled = prefs.getBoolean(PREF_LOCKSCREEN_ENABLED, false)
        LockScreenStore.setEnabled(enabled)
        if (enabled) {
            startService()
        }
    }

    fun setLockScreenEnabled(enabled: Boolean) {
        LockScreenStore.setEnabled(enabled)
        saveEnabled(enabled)
        if (enabled) {
            startService()
            tryShowLockScreen()
        } else {
            stopService()
        }
    }

    fun updateMetadata(title: String?, artist: String?, coverUrl: String?) {
        LockScreenStore.updateMetadata(title, artist, coverUrl)
        tryShowLockScreen()
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
        tryShowLockScreen()
    }

    fun updatePosition(positionMs: Int) {
        LockScreenStore.updatePosition(positionMs)
    }

    fun updatePlayState(isPlaying: Boolean) {
        LockScreenStore.updatePlayState(isPlaying)
        tryShowLockScreen()
    }

    fun clearLyrics() {
        LockScreenStore.clear()
        LockScreenActivity.dismissActive()
    }

    fun tryShowLockScreen() {
        val app = application ?: return
        LockScreenService.requestEvaluate(app)
    }

    private fun saveEnabled(enabled: Boolean) {
        val app = application ?: return
        PreferenceManager.getDefaultSharedPreferences(app)
            .edit()
            .putBoolean(PREF_LOCKSCREEN_ENABLED, enabled)
            .apply()
    }

    private fun startService() {
        val app = application ?: return
        val intent = Intent(app, LockScreenService::class.java)
        ContextCompat.startForegroundService(app, intent)
    }

    private fun stopService() {
        val app = application ?: return
        LockScreenActivity.dismissActive()
        app.stopService(Intent(app, LockScreenService::class.java))
    }
}
