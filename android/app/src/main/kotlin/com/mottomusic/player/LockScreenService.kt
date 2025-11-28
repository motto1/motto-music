package com.mottomusic.player

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.PlaybackStateCompat
import com.ryanheise.audioservice.AudioService

class LockScreenService : Service() {

    private val storeListener: LockScreenListener = {
        evaluateLockScreen()
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_ON -> evaluateLockScreen(force = true)
                Intent.ACTION_SCREEN_OFF -> evaluateLockScreen()
                Intent.ACTION_USER_PRESENT -> LockScreenActivity.dismissActive()
            }
        }
    }

    private var mediaBrowser: MediaBrowserCompat? = null
    private var mediaController: MediaControllerCompat? = null
    private var alertVisible = false

    private val controllerCallback = object : MediaControllerCompat.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackStateCompat?) {
            val playing = state?.state == PlaybackStateCompat.STATE_PLAYING ||
                state?.state == PlaybackStateCompat.STATE_BUFFERING
            LockScreenStore.updatePlayState(playing)
            evaluateLockScreen()
        }

        override fun onMetadataChanged(metadata: MediaMetadataCompat?) {
            val currentState = LockScreenStore.currentState()
            if ((currentState.title.isNullOrBlank() && currentState.artist.isNullOrBlank()) && metadata != null) {
                val title = metadata.getString(MediaMetadataCompat.METADATA_KEY_TITLE)
                val artist = metadata.getString(MediaMetadataCompat.METADATA_KEY_ARTIST)
                val albumArt = metadata.getString(MediaMetadataCompat.METADATA_KEY_ALBUM_ART_URI)
                LockScreenStore.updateMetadata(title, artist, albumArt)
            }
        }
    }

    private val browserCallback = object : MediaBrowserCompat.ConnectionCallback() {
        override fun onConnected() {
            val browser = mediaBrowser ?: return
            val token = browser.sessionToken ?: return
            try {
                val controller = MediaControllerCompat(this@LockScreenService, token)
                mediaController = controller
                controller.registerCallback(controllerCallback)
                controllerCallback.onPlaybackStateChanged(controller.playbackState)
                controllerCallback.onMetadataChanged(controller.metadata)
            } catch (_: Exception) {
                // Ignore
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        LockScreenStore.observe(storeListener)
        registerScreenReceiver()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        connectToMediaSession()
        evaluateLockScreen()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val force = intent?.action == ACTION_EVALUATE
        evaluateLockScreen(force = force)
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        LockScreenStore.remove(storeListener)
        runCatching { unregisterReceiver(screenReceiver) }
        mediaController?.unregisterCallback(controllerCallback)
        mediaBrowser?.disconnect()
        dismissLockScreenAlert()
        stopForeground(true)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun connectToMediaSession() {
        if (mediaBrowser != null) return
        mediaBrowser = MediaBrowserCompat(
            this,
            ComponentName(this, AudioService::class.java),
            browserCallback,
            null
        ).apply { connect() }
    }

    private fun evaluateLockScreen(force: Boolean = false) {
        val state = LockScreenStore.currentState()
        if (!state.enabled) {
            dismissLockScreenAlert()
            stopSelfSafely()
            return
        }
        val locked = isDeviceLocked()
        if (locked && state.shouldShowLockScreen()) {
            showLockScreenAlert()
        } else {
            dismissLockScreenAlert()
            if (!locked && !force) {
                LockScreenActivity.dismissActive()
            }
        }
    }

    private fun isDeviceLocked(): Boolean {
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        return keyguard?.isKeyguardLocked ?: false
    }

    private fun registerScreenReceiver() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        ContextCompat.registerReceiver(
            this,
            screenReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "锁屏歌词",
            NotificationManager.IMPORTANCE_MIN
        ).apply {
            description = "锁屏歌词服务"
            setSound(null, null)
            enableLights(false)
            enableVibration(false)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
        val alertChannel = NotificationChannel(
            CHANNEL_ALERT_ID,
            "锁屏歌词唤醒",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "用于在锁屏时显示歌词"
            enableVibration(false)
            setSound(null, null)
        }
        manager?.createNotificationChannel(alertChannel)
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification_favorite)
            .setContentTitle(getString(R.string.lockscreen_service_title))
            .setContentText(getString(R.string.lockscreen_service_text))
            .setOngoing(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun stopSelfSafely() {
        runCatching { stopForeground(true) }
        stopSelf()
    }

    private fun showLockScreenAlert() {
        if (LockScreenActivity.isActive()) {
            dismissLockScreenAlert()
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, LockScreenActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ALERT_ID)
            .setSmallIcon(R.drawable.ic_notification_favorite)
            .setContentTitle(getString(R.string.lockscreen_alert_title))
            .setContentText(getString(R.string.lockscreen_alert_text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(pendingIntent, true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .build()
        manager.notify(NOTIFICATION_ALERT_ID, notification)
        alertVisible = true
    }

    private fun dismissLockScreenAlert() {
        if (!alertVisible) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.cancel(NOTIFICATION_ALERT_ID)
        alertVisible = false
    }

    companion object {
        private const val ACTION_EVALUATE = "com.mottomusic.player.lock.EVALUATE"
        private const val CHANNEL_ID = "lockscreen_lyrics_service"
        private const val NOTIFICATION_ID = 2048
        private const val CHANNEL_ALERT_ID = "lockscreen_lyrics_alert"
        private const val NOTIFICATION_ALERT_ID = 2049

        fun requestEvaluate(context: Context) {
            val intent = Intent(context, LockScreenService::class.java).apply {
                action = ACTION_EVALUATE
            }
            ContextCompat.startForegroundService(context, intent)
        }
    }
}
