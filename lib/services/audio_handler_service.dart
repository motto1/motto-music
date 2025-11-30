/// Motto Music AudioHandler
/// 完全基于 namida 的 BasicAudioHandler 实现
/// 
/// 核心特性：
/// - 继承自本地 BasicAudioHandler（模拟 namida 的 basic_audio_handler 包）
/// - 完整移植 namida 的播放控制逻辑
/// - vivo 等厂商系统兼容性修复
/// - 保持与 PlayerProvider 的接口兼容

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import '../core/basic_audio_handler.dart';
import 'audio_source_registry.dart';
import 'lyrics_notification_service.dart';

/// TrackItem - 音频项包装类
/// 实现 Playable 接口以兼容 BasicAudioHandler
class TrackItem extends Playable {
  @override
  final String id;
  final MediaItem mediaItem;
  final String? audioUrl; // URL 或文件路径
  final bool isFile; // 是否为本地文件
  final AudioVideoSource? audioSource; // LockCachingAudioSource
  final bool needsResolve; // 是否需要延迟解析（懒加载标记）

  TrackItem({
    required this.id,
    required this.mediaItem,
    required this.audioUrl,
    this.isFile = true,
    this.audioSource,
    this.needsResolve = false,
  });

  /// 从 MediaItem 创建 TrackItem
  static TrackItem fromMediaItem(MediaItem item) {
    final sourceType = item.extras?['sourceType'] as String? ?? 'file';
    final sourcePath = item.extras?['sourcePath'] as String?;
    final needsResolve = item.extras?['needsResolve'] as bool? ?? false;
    AudioVideoSource? customAudioSource;
    String? resolvedPath = sourcePath ?? item.id;

    // 懒加载项目：不设置 audioUrl，等待播放时解析
    if (sourceType == 'lazy' || needsResolve) {
      return TrackItem(
        id: item.id,
        mediaItem: item,
        audioUrl: null,
        isFile: false,
        needsResolve: true,
      );
    }

    if (sourceType == 'lock_caching' && sourcePath != null) {
      customAudioSource = AudioSourceRegistry.take(sourcePath);
      resolvedPath = null;
    }

    return TrackItem(
      id: item.id,
      mediaItem: item,
      audioUrl: resolvedPath,
      isFile: sourceType == 'file',
      audioSource: customAudioSource,
      needsResolve: false,
    );
  }
}

/// 懒加载解析回调类型
/// 返回解析后的音频源信息：(url, headers, isFile)
typedef LazyResolveCallback = Future<(String? url, Map<String, String>? headers, bool isFile)?> Function(MediaItem item);

/// Motto AudioHandler - 完全移植 namida 架构
class MottoAudioHandler extends BasicAudioHandler<TrackItem> {
  AudioSession? _audioSession;
  AndroidEqualizer? _equalizer;

  // ========== namida 防抖机制（完全移植）==========
  DateTime? _lastPauseAt;
  bool _suppressNextPlay = false;

  // ========== 懒加载解析回调 ==========
  LazyResolveCallback? onLazyResolve;

  // ========== 均衡器访问器 ==========
  AndroidEqualizer get equalizer => _equalizer ??= AndroidEqualizer();

  // ========== 通知栏歌词服务 ==========
  final LyricsNotificationService _lyricsService = LyricsNotificationService();

  MottoAudioHandler() {
    _initAudioHandler();

    // ⭐ 关键：监听播放状态变化，自动广播到UI和通知栏
    isPlaying.addListener(() {
      print('[AudioHandler] 🔄 播放状态变化: ${isPlaying.value}');
      _broadcastState(currentIndex.value);
    });
  }

  // ========== 覆盖通知栏位置更新回调 ==========
  @override
  void onNotificationPositionUpdate(int positionMs) {
    // 调用通知栏歌词服务更新播放位置（用于逐字高亮）
    _lyricsService.updatePosition(positionMs);
  }

  // ========== 初始化 ==========

  Future<void> _initAudioHandler() async {
    await _configureAudioSession();
    await _initializeEqualizer();
    print('[AudioHandler] ✅ 初始化完成（namida 架构）');
  }

