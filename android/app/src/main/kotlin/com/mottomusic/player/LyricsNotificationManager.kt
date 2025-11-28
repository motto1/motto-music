package com.mottomusic.player

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.text.SpannableString
import android.text.style.ForegroundColorSpan
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import android.util.Log
import kotlin.math.min

/**
 * 通知栏歌词管理器
 *
 * 职责：
 * - 管理歌词状态缓存
 * - 构建自定义通知布局（RemoteViews）
 * - 实现逐字高亮渲染
 * - ROM兼容性检测和降级
 * - 节流更新机制
 */
class LyricsNotificationManager(private val context: Context) {

    companion object {
        private const val TAG = "LyricsNotification"
        private const val NOTIFICATION_ID = 999  // 使用独立ID，避免与audio_service冲突
        private const val CHANNEL_ID = "com.mottomusic.player.lyrics"  // 独立通道

        // 更新节流间隔
        private const val UPDATE_THROTTLE_MS = 1000L // 行切换更新
        private const val HIGHLIGHT_UPDATE_MS = 120L  // 字高亮刷新
        private const val RESTRICTED_POSITION_THROTTLE_MS = 350L

        private val HIGHLIGHT_START_COLOR = 0xFFCCCCCC.toInt() // 灰色
        private val HIGHLIGHT_END_COLOR = 0xFFFFFFFF.toInt()   // 白色
        private val NON_HIGHLIGHT_COLOR = 0x66FFFFFF.toInt()   // 半透明白
    }

    // ========== 状态缓存 ==========

    private var enabled = true
    private var currentLine: String? = null
    private var nextLine: String? = null
    private var currentLineStartMs = 0
    private var currentLineEndMs = 0
    private var charTimestamps: List<CharTimestamp>? = null
    private var currentPositionMs = 0

    // 节流控制
    private var lastUpdateTime = 0L
    private val handler = Handler(Looper.getMainLooper())
    private var pendingUpdate: Runnable? = null

    // ROM类型检测
    private val isRestrictedRom: Boolean by lazy {
        detectRestrictedRom()
    }

    // NotificationManager
    private val notificationManager: NotificationManager by lazy {
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }

    // ========== 数据结构 ==========

    data class CharTimestamp(
        val char: String,
        val startMs: Int,
        val endMs: Int
    )

    // ========== 初始化 ==========

