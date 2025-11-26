import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../utils/platform_utils.dart';
import 'audio_handler_service.dart';

/// 统一管理 AudioService 与 MottoAudioHandler 的初始化，解决桌面 / 移动差异。
class AudioServiceManager {
  AudioServiceManager._();

  static MottoAudioHandler? _handler;
  static Completer<MottoAudioHandler>? _pendingInit;

  /// 获取（或初始化）音频处理器。
  static Future<MottoAudioHandler> ensureInitialized() {
    if (_handler != null) return Future.value(_handler);
    if (_pendingInit != null) return _pendingInit!.future;

    _pendingInit = Completer<MottoAudioHandler>();
    _createHandler().then((handler) {
      _handler = handler;
      _pendingInit?.complete(handler);
    }).catchError((Object error, StackTrace stackTrace) {
      debugPrint('❌ AudioService 初始化失败: $error');
      debugPrint('$stackTrace');
      // 回退到本地 AudioHandler，保证播放器仍可运行
      final fallback = MottoAudioHandler();
      _handler = fallback;
      _pendingInit?.complete(fallback);
    }).whenComplete(() {
      _pendingInit = null;
    });

    return _pendingInit!.future;
  }

  static MottoAudioHandler? get handler => _handler;

  static Future<MottoAudioHandler> _createHandler() async {
    if (PlatformUtils.isMobile) {
      debugPrint('🔧 正在初始化 AudioService (移动端)...');
      final handler = await AudioService.init(
        builder: MottoAudioHandler.new,
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.mottomusic.player.channel.audio',
          androidNotificationChannelName: 'Motto Music',
          androidNotificationChannelDescription: 'Motto Music 播放控制',
          androidNotificationIcon: 'mipmap/ic_launcher',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
          androidShowNotificationBadge: true,
        ),
      );
      debugPrint('✅ AudioService 初始化完成');
      return handler;
    }

    debugPrint('ℹ️ 桌面平台绕过 AudioService，直接使用本地 AudioHandler');
    return MottoAudioHandler();
  }
}
