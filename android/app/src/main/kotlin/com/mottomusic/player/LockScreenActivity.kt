package com.mottomusic.player

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.text.SpannableString
import android.text.style.ForegroundColorSpan
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.SeekBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import coil.load
import com.ryanheise.audioservice.AudioService
import java.lang.ref.WeakReference
import kotlin.math.min
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.PlaybackStateCompat

class LockScreenActivity : AppCompatActivity() {

    private lateinit var backgroundView: ImageView
    private lateinit var coverImage: ImageView
    private lateinit var titleView: TextView
    private lateinit var artistView: TextView
    private lateinit var currentLyricView: TextView
    private lateinit var nextLyricView: TextView
    private lateinit var progressContainer: View
    private lateinit var progressBar: SeekBar
    private lateinit var elapsedView: TextView
    private lateinit var durationView: TextView
    private lateinit var prevButton: ImageButton
    private lateinit var playPauseButton: ImageButton
    private lateinit var nextButton: ImageButton
    private lateinit var slideHintView: TextView

    private var latestState: LockScreenState? = null

    private var mediaBrowser: MediaBrowserCompat? = null
    private var mediaController: MediaControllerCompat? = null
    private var playbackState: PlaybackStateCompat? = null
    private var metadataCompat: MediaMetadataCompat? = null
    private val progressHandler = Handler(Looper.getMainLooper())
    private val progressUpdater = object : Runnable {
        override fun run() {
            updateProgress()
            progressHandler.postDelayed(this, 1000L)
        }
    }
    
    // 深度混合方案：定时轮询读取状态
    private val stateUpdateHandler = Handler(Looper.getMainLooper())
    private val stateUpdater = object : Runnable {
        override fun run() {
            updateUi(LockScreenStore.currentState())
            stateUpdateHandler.postDelayed(this, 500L)  // 每500ms更新一次
        }
    }

