package com.mottomusic.player

import android.content.Context
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val LYRICS_CHANNEL = "com.mottomusic.lyrics_notification"
    private lateinit var lyricsManager: LyricsNotificationManager

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        return AudioServicePlugin.getFlutterEngine(context)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 初始化歌词管理器
        lyricsManager = LyricsNotificationManager(this)

        // 注册MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LYRICS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    lyricsManager.init()
                    result.success(null)
                }
                "updateLyrics" -> {
                    val currentLine = call.argument<String>("currentLine")
                    val nextLine = call.argument<String?>("nextLine")
                    val currentLineStartMs = call.argument<Int>("currentLineStartMs") ?: 0
                    val currentLineEndMs = call.argument<Int>("currentLineEndMs") ?: 0
                    val charTimestamps = call.argument<List<Map<String, Any>>?>("charTimestamps")

                    lyricsManager.updateLyrics(
                        currentLine,
                        nextLine,
                        currentLineStartMs,
                        currentLineEndMs,
                        charTimestamps
                    )
                    result.success(null)
                }
                "updatePosition" -> {
                    val positionMs = call.argument<Int>("positionMs") ?: 0
                    lyricsManager.updatePosition(positionMs)
                    result.success(null)
                }
                "clearLyrics" -> {
                    lyricsManager.clearLyrics()
                    result.success(null)
                }
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    lyricsManager.setEnabled(enabled)
                    result.success(null)
                }
                "ping" -> {
                    val pong = lyricsManager.ping()
                    result.success(pong)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::lyricsManager.isInitialized) {
            lyricsManager.dispose()
        }
    }
}
