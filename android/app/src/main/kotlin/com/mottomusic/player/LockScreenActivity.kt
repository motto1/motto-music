package com.mottomusic.player

import android.animation.ObjectAnimator
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.SeekBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.palette.graphics.Palette
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import coil.Coil
import coil.ImageLoader
import coil.load
import coil.request.SuccessResult
import com.ryanheise.audioservice.AudioService
import okhttp3.OkHttpClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.lang.ref.WeakReference
import kotlin.math.min
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.PlaybackStateCompat

class LockScreenActivity : AppCompatActivity() {

    private lateinit var backgroundView: ImageView
    private lateinit var coverImage: ImageView
    private lateinit var lyricsRecyclerView: RecyclerView
    private lateinit var lyricsAdapter: SimpleLyricsAdapter
    private lateinit var titleView: TextView
    private lateinit var artistView: TextView
    private lateinit var progressContainer: View
    private lateinit var progressBar: SeekBar
    private lateinit var elapsedView: TextView
    private lateinit var durationView: TextView
    private lateinit var prevButton: ImageButton
    private lateinit var playPauseButton: ImageButton
    private lateinit var nextButton: ImageButton
    private lateinit var slideHintView: TextView

    private var isShowingLyrics = false
    private var isAnimating = false
    private var latestState: LockScreenState? = null
    private var currentHighlightEnd: Int = 0
    private var lastLineIndex: Int = -1

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
    
    // 统一定时器：50ms更新状态和歌词
    private val stateUpdateHandler = Handler(Looper.getMainLooper())
    private val stateUpdater = object : Runnable {
        override fun run() {
            val state = LockScreenStore.currentState()
            updateUi(state)
            updateLyrics(state)
            stateUpdateHandler.postDelayed(this, 50L)
        }
    }

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
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        companionRef = WeakReference(this)
        
        registerReceiver(userPresentReceiver, IntentFilter(Intent.ACTION_USER_PRESENT))
        
        setContentView(R.layout.activity_lock_screen)
        configureWindow()
        bindViews()
        setupControls()
        setupCoilImageLoader()
        