  Future<void> _configureAudioSession() async {
    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(const AudioSessionConfiguration.music());

      // 监听音频中断（拔出耳机等）
      _audioSession!.becomingNoisyEventStream.listen((_) {
        if (isPlaying.value) {
          pause();
        }
      });
    } catch (e) {
      print('[AudioHandler] ⚠️ AudioSession 配置失败: $e');
    }
  }

  Future<void> _initializeEqualizer() async {
    try {
      await equalizer.setEnabled(true);
      print('[AudioHandler] ✅ 均衡器已启用');
    } catch (e) {
      print('[AudioHandler] ⚠️ 均衡器初始化失败: $e');
    }
  }

  // ========== namida 核心：播放控制逻辑（完全移植）==========

  @override
  Future<void> play() async {
    print('[AudioHandler] ▶️ play() 调用 (suppressNext: $_suppressNextPlay, 播放中: ${isPlaying.value})');

    // ⭐ namida 防抖逻辑 - 防止 vivo 等厂商异常回调
    if (_suppressNextPlay) {
      final now = DateTime.now();
      if (_lastPauseAt != null) {
        final diff = now.difference(_lastPauseAt!).inMilliseconds;
        if (diff < 500) {
          print('[AudioHandler] ❎ 忽略暂停后 ${diff}ms 内的 play (vivo 兼容修复)');
          _suppressNextPlay = false;
          return;
        }
        print('[AudioHandler] ⏱️ 距暂停 ${diff}ms，清除防抖标志');
      }
      _suppressNextPlay = false;
    }

    try {
      await _audioSession?.setActive(true);
      await super.play();
      print('[AudioHandler] ✅ play() 执行完成');
    } catch (e) {
      print('[AudioHandler] ❌ play() 失败: $e');
    }
  }

  @override
  Future<void> pause() async {
    print('[AudioHandler] ⏸️ pause() 调用 (播放中: ${isPlaying.value})');

    // ⭐ namida 防抖设置
    _lastPauseAt = DateTime.now();
    _suppressNextPlay = true;

    try {
      await super.pause();
      // ⚠️ 关键：不调用 setActive(false)，避免 vivo 系统异常回调
      print('[AudioHandler] ✅ pause() 执行完成');
    } catch (e) {
      print('[AudioHandler] ❌ pause() 失败: $e');
    }
  }

  @override
  Future<void> stop() async {
    print('[AudioHandler] ⏹️ stop() 调用');
    await super.stop();
    await _audioSession?.setActive(false);
  }

  // ========== 播放项管理（namida 模式）==========

  @override
  Future<void> onItemPlay(
    TrackItem item,
    int index,
    Function skipItem,
    dynamic preparedItemInfo,
  ) async {
    print('[AudioHandler] 🎵 播放: ${item.mediaItem.title} (索引: $index)');

    try {
      String? audioUrl = item.audioUrl;
      Map<String, String>? headers = item.mediaItem.extras?['headers'] as Map<String, String>?;
      bool isFile = item.isFile;

      // ⭐ 懒加载处理：如果需要解析，调用回调获取音频源
      if (item.needsResolve) {
        print('[AudioHandler] 🔄 懒加载项目，开始解析音频源...');

        if (onLazyResolve != null) {
          final resolved = await onLazyResolve!(item.mediaItem);
          if (resolved != null) {
            audioUrl = resolved.$1;
            headers = resolved.$2;
            isFile = resolved.$3;
            final urlPreview = audioUrl != null && audioUrl.length > 50
                ? '${audioUrl.substring(0, 50)}...'
                : audioUrl ?? 'null';
            print('[AudioHandler] ✅ 懒加载解析完成: $urlPreview');
          } else {
            print('[AudioHandler] ❌ 懒加载解析失败，跳过此曲目');
            skipItem();
            return;
          }
        } else {
          print('[AudioHandler] ⚠️ 未设置懒加载回调，跳过此曲目');
          skipItem();
          return;
        }
      }

      if (headers != null) {
        print('[AudioHandler] 🔑 提取到 headers: ${headers.keys.join(", ")}');
      }

      // 设置音频源（使用 URL 字符串）
      final duration = await setSource(
        audioUrl,
        item: item,
        index: index,
        isFile: isFile,
        headers: headers,
        audioSource: item.audioSource,
      );

      // 更新媒体信息到通知栏
      mediaItem.add(item.mediaItem);
      _broadcastState(index);

      // 如果设置了自动播放
      if (playWhenReady.value) {
        await _audioSession?.setActive(true);
        await player.play();
      }

      print('[AudioHandler] ✅ 播放设置完成 (时长: $duration)');
    } catch (e, stack) {
      print('[AudioHandler] ❌ 播放失败: $e\n$stack');
      // 播放失败时跳过
      skipItem();
    }
  }

  void _broadcastState(int itemIndex) {
    final event = PlaybackEvent(
      processingState: player.processingState,  // 直接使用 ProcessingState
      updateTime: DateTime.now(),
      updatePosition: Duration(milliseconds: currentPositionMS.value),
      bufferedPosition: player.bufferedPosition,
      duration: currentItemDuration.value,
      currentIndex: itemIndex,
    );

    playbackState.add(transformEvent(event, false, itemIndex));
  }

  /// 映射 ProcessingState 到 AudioProcessingState
  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        return AudioProcessingState.idle;
    }
  }

  @override
  Future<void> onQueueChanged() async {
    await super.onQueueChanged();
    print('[AudioHandler] 📋 队列更新 (长度: ${currentQueue.queueRx.value.length})');
  }

  // ========== namida 通知栏配置（完全移植）==========

  @override
  PlaybackState transformEvent(
    PlaybackEvent event,
    bool isItemFavourite,
    int itemIndex,
  ) {
    return playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (isPlaying.value) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.playPause,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(event.processingState),  // 映射类型
      playing: isPlaying.value,
      updatePosition: event.updatePosition,
      bufferedPosition: event.bufferedPosition,
      speed: player.speed,
      queueIndex: itemIndex,
    );
  }

  // ========== 兼容层方法 - 保持与 PlayerProvider 的兼容 ==========

  /// 设置播放列表（兼容旧接口）
  Future<void> setPlaylist(List<MediaItem> items, {int initialIndex = 0}) async {
    print('[AudioHandler] 📋 设置播放列表: ${items.length} 首, 起始: $initialIndex');

    final trackItems = items.map((item) => TrackItem.fromMediaItem(item)).toList();

    await assignNewQueue(
      queue: trackItems,
      playAtIndex: initialIndex,
      startPlaying: false, // 默认不自动播放
    );
  }

  /// 添加到队列（兼容旧接口）
  @override
  Future<void> addQueueItem(MediaItem item) async {
    final trackItem = TrackItem.fromMediaItem(item);
    await addToQueue(trackItem);
    print('[AudioHandler] ➕ 添加到队列: ${item.title}');
  }

  /// 从队列移除（兼容旧接口）
  @override
  Future<void> removeQueueItem(MediaItem item) async {
    final index = currentQueue.queueRx.value.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      await removeFromQueue(index);
      print('[AudioHandler] ➖ 从队列移除: ${item.title}');
    }
  }

  // ========== 便捷访问器（PlayerProvider 兼容）==========

  /// 获取当前播放位置
  Duration get position => player.position;

  /// 获取当前播放状态
  bool get playing => isPlaying.value;

  /// 获取音频时长
  Duration? get duration => currentItemDuration.value;

  /// 获取当前索引
  int get currentQueueIndex => currentIndex.value;

  /// 获取播放队列（兼容访问）
  List<TrackItem> get queueList => currentQueue.queueRx.value;

  // ========== 资源清理 ==========

  Future<void> dispose() async {
    _suppressNextPlay = false;
    _lastPauseAt = null;
    await onDispose();
    // AndroidEqualizer 会随播放器自动释放
    print('[AudioHandler] 🗑️ 资源释放完成');
  }
}