    // 监听解锁广播，解锁后自动关闭
    private val userPresentReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (Intent.ACTION_USER_PRESENT == intent?.action) {
                finish()
            }
        }
    }

    private var isUserSeeking = false

    private val controllerCallback = object : MediaControllerCompat.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackStateCompat?) {
            updateFromPlaybackState(state)
        }

        override fun onMetadataChanged(metadata: MediaMetadataCompat?) {
            updateFromMetadata(metadata)
        }
    }

    private val mediaBrowserCallback = object : MediaBrowserCompat.ConnectionCallback() {
        override fun onConnected() {
            val browser = mediaBrowser ?: return
            val token = browser.sessionToken ?: return
            try {
                val controller = MediaControllerCompat(this@LockScreenActivity, token)
                MediaControllerCompat.setMediaController(this@LockScreenActivity, controller)
                mediaController = controller
                controller.registerCallback(controllerCallback)
                updateFromMetadata(controller.metadata)
                updateFromPlaybackState(controller.playbackState)
            } catch (_: Exception) {
                // Ignore connection failures, activity will still show lyrics UI.
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        companionRef = WeakReference(this)
        
        // 注册解锁广播
        registerReceiver(userPresentReceiver, IntentFilter(Intent.ACTION_USER_PRESENT))
        
        setContentView(R.layout.activity_lock_screen)
        configureWindow()
        bindViews()
        setupControls()
        mediaBrowser = MediaBrowserCompat(
            this,
            ComponentName(this, AudioService::class.java),
            mediaBrowserCallback,
            null
        )
    }

    override fun onStart() {
        super.onStart()
        // 深度混合方案：直接读取状态，无需 observe
        updateUi(LockScreenStore.currentState())
        // 启动定时轮询
        stateUpdateHandler.post(stateUpdater)
        mediaBrowser?.connect()
    }

    override fun onStop() {
        super.onStop()
        // 停止定时轮询
        stateUpdateHandler.removeCallbacks(stateUpdater)
        progressHandler.removeCallbacks(progressUpdater)
        mediaController?.unregisterCallback(controllerCallback)
        MediaControllerCompat.setMediaController(this, null)
        mediaController = null
        if (mediaBrowser?.isConnected == true) {
            mediaBrowser?.disconnect()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        
        // 注销广播
        try {
            unregisterReceiver(userPresentReceiver)
        } catch (e: Exception) {
            // ignore
        }
        
        if (companionRef.get() == this) {
            companionRef = WeakReference(null)
        }
    }

    private fun configureWindow() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // 深度混合方案：参考 Metro-dev，仅 showWhenLocked，不 turnScreenOn
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            // 移除 setTurnScreenOn(true) - 避免误唤醒，节省电量
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            // 移除 FLAG_TURN_SCREEN_ON
        }
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.BLACK
    }

    private fun bindViews() {
        backgroundView = findViewById(R.id.lockscreen_cover_background)
        coverImage = findViewById(R.id.lockscreen_cover)
        titleView = findViewById(R.id.lockscreen_title)
        artistView = findViewById(R.id.lockscreen_artist)
        currentLyricView = findViewById(R.id.lockscreen_current_lyric)
        nextLyricView = findViewById(R.id.lockscreen_next_lyric)
        progressContainer = findViewById(R.id.lockscreen_progress_container)
        progressBar = findViewById(R.id.lockscreen_progress)
        elapsedView = findViewById(R.id.lockscreen_elapsed)
        durationView = findViewById(R.id.lockscreen_duration)
        prevButton = findViewById(R.id.lockscreen_prev)
        playPauseButton = findViewById(R.id.lockscreen_play_pause)
        nextButton = findViewById(R.id.lockscreen_next)
        slideHintView = findViewById(R.id.lockscreen_slide_hint)
    }

    private fun setupControls() {
        prevButton.setOnClickListener { mediaController?.transportControls?.skipToPrevious() }
        nextButton.setOnClickListener { mediaController?.transportControls?.skipToNext() }
        playPauseButton.setOnClickListener { togglePlayPause() }
        progressBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser) {
                    elapsedView.text = formatDuration(progress.toLong())
                }
            }

            override fun onStartTrackingTouch(seekBar: SeekBar?) {
                isUserSeeking = true
                progressHandler.removeCallbacks(progressUpdater)
            }

            override fun onStopTrackingTouch(seekBar: SeekBar?) {
                val target = seekBar?.progress?.toLong() ?: 0L
                mediaController?.transportControls?.seekTo(target)
                isUserSeeking = false
                updateProgress()
            }
        })
    }

    private fun togglePlayPause() {
        val state = playbackState?.state ?: PlaybackStateCompat.STATE_NONE
        if (state == PlaybackStateCompat.STATE_PLAYING ||
            state == PlaybackStateCompat.STATE_BUFFERING
        ) {
            mediaController?.transportControls?.pause()
        } else {
            mediaController?.transportControls?.play()
        }
    }

    private fun updateFromPlaybackState(state: PlaybackStateCompat?) {
        playbackState = state
        val playing = state?.state == PlaybackStateCompat.STATE_PLAYING ||
            state?.state == PlaybackStateCompat.STATE_BUFFERING
        playPauseButton.setImageResource(
            if (playing) R.drawable.ic_lock_pause else R.drawable.ic_lock_play
        )
        updateProgress()
    }

    private fun updateFromMetadata(metadata: MediaMetadataCompat?) {
        metadataCompat = metadata
        updateUi(latestState ?: LockScreenStore.currentState())
        updateProgress()
    }

    private fun updateUi(state: LockScreenState) {
        latestState = state
        if (!state.shouldShowLockScreen()) {
            finish()
            return
        }
        val resolvedTitle = when {
            !state.title.isNullOrBlank() -> state.title
            !metadataTitle().isNullOrBlank() -> metadataTitle()
            else -> getString(R.string.lockscreen_default_title)
        }
        val resolvedArtist = when {
            !state.artist.isNullOrBlank() -> state.artist
            !metadataArtist().isNullOrBlank() -> metadataArtist()
            !metadataAlbum().isNullOrBlank() -> metadataAlbum()
            else -> getString(R.string.lockscreen_default_artist)
        }
        titleView.text = resolvedTitle
        artistView.text = resolvedArtist
        updateCover(state)
        updateLyricViews(state)
    }

    private fun updateCover(state: LockScreenState?) {
        val placeholder = R.drawable.lockscreen_cover_placeholder
        val coverUrl = state?.coverUrl
        val description = metadataCompat?.description
        when {
            !coverUrl.isNullOrBlank() -> {
                loadCoverImage(coverUrl)
                loadBackgroundImage(coverUrl)
            }
            description?.iconBitmap != null -> {
                coverImage.setImageBitmap(description.iconBitmap)
                backgroundView.setImageBitmap(description.iconBitmap)
            }
            description?.iconUri != null -> {
                val uri = description.iconUri.toString()
                loadCoverImage(uri)
                loadBackgroundImage(uri)
            }
            else -> {
                coverImage.setImageResource(placeholder)
                backgroundView.setImageResource(placeholder)
            }
        }
    }

    private fun loadCoverImage(data: Any?) {
        val placeholder = R.drawable.lockscreen_cover_placeholder
        coverImage.load(data) {
            crossfade(true)
            placeholder(placeholder)
            error(placeholder)
        }
    }

    private fun loadBackgroundImage(data: Any?) {
        val placeholder = R.drawable.lockscreen_cover_placeholder
        backgroundView.load(data) {
            crossfade(true)
            placeholder(placeholder)
            error(placeholder)
        }
    }

    private fun updateLyricViews(state: LockScreenState) {
        val currentLine = state.currentLine
        if (currentLine.isNullOrBlank()) {
            currentLyricView.text = getString(R.string.lockscreen_waiting_for_lyrics)
        } else {
            currentLyricView.text = buildHighlightedSpannable(
                currentLine,
                state.charTimestamps,
                state.currentPositionMs
            )
        }

        if (state.nextLine.isNullOrBlank()) {
            nextLyricView.visibility = View.GONE
        } else {
            nextLyricView.visibility = View.VISIBLE
            nextLyricView.text = state.nextLine
        }
    }

    private fun metadataTitle(): String? =
        metadataCompat?.getString(MediaMetadataCompat.METADATA_KEY_TITLE)

    private fun metadataArtist(): String? =
        metadataCompat?.getString(MediaMetadataCompat.METADATA_KEY_ARTIST)

    private fun metadataAlbum(): String? =
        metadataCompat?.getString(MediaMetadataCompat.METADATA_KEY_ALBUM)

    private fun updateProgress() {
        val duration = metadataCompat?.getLong(MediaMetadataCompat.METADATA_KEY_DURATION) ?: 0L
        if (duration <= 0L) {
            progressContainer.visibility = View.GONE
            progressHandler.removeCallbacks(progressUpdater)
            return
        }
        progressContainer.visibility = View.VISIBLE
        val position = calculateCurrentPosition(duration)
        if (!isUserSeeking) {
            val clampedDuration = duration.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
            progressBar.max = clampedDuration
            val progressValue = position
                .coerceIn(0, duration)
                .coerceAtMost(Int.MAX_VALUE.toLong())
                .toInt()
            progressBar.progress = progressValue
        }
        elapsedView.text = formatDuration(position)
        durationView.text = formatDuration(duration)
        scheduleProgressUpdates()
    }

    private fun scheduleProgressUpdates() {
        progressHandler.removeCallbacks(progressUpdater)
        val duration = metadataCompat?.getLong(MediaMetadataCompat.METADATA_KEY_DURATION) ?: 0L
        if (duration > 0 &&
            playbackState?.state == PlaybackStateCompat.STATE_PLAYING
        ) {
            progressHandler.postDelayed(progressUpdater, 1000L)
        }
    }

    private fun calculateCurrentPosition(duration: Long): Long {
        val state = playbackState ?: return 0L
        var position = state.position
        if (state.state == PlaybackStateCompat.STATE_PLAYING) {
            val timeDelta = SystemClock.elapsedRealtime() - state.lastPositionUpdateTime
            position += (timeDelta * state.playbackSpeed).toLong()
        }
        return position.coerceIn(0, duration)
    }

    private fun formatDuration(ms: Long): String {
        val totalSeconds = (ms / 1000).coerceAtLeast(0)
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return String.format("%02d:%02d", minutes, seconds)
    }

    private fun buildHighlightedSpannable(
        text: String,
        timestamps: List<Map<String, Any>>?,
        positionMs: Int
    ): SpannableString {
        if (text.isEmpty()) return SpannableString("")

        val spannable = SpannableString(text)
        spannable.setSpan(
            ForegroundColorSpan(Color.parseColor("#66FFFFFF")),
            0,
            text.length,
            SpannableString.SPAN_EXCLUSIVE_EXCLUSIVE
        )

        if (timestamps.isNullOrEmpty()) {
            return spannable
        }

        var highlightEnd = 0
        timestamps.forEachIndexed { index, map ->
            val start = (map["startMs"] as? Number)?.toInt() ?: return@forEachIndexed
            if (positionMs >= start) {
                highlightEnd = index + 1
            }
        }

        if (highlightEnd > 0) {
            val clamped = min(highlightEnd, text.length)
            for (i in 0 until clamped) {
                spannable.setSpan(
                    ForegroundColorSpan(Color.WHITE),
                    i,
                    i + 1,
                    SpannableString.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
        }

        return spannable
    }

    companion object {
        private var companionRef: WeakReference<LockScreenActivity?> = WeakReference(null)

        fun start(context: Context) {
            if (isActive()) return
            val intent = android.content.Intent(context, LockScreenActivity::class.java).apply {
                addFlags(
                    android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
                        android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            }
            context.startActivity(intent)
        }

        fun dismissActive() {
            companionRef.get()?.finish()
            companionRef = WeakReference(null)
        }

        fun isActive(): Boolean = companionRef.get() != null
    }
}