        backgroundView.setImageDrawable(getDefaultGradient())
        mediaBrowser = MediaBrowserCompat(
            this,
            ComponentName(this, AudioService::class.java),
            mediaBrowserCallback,
            null
        )
    }
    
    private fun setupCoilImageLoader() {
        val okHttpClient = okhttp3.OkHttpClient.Builder()
            .connectTimeout(10, java.util.concurrent.TimeUnit.SECONDS)
            .readTimeout(15, java.util.concurrent.TimeUnit.SECONDS)
            .addInterceptor { chain ->
                val request = chain.request()
                val url = request.url.toString()

                android.util.Log.d("LockScreenActivity", "Loading image: $url")

                // 为Bilibili CDN添加必要的请求头
                val newRequest = request.newBuilder()
                    .addHeader("Referer", "https://www.bilibili.com")
                    .addHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
                    .addHeader("Accept", "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8")
                    .build()

                try {
                    val response = chain.proceed(newRequest)
                    android.util.Log.d("LockScreenActivity", "Image response: ${response.code}")
                    response
                } catch (e: Exception) {
                    android.util.Log.e("LockScreenActivity", "Image load error: ${e.message}")
                    throw e
                }
            }
            .build()

        val imageLoader = coil.ImageLoader.Builder(this)
            .okHttpClient(okHttpClient)
            .crossfade(true)
            .respectCacheHeaders(false)  // 忽略缓存头，强制缓存
            .build()

        coil.Coil.setImageLoader(imageLoader)
        android.util.Log.d("LockScreenActivity", "Coil ImageLoader configured with Bilibili headers")
    }

    override fun onStart() {
        super.onStart()
        android.util.Log.d("LockScreenActivity", "onStart - isConnected: ${mediaBrowser?.isConnected}")
        
        updateUi(LockScreenStore.currentState())
        stateUpdateHandler.post(stateUpdater)
        
        // 启动进度条更新
        updateProgress()
        
        if (mediaBrowser?.isConnected == false) {
            try {
                mediaBrowser?.connect()
                android.util.Log.d("LockScreenActivity", "MediaBrowser connecting...")
            } catch (e: Exception) {
                android.util.Log.e("LockScreenActivity", "MediaBrowser connect failed", e)
            }
        } else {
            android.util.Log.d("LockScreenActivity", "MediaBrowser already connected, skipping connect()")
        }
    }

    override fun onStop() {
        super.onStop()
        android.util.Log.d("LockScreenActivity", "onStop - finishing: $isFinishing")
        
        stateUpdateHandler.removeCallbacks(stateUpdater)
        progressHandler.removeCallbacks(progressUpdater)
        
        if (isFinishing) {
            mediaController?.unregisterCallback(controllerCallback)
            MediaControllerCompat.setMediaController(this, null)
            mediaController = null
            
            try {
                if (mediaBrowser?.isConnected == true) {
                    mediaBrowser?.disconnect()
                    android.util.Log.d("LockScreenActivity", "MediaBrowser disconnected")
                }
            } catch (e: Exception) {
                android.util.Log.e("LockScreenActivity", "MediaBrowser disconnect failed", e)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        android.util.Log.d("LockScreenActivity", "onDestroy")
        
        stateUpdateHandler.removeCallbacks(stateUpdater)
        progressHandler.removeCallbacks(progressUpdater)
        
        try {
            mediaController?.unregisterCallback(controllerCallback)
            MediaControllerCompat.setMediaController(this, null)
            mediaController = null
        } catch (e: Exception) {
            android.util.Log.e("LockScreenActivity", "MediaController cleanup failed", e)
        }
        
        try {
            if (mediaBrowser?.isConnected == true) {
                mediaBrowser?.disconnect()
            }
        } catch (e: Exception) {
            android.util.Log.e("LockScreenActivity", "MediaBrowser disconnect failed", e)
        }
        
        try {
            unregisterReceiver(userPresentReceiver)
        } catch (e: Exception) {
        }
        
        if (companionRef.get() == this) {
            companionRef = WeakReference(null)
        }
    }

    private fun configureWindow() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        }
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.BLACK
    }

    private fun bindViews() {
        backgroundView = findViewById(R.id.lockscreen_cover_background)
        coverImage = findViewById(R.id.lockscreen_cover)
        lyricsRecyclerView = findViewById(R.id.lockscreen_lyrics_recycler)
        titleView = findViewById(R.id.lockscreen_title)
        artistView = findViewById(R.id.lockscreen_artist)
        progressContainer = findViewById(R.id.lockscreen_progress_container)
        progressBar = findViewById(R.id.lockscreen_progress)
        elapsedView = findViewById(R.id.lockscreen_elapsed)
        durationView = findViewById(R.id.lockscreen_duration)
        prevButton = findViewById(R.id.lockscreen_prev)
        playPauseButton = findViewById(R.id.lockscreen_play_pause)
        nextButton = findViewById(R.id.lockscreen_next)
        slideHintView = findViewById(R.id.lockscreen_slide_hint)

        // 初始化RecyclerView
        lyricsAdapter = SimpleLyricsAdapter(
            onItemClick = {
                android.util.Log.d("LockScreenActivity", "Lyric item clicked!")
                toggleCoverLyrics()
            }
        )
        lyricsRecyclerView.apply {
            layoutManager = LinearLayoutManager(this@LockScreenActivity)
            adapter = lyricsAdapter
            setHasFixedSize(true)
            // 禁用item动画，避免闪烁
            (itemAnimator as? androidx.recyclerview.widget.SimpleItemAnimator)?.supportsChangeAnimations = false
        }

        coverImage.setOnClickListener {
            android.util.Log.d("LockScreenActivity", "Cover clicked!")
            toggleCoverLyrics()
        }
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
    }

    private fun updateLyrics(state: LockScreenState) {
        if (!isShowingLyrics || state.allLyrics.isEmpty()) return

        val currentIndex = state.currentLineIndex
        if (currentIndex < 0 || currentIndex >= state.allLyrics.size) return

        // 首次加载歌词列表
        if (lyricsAdapter.itemCount == 0) {
            lyricsAdapter.updateLyrics(state.allLyrics)
        }

        // 检测歌词行切换
        if (currentIndex != lastLineIndex) {
            lastLineIndex = currentIndex
            currentHighlightEnd = 0
            
            // 平滑滚动到当前行
            val layoutManager = lyricsRecyclerView.layoutManager as? LinearLayoutManager
            if (layoutManager != null) {
                val smoothScroller = object : androidx.recyclerview.widget.LinearSmoothScroller(lyricsRecyclerView.context) {
                    override fun getVerticalSnapPreference(): Int = SNAP_TO_START
                    override fun calculateTimeForScrolling(dx: Int): Int = 800
                }
                smoothScroller.targetPosition = currentIndex
                layoutManager.startSmoothScroll(smoothScroller)
            }
        }

        // 更新逐字高亮
        val currentLine = state.allLyrics[currentIndex]
        val timestamps = currentLine.charTimestamps
        if (timestamps != null) {
            val position = getCurrentPlaybackPosition().toInt()
            var newHighlightEnd = 0
            
            timestamps.forEachIndexed { index, map ->
                val start = (map["startMs"] as? Number)?.toInt() ?: return@forEachIndexed
                if (position >= start) {
                    newHighlightEnd = index + 1
                }
            }

            // 单向递增：只在增加时更新
            if (newHighlightEnd > currentHighlightEnd) {
                currentHighlightEnd = newHighlightEnd
                val spannable = buildHighlightedSpannable(currentLine.text, currentHighlightEnd)
                lyricsAdapter.updateCurrentLine(currentIndex, spannable)
            }
        } else {
            // 无逐字高亮，直接更新当前行
            lyricsAdapter.updateCurrentLine(currentIndex, null)
        }
    }

    private fun buildHighlightedSpannable(text: String, highlightEnd: Int): SpannableString {
        if (text.isEmpty()) return SpannableString("")

        val spannable = SpannableString(text)

        if (highlightEnd > 0) {
            val clamped = min(highlightEnd, text.length)
            spannable.setSpan(
                ForegroundColorSpan(Color.WHITE),
                0,
                clamped,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }

        if (highlightEnd < text.length) {
            spannable.setSpan(
                ForegroundColorSpan(Color.parseColor("#80FFFFFF")),
                highlightEnd,
                text.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }

        return spannable
    }

    private fun updateCover(state: LockScreenState?) {
        val placeholder = R.drawable.lockscreen_cover_placeholder
        val description = metadataCompat?.description

        android.util.Log.d("LockScreenActivity", "========== updateCover ==========")
        android.util.Log.d("LockScreenActivity", "metadata.iconBitmap: ${description?.iconBitmap != null}")
        android.util.Log.d("LockScreenActivity", "metadata.iconUri: ${description?.iconUri}")
        android.util.Log.d("LockScreenActivity", "metadata.title: ${description?.title}")

        when {
            description?.iconBitmap != null -> {
                android.util.Log.d("LockScreenActivity", "✅ Loading cover from metadata.iconBitmap")
                val bitmap = description.iconBitmap
                coverImage.setImageBitmap(bitmap)
                if (bitmap != null) {
                    extractAndApplyGradient(bitmap)
                }
            }
            description?.iconUri != null -> {
                val uri = description.iconUri.toString()
                android.util.Log.d("LockScreenActivity", "✅ Loading cover from metadata.iconUri: $uri")
                loadCoverImage(uri)
            }
            else -> {
                android.util.Log.w("LockScreenActivity", "⚠️ No cover source available, using placeholder")
                coverImage.setImageResource(placeholder)
                backgroundView.setImageDrawable(getDefaultGradient())
            }
        }
    }

    private fun loadCoverImage(data: Any?) {
        val placeholder = R.drawable.lockscreen_cover_placeholder
        android.util.Log.d("LockScreenActivity", "loadCoverImage - data: $data, type: ${data?.javaClass?.simpleName}")
        
        coverImage.load(data) {
            crossfade(true)
            placeholder(placeholder)
            error(placeholder)
            listener(
                onSuccess = { _, result ->
                    android.util.Log.d("LockScreenActivity", "Cover loaded successfully")
                    val bitmap = (result.drawable as? BitmapDrawable)?.bitmap
                    if (bitmap != null) {
                        extractAndApplyGradient(bitmap)
                    } else {
                        android.util.Log.w("LockScreenActivity", "Cannot extract bitmap from drawable")
                        backgroundView.setImageDrawable(getDefaultGradient())
                    }
                },
                onError = { _, error ->
                    android.util.Log.e("LockScreenActivity", "Cover load failed: ${error.throwable.message}")
                    backgroundView.setImageDrawable(getDefaultGradient())
                }
            )
        }
    }

    private fun extractAndApplyGradient(bitmap: Bitmap) {
        CoroutineScope(Dispatchers.Default).launch {
            try {
                val palette = Palette.from(bitmap).generate()
                val gradient = createGradientFromPalette(palette)
                
                withContext(Dispatchers.Main) {
                    backgroundView.setImageDrawable(gradient)
                }
            } catch (e: Exception) {
                android.util.Log.e("LockScreenActivity", "Failed to extract colors", e)
                withContext(Dispatchers.Main) {
                    backgroundView.setImageDrawable(getDefaultGradient())
                }
            }
        }
    }


    private fun createGradientFromPalette(palette: Palette): GradientDrawable {
        val darkColor = palette.darkVibrantSwatch?.rgb
            ?: palette.darkMutedSwatch?.rgb
            ?: palette.dominantSwatch?.rgb
            ?: Color.parseColor("#1a1a2e")

        val lightColor = palette.lightMutedSwatch?.rgb
            ?: palette.mutedSwatch?.rgb
            ?: adjustBrightness(darkColor, 1.3f)

        return GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(darkColor, lightColor)
        ).apply {
            gradientType = GradientDrawable.LINEAR_GRADIENT
        }
    }

    private fun getDefaultGradient(): GradientDrawable {
        return GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(
                Color.parseColor("#1a1a2e"),
                Color.parseColor("#16213e")
            )
        ).apply {
            gradientType = GradientDrawable.LINEAR_GRADIENT
        }
    }

    private fun adjustBrightness(color: Int, factor: Float): Int {
        val r = (Color.red(color) * factor).toInt().coerceIn(0, 255)
        val g = (Color.green(color) * factor).toInt().coerceIn(0, 255)
        val b = (Color.blue(color) * factor).toInt().coerceIn(0, 255)
        return Color.rgb(r, g, b)
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
    
    private fun getCurrentPlaybackPosition(): Long {
        val state = playbackState ?: return 0L
        var position = state.position
        if (state.state == PlaybackStateCompat.STATE_PLAYING) {
            val timeDelta = SystemClock.elapsedRealtime() - state.lastPositionUpdateTime
            position += (timeDelta * state.playbackSpeed).toLong()
        }
        return position.coerceAtLeast(0L)
    }

    private fun formatDuration(ms: Long): String {
        val totalSeconds = (ms / 1000).coerceAtLeast(0)
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return String.format("%02d:%02d", minutes, seconds)
    }

    private fun toggleCoverLyrics() {
        if (isAnimating) {
            android.util.Log.d("LockScreenActivity", "Animation in progress, ignoring click")
            return
        }
        
        val state = latestState ?: return
        if (state.allLyrics.isEmpty()) {
            android.util.Log.d("LockScreenActivity", "No lyrics available, cannot toggle")
            return
        }

        android.util.Log.d("LockScreenActivity", "toggleCoverLyrics - isShowingLyrics: $isShowingLyrics")
        isAnimating = true

        if (isShowingLyrics) {
            fadeOut(lyricsRecyclerView) {
                lyricsRecyclerView.visibility = View.GONE
                coverImage.visibility = View.VISIBLE
                fadeIn(coverImage) {
                    isShowingLyrics = false
                    isAnimating = false
                    android.util.Log.d("LockScreenActivity", "Switched to cover view")
                }
            }
        } else {
            fadeOut(coverImage) {
                lyricsRecyclerView.visibility = View.VISIBLE
                fadeIn(lyricsRecyclerView) {
                    isShowingLyrics = true
                    isAnimating = false
                    android.util.Log.d("LockScreenActivity", "Switched to lyrics view")
                    // 初始化歌词显示
                    lastLineIndex = -1
                    updateLyrics(latestState ?: LockScreenStore.currentState())
                }
            }
        }
    }

    private fun fadeOut(view: View, onComplete: () -> Unit) {
        ObjectAnimator.ofFloat(view, "alpha", view.alpha, 0f).apply {
            duration = 300
            addUpdateListener {
                if (it.animatedFraction == 1f) {
                    onComplete()
                }
            }
            start()
        }
    }

    private fun fadeIn(view: View, onComplete: (() -> Unit)? = null) {
        ObjectAnimator.ofFloat(view, "alpha", 0f, 1f).apply {
            duration = 300
            addUpdateListener {
                if (it.animatedFraction == 1f) {
                    onComplete?.invoke()
                }
            }
            start()
        }
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