    fun init() {
        Log.d(TAG, "初始化通知栏歌词管理器")
        Log.d(TAG, "ROM类型检测: ${if (isRestrictedRom) "受限ROM (降级模式)" else "标准ROM"}")

        // 创建通知渠道 (Android 8.0+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "歌词显示",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "实时显示歌词内容"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = android.app.Notification.VISIBILITY_SECRET
            }
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "✅ NotificationChannel 已创建: $CHANNEL_ID")
        }
    }

    // ========== 核心方法：更新歌词 ==========

    fun updateLyrics(
        currentLine: String?,
        nextLine: String?,
        currentLineStartMs: Int,
        currentLineEndMs: Int,
        charTimestamps: List<Map<String, Any>>?
    ) {
        if (!enabled) {
            Log.d(TAG, "歌词显示已禁用，跳过更新")
            return
        }

        this.currentLine = currentLine
        this.nextLine = nextLine
        this.currentLineStartMs = currentLineStartMs
        this.currentLineEndMs = currentLineEndMs
        this.charTimestamps = charTimestamps?.map {
            CharTimestamp(
                char = it["char"] as String,
                startMs = (it["startMs"] as Number).toInt(),
                endMs = (it["endMs"] as Number).toInt()
            )
        }

        Log.d(TAG, "更新歌词: current='$currentLine'")

        // 立即触发通知更新（歌词行切换）
        updateNotificationThrottled(immediate = true)
    }

    // ========== 核心方法：更新播放位置 ==========

    fun updatePosition(positionMs: Int) {
        if (!enabled) return

        this.currentPositionMs = positionMs

        if (charTimestamps != null) {
            val throttle = if (isRestrictedRom) {
                RESTRICTED_POSITION_THROTTLE_MS
            } else {
                HIGHLIGHT_UPDATE_MS
            }
            updateNotificationThrottled(immediate = false, throttleMs = throttle)
        }
    }

    // ========== 核心方法：清除歌词 ==========

    fun clearLyrics() {
        currentLine = null
        nextLine = null
        charTimestamps = null

        Log.d(TAG, "清除歌词")

        // 取消待处理的更新
        pendingUpdate?.let { handler.removeCallbacks(it) }

        // 取消通知
        try {
            notificationManager.cancel(NOTIFICATION_ID)
            Log.d(TAG, "✅ 通知已取消")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 取消通知失败: ${e.message}", e)
        }
    }

    // ========== 核心方法：设置开关 ==========

    fun setEnabled(enabled: Boolean) {
        this.enabled = enabled
        Log.d(TAG, "通知栏歌词${if (enabled) "已启用" else "已禁用"}")

        if (!enabled) {
            clearLyrics()
        }
    }

    // ========== 通知更新（节流） ==========

    private fun updateNotificationThrottled(immediate: Boolean, throttleMs: Long = UPDATE_THROTTLE_MS) {
        val now = System.currentTimeMillis()
        val timeSinceLastUpdate = now - lastUpdateTime

        if (immediate || timeSinceLastUpdate >= throttleMs) {
            // 立即更新
            lastUpdateTime = now
            updateNotificationInternal()
        } else {
            // 延迟更新
            pendingUpdate?.let { handler.removeCallbacks(it) }
            pendingUpdate = Runnable {
                lastUpdateTime = System.currentTimeMillis()
                updateNotificationInternal()
            }.also {
                handler.postDelayed(it, throttleMs - timeSinceLastUpdate)
            }
        }
    }

    // ========== 实际通知更新逻辑 ==========

    private fun updateNotificationInternal() {
        Log.d(TAG, "🔧 开始构建通知...")

        if ((currentLine.isNullOrBlank()) && (nextLine.isNullOrBlank())) {
            clearLyrics()
            return
        }

        // 构建高亮歌词
        val highlightedCurrent = buildHighlightedLyric(
            currentLine ?: "",
            charTimestamps,
            currentPositionMs
        )

        Log.d(TAG, "更新通知: position=${currentPositionMs}ms, highlighted=${highlightedCurrent.length}chars")

        try {
            Log.d(TAG, "🔧 步骤1: 创建RemoteViews")
            val remoteViews = RemoteViews(context.packageName, R.layout.notification_lyrics_simple)

            val lyricText = if (currentLine.isNullOrEmpty()) {
                ""
            } else {
                highlightedCurrent
            }

            Log.d(TAG, "🔧 步骤2: 设置歌词文本 (${lyricText.length} chars)")
            remoteViews.setTextViewText(R.id.notification_current_lyric, lyricText)
            if (nextLine.isNullOrBlank()) {
                remoteViews.setTextViewText(R.id.notification_next_lyric, "")
                remoteViews.setViewVisibility(R.id.notification_next_lyric, View.GONE)
            } else {
                remoteViews.setTextViewText(R.id.notification_next_lyric, nextLine)
                remoteViews.setViewVisibility(R.id.notification_next_lyric, View.VISIBLE)
            }

            Log.d(TAG, "🔧 步骤3: 构建Notification对象")
            // 创建点击Intent
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // 构建通知
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setContentTitle(null)
                .setContentText(null)
                .setCustomContentView(remoteViews)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setShowWhen(false)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setVisibility(NotificationCompat.VISIBILITY_SECRET)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setAutoCancel(false)
                .build()

            Log.d(TAG, "🔧 步骤5: 显示通知 (ID=$NOTIFICATION_ID)")
            // 显示通知
            notificationManager.notify(NOTIFICATION_ID, notification)

            Log.d(TAG, "✅ 通知已更新显示")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 更新通知失败: ${e.message}", e)
            e.printStackTrace()
        }
    }

    // ========== 逐字高亮计算 ==========

    private fun buildHighlightedLyric(
        text: String,
        timestamps: List<CharTimestamp>?,
        positionMs: Int
    ): SpannableString {
        if (text.isEmpty()) {
            return SpannableString("")
        }

        val spannable = SpannableString(text)
        spannable.setSpan(
            ForegroundColorSpan(NON_HIGHLIGHT_COLOR),
            0,
            text.length,
            SpannableString.SPAN_EXCLUSIVE_EXCLUSIVE
        )

        if (timestamps.isNullOrEmpty()) {
            return spannable
        }

        // 计算高亮字符数
        var highlightEnd = 0
        for ((index, charTime) in timestamps.withIndex()) {
            if (positionMs >= charTime.startMs) {
                highlightEnd = index + 1
            } else {
                break
            }
        }

        // 应用前景色（高亮部分）
        if (highlightEnd > 0) {
            val clampedEnd = min(highlightEnd, text.length)
            for (i in 0 until clampedEnd) {
                val ratio = if (clampedEnd <= 1) 1f else i.toFloat() / (clampedEnd - 1).toFloat()
                val color = blendColors(HIGHLIGHT_START_COLOR, HIGHLIGHT_END_COLOR, ratio)
                spannable.setSpan(
                    ForegroundColorSpan(color),
                    i,
                    i + 1,
                    SpannableString.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
        }

        return spannable
    }

    private fun blendColors(startColor: Int, endColor: Int, ratio: Float): Int {
        val clampedRatio = ratio.coerceIn(0f, 1f)
        val inverseRatio = 1f - clampedRatio
        val a = (Color.alpha(startColor) * inverseRatio + Color.alpha(endColor) * clampedRatio).toInt()
        val r = (Color.red(startColor) * inverseRatio + Color.red(endColor) * clampedRatio).toInt()
        val g = (Color.green(startColor) * inverseRatio + Color.green(endColor) * clampedRatio).toInt()
        val b = (Color.blue(startColor) * inverseRatio + Color.blue(endColor) * clampedRatio).toInt()
        return Color.argb(a, r, g, b)
    }

    // ========== ROM兼容性检测 ==========

    private fun detectRestrictedRom(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()

        return when {
            manufacturer.contains("vivo") -> true
            manufacturer.contains("oppo") -> true
            brand.contains("vivo") -> true
            brand.contains("oppo") -> true
            manufacturer.contains("xiaomi") && Build.VERSION.SDK_INT < Build.VERSION_CODES.Q -> true
            else -> false
        }.also {
            if (it) {
                Log.w(TAG, "检测到受限ROM: $manufacturer $brand, 启用降级模式")
            }
        }
    }

    // ========== 测试方法 ==========

    fun ping(): String {
        Log.d(TAG, "Ping测试")
        return "pong"
    }

    // ========== 资源清理 ==========

    fun dispose() {
        pendingUpdate?.let { handler.removeCallbacks(it) }
        Log.d(TAG, "资源已清理")
    }
}
