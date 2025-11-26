/// 通知栏歌词服务
/// 通过Platform Channel与Android原生层通信，实现通知栏歌词显示
///
/// 功能：
/// - 发送当前句和下一句歌词到通知栏
/// - 更新播放位置用于逐字高亮
/// - 清除歌词显示
/// - 控制功能开关

import 'package:flutter/services.dart';
import 'dart:io';

class LyricsNotificationService {
  static const MethodChannel _channel = MethodChannel('com.mottomusic.lyrics_notification');

  // 单例模式
  static final LyricsNotificationService _instance = LyricsNotificationService._internal();
  factory LyricsNotificationService() => _instance;
  LyricsNotificationService._internal();

  /// 是否启用通知栏歌词（默认开启）
  bool _enabled = true;
  bool get enabled => _enabled;

  /// 初始化服务
  Future<void> init() async {
    if (!Platform.isAndroid) {
      print('[LyricsNotification] 仅支持Android平台');
      return;
    }

    try {
      await _channel.invokeMethod('init');
      print('[LyricsNotification] ✅ 初始化成功');
    } catch (e) {
      print('[LyricsNotification] ❌ 初始化失败: $e');
    }
  }

  /// 更新通知栏歌词
  ///
  /// [currentLine] 当前句歌词文本
  /// [nextLine] 下一句歌词文本（可选）
  /// [currentLineStartMs] 当前句起始时间（毫秒）
  /// [currentLineEndMs] 当前句结束时间（毫秒）
  /// [charTimestamps] 字级时间戳列表（可选，用于逐字高亮）
  ///   格式：[{char: "歌", startMs: 1000, endMs: 1200}, ...]
  Future<void> updateLyrics({
    required String currentLine,
    String? nextLine,
    required int currentLineStartMs,
    required int currentLineEndMs,
    List<Map<String, dynamic>>? charTimestamps,
  }) async {
    if (!Platform.isAndroid || !_enabled) return;

    try {
      await _channel.invokeMethod('updateLyrics', {
        'currentLine': currentLine,
        'nextLine': nextLine,
        'currentLineStartMs': currentLineStartMs,
        'currentLineEndMs': currentLineEndMs,
        'charTimestamps': charTimestamps,
      });
    } catch (e) {
      print('[LyricsNotification] ❌ 更新歌词失败: $e');
    }
  }

  /// 更新播放位置（用于逐字高亮）
  ///
  /// [positionMs] 当前播放位置（毫秒）
  Future<void> updatePosition(int positionMs) async {
    if (!Platform.isAndroid || !_enabled) return;

    try {
      await _channel.invokeMethod('updatePosition', {
        'positionMs': positionMs,
      });
    } catch (e) {
      // 位置更新高频调用，失败不打印日志避免刷屏
    }
  }

  /// 清除通知栏歌词（无歌词或停止播放时调用）
  Future<void> clearLyrics() async {
    if (!Platform.isAndroid || !_enabled) return;

    try {
      await _channel.invokeMethod('clearLyrics');
      print('[LyricsNotification] 🧹 歌词已清除');
    } catch (e) {
      print('[LyricsNotification] ❌ 清除歌词失败: $e');
    }
  }

  /// 设置通知栏歌词开关
  ///
  /// [enabled] true=启用，false=禁用
  Future<void> setEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;

    _enabled = enabled;

    try {
      await _channel.invokeMethod('setEnabled', {
        'enabled': enabled,
      });
      print('[LyricsNotification] ${enabled ? "✅ 已启用" : "⏸️ 已禁用"}');

      // 禁用时清除现有歌词
      if (!enabled) {
        await clearLyrics();
      }
    } catch (e) {
      print('[LyricsNotification] ❌ 设置开关失败: $e');
    }
  }

  /// 测试原生通信是否正常
  Future<bool> testConnection() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('ping');
      print('[LyricsNotification] 🏓 Ping结果: $result');
      return result == 'pong';
    } catch (e) {
      print('[LyricsNotification] ❌ 连接测试失败: $e');
      return false;
    }
  }
}
