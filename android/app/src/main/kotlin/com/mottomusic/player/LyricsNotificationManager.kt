package com.mottomusic.player

import android.app.NotificationManager
import android.content.Context
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.text.SpannableString
import android.text.style.ForegroundColorSpan
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
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "com.mottomusic.player.channel.audio"

        // 更新节流间隔
        private const val UPDATE_THROTTLE_MS = 1000L // 通知更新 ≤ 1次/秒
        private const val HIGHLIGHT_UPDATE_MS = 100L  // 字高亮更新间隔
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

        Log.d(TAG, "更新歌词: current='$currentLine', next='$nextLine'")

        // 立即触发通知更新（歌词行切换）
        updateNotificationThrottled(immediate = true)
    }

    // ========== 核心方法：更新播放位置 ==========

    fun updatePosition(positionMs: Int) {
        if (!enabled) return

        this.currentPositionMs = positionMs

        // 仅在有字级时间戳时才高频更新（逐字高亮）
        if (charTimestamps != null && !isRestrictedRom) {
            updateNotificationThrottled(immediate = false)
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

        // TODO: 更新通知为无歌词状态
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

    private fun updateNotificationThrottled(immediate: Boolean) {
        val now = System.currentTimeMillis()
        val timeSinceLastUpdate = now - lastUpdateTime

        if (immediate || timeSinceLastUpdate >= UPDATE_THROTTLE_MS) {
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
                handler.postDelayed(it, UPDATE_THROTTLE_MS - timeSinceLastUpdate)
            }
        }
    }

    // ========== 实际通知更新逻辑 ==========

    private fun updateNotificationInternal() {
        // 构建高亮歌词
        val highlightedCurrent = buildHighlightedLyric(
            currentLine ?: "",
            charTimestamps,
            currentPositionMs
        )

        Log.d(TAG, "更新通知: position=${currentPositionMs}ms, highlighted=${highlightedCurrent.length}chars")

        // TODO: 实际构建和发送通知（Phase 1.3完成布局后实现）
        // 这里暂时只记录日志
    }

    // ========== 逐字高亮计算 ==========

    private fun buildHighlightedLyric(
        text: String,
        timestamps: List<CharTimestamp>?,
        positionMs: Int
    ): SpannableString {
        val spannable = SpannableString(text)

        if (timestamps.isNullOrEmpty() || isRestrictedRom) {
            // 无字级时间戳或受限ROM，返回普通文本
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
            val highlightColor = 0xFFFFFFFF.toInt() // 白色高亮
            spannable.setSpan(
                ForegroundColorSpan(highlightColor),
                0,
                min(highlightEnd, text.length),
                SpannableString.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }

        return spannable
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
