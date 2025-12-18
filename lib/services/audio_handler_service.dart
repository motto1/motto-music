/// Motto Music AudioHandler
/// 完全基于 namida 的 BasicAudioHandler 实现
///
/// 核心特性：
/// - 继承自本地 BasicAudioHandler（模拟 namida 的 basic_audio_handler 包）
/// - 完整移植 namida 的播放控制逻辑
/// - vivo 等厂商系统兼容性修复
/// - 保持与 PlayerProvider 的接口兼容

import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../core/basic_audio_handler.dart';
import '../models/bilibili/loudness_info.dart';
import '../storage/player_state_storage.dart';
import 'audio_source_registry.dart';
import 'lyrics_notification_service.dart';

/// 播放失败回调，用于将底层播放器错误上报到上层（如 PlayerProvider）
typedef PlaybackErrorCallback = void Function(
  MediaItem mediaItem,
  Object error,
  StackTrace stackTrace,
);

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

  // ========== 播放失败回调（供上层状态管理使用）==========
  PlaybackErrorCallback? onPlaybackError;

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

  @override
  Future<void> configureEnginePlaylist({
    required List<TrackItem> queue,
    required int initialIndex,
    required bool gaplessEnabled,
  }) async {
    // 当前版本不启用底层引擎播放列表，仅记录调用信息，保留扩展点。
    enginePlaylistEnabled = false;
    print(
      '[AudioHandler] 🎛️ configureEnginePlaylist: queue=${queue.length}, '
      'initial=$initialIndex, gaplessEnabled=$gaplessEnabled '
      '(当前实现未启用底层播放列表)',
    );
  }

  // ========== 覆盖通知栏位置更新回调 ==========
  @override
  void onNotificationPositionUpdate(int positionMs) {
    // 调用通知栏歌词服务更新播放位置（用于逐字高亮）
    _lyricsService.updatePosition(positionMs);
    // 同步刷新 MediaSession 的 updatePosition/lastPositionUpdateTime，避免锁屏进度条推算漂移
    _broadcastState(currentIndex.value);
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

      // 应用淡入效果
      final storage = await PlayerStateStorage.getInstance();
      final fadeInMs = storage.fadeInDurationMs;
      print('[AudioHandler] 🎚️ play()中的淡入设置: ${fadeInMs}ms');
      if (fadeInMs > 0) {
        await fadeIn(fadeInMs);
      }
    } catch (e) {
      print('[AudioHandler] ❌ play() 失败: $e');
    }
  }

  @override
  Future<void> pause() async {
    print('[AudioHandler] ⏸️ pause() 调用 (播放中: ${isPlaying.value})');

    final wasPlaying = isPlaying.value;

    // ⭐ namida 防抖设置
    _lastPauseAt = DateTime.now();
    _suppressNextPlay = true;

    // 立即更新本地播放状态，提升按钮响应速度
    if (wasPlaying) {
      isPlaying.value = false;
      _broadcastState(currentIndex.value);
    }

    try {
      // 应用淡出效果（针对用户主动暂停）
      try {
        final storage = await PlayerStateStorage.getInstance();
        final fadeOutMs = storage.fadeOutDurationMs;
        if (fadeOutMs > 0 && wasPlaying) {
          print('[AudioHandler] 🎚️ pause()中的淡出设置: ${fadeOutMs}ms');
          await fadeOut(fadeOutMs);
        }
      } catch (e) {
        print('[AudioHandler] ⚠️ pause() 获取淡出配置失败: $e');
      }

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

    final wasPlaying = isPlaying.value;

    // 立即更新本地播放状态，提升按钮响应速度
    if (wasPlaying) {
      isPlaying.value = false;
      _broadcastState(currentIndex.value);
    }

    // 停止播放前尝试根据设置做一次淡出
    try {
      final storage = await PlayerStateStorage.getInstance();
      final fadeOutMs = storage.fadeOutDurationMs;
      if (fadeOutMs > 0 && wasPlaying) {
        print('[AudioHandler] 🎚️ stop()中的淡出设置: ${fadeOutMs}ms');
        await fadeOut(fadeOutMs);
      }
    } catch (e) {
      print('[AudioHandler] ⚠️ stop() 获取淡出配置失败: $e');
    }

    await super.stop();
    await _audioSession?.setActive(false);
  }

  // ========== seek 覆盖：完成后广播状态刷新时间戳 ==========

  @override
  Future<void> seek(Duration position) async {
    await super.seek(position);
    // ⭐ 关键：seek完成后广播状态，刷新lastPositionUpdateTime
    // 解决锁屏进度条在seek后跳回的问题
    _broadcastState(currentIndex.value);
    print('[AudioHandler] 🔍 seek完成，已广播状态更新');
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
      Map<String, String>? headers =
          item.mediaItem.extras?['headers'] as Map<String, String>?;
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

      // ⭐ LockCachingAudioSource 兼容处理：
      // 懒加载场景下，_resolveBilibiliAudioSource 会在 AudioSourceRegistry 中注册
      // 一个 LockCachingAudioSource，并返回其 ID（如 bilibili_BV..._cid_quality）。
      // 若此时 TrackItem.audioSource 仍为空，则优先尝试从注册表取回真实音源，
      // 避免将该 ID 误当作本地文件路径或普通 URL 交给 ExoPlayer。
      AudioVideoSource? effectiveAudioSource = item.audioSource;
      if (effectiveAudioSource == null && audioUrl != null) {
        final lockCachingSource = AudioSourceRegistry.take(audioUrl);
        if (lockCachingSource != null) {
          print(
            '[AudioHandler] 🎧 检测到 LockCachingAudioSource 标识，'
            '从注册表接管为自定义音源: $audioUrl',
          );
          effectiveAudioSource = lockCachingSource;
          // 此时 audioUrl 只是内部标识，不应再作为 URL 使用
          audioUrl = null;
          isFile = false;
        }
      }

      if (headers != null) {
        print('[AudioHandler] 🔑 提取到 headers: ${headers.keys.join(", ")}');
      }

      // ⭐ 应用响度增益（自动场景选择）
      final loudnessData = item.mediaItem.extras?['loudness'];
      if (loudnessData != null && loudnessData is Map<String, dynamic>) {
        final loudness = LoudnessInfo.fromJson(loudnessData);

        // 自动选择场景
        final autoScene = loudness.getAutoScene();
        final gain = loudness.getLinearGain(); // 使用自动场景

        setLoudnessGain(gain);

        print('[AudioHandler] 🔊 自动场景: $autoScene');
        print('[AudioHandler] 📊 响度参数: ${loudness.measuredI.toStringAsFixed(1)} LUFS, LRA: ${loudness.measuredLra.toStringAsFixed(1)} LU');
        print('[AudioHandler] 🎚️ 增益: ${loudness.getGainDb().toStringAsFixed(1)} dB (${gain.toStringAsFixed(2)}x)');
      } else {
        setLoudnessGain(1.0);
      }

      // 设置音频源（使用 URL 字符串或自定义音频源），带有限次重试
      final duration = await _setSourceWithRetry(
        item: item,
        index: index,
        audioUrl: audioUrl,
        isFile: isFile,
        headers: headers,
        audioSource: effectiveAudioSource,
      );

      // 如果多次重试后仍然无法加载音源，视为当前曲目不可播放，直接跳过
      if (duration == null) {
        print(
          '[AudioHandler] ❌ 多次重试后仍无法设置音频源，跳过此曲目: '
          '${item.mediaItem.title}',
        );
        skipItem();
        return;
      }

      // 更新媒体信息到通知栏
      final updatedMediaItem = item.mediaItem.duration == duration
          ? item.mediaItem
          : item.mediaItem.copyWith(duration: duration);
      mediaItem.add(updatedMediaItem);
      _broadcastState(index);

      print('[AudioHandler] 🔍 playWhenReady: ${playWhenReady.value}');

      // 如果设置了自动播放
      if (playWhenReady.value) {
        print('[AudioHandler] ▶️ 开始播放流程');
        await _audioSession?.setActive(true);
        await player.play();
        print('[AudioHandler] ✅ player.play() 完成');

        // 应用淡入效果（根据 Gapless 设置决定切歌时淡入策略）
        final storage = await PlayerStateStorage.getInstance();
        final fadeInMs = storage.fadeInDurationMs;
        final gaplessEnabled = storage.gaplessEnabled;
        print(
          '[AudioHandler] 🎚️ 淡入设置: ${fadeInMs}ms, gaplessEnabled: $gaplessEnabled',
        );

        if (gaplessEnabled) {
          // Gapless 模式下：使用极短淡入以消除爆音，同时尽量减少感知间隙
          final microFadeMs = fadeInMs.clamp(0, 100);
          if (microFadeMs > 0) {
            print(
              '[AudioHandler] ⏭️ Gapless 已启用，使用微淡入: ${microFadeMs}ms',
            );
            await fadeIn(microFadeMs);
          } else {
            print('[AudioHandler] ⏭️ Gapless 已启用，但淡入时长为0，跳过淡入');
          }
        } else if (fadeInMs > 0) {
          // 非 Gapless 模式：使用用户配置的完整淡入
          await fadeIn(fadeInMs);
        } else {
          print('[AudioHandler] ⏭️ 淡入已禁用（时长为0）');
        }
      } else {
        print('[AudioHandler] ⏸️ playWhenReady=false，跳过自动播放');
      }

      print('[AudioHandler] ✅ 播放设置完成 (时长: $duration)');
    } catch (e, stack) {
      print('[AudioHandler] ❌ 播放失败: $e\n$stack');
      // 播放失败时跳过
      skipItem();
    }
  }

  /// 带有限次重试的音源设置逻辑
  ///
  /// - 避免单次网络抖动导致直接失败
  /// - 总重试次数和间隔保持较小，保证队列不会被长时间阻塞
  Future<Duration?> _setSourceWithRetry({
    required TrackItem item,
    required int index,
    required String? audioUrl,
    required bool isFile,
    required Map<String, String>? headers,
    required AudioVideoSource? audioSource,
  }) async {
    const maxAttempts = 3;

    Duration? duration;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      duration = await setSource(
        audioUrl,
        item: item,
        index: index,
        isFile: isFile,
        headers: headers,
        audioSource: audioSource,
      );

      if (duration != null) {
        if (attempt > 1) {
          print(
            '[AudioHandler] ✅ 设置音源在第 $attempt 次尝试后成功: '
            '${item.mediaItem.title}',
          );
        }
        return duration;
      }

      if (attempt < maxAttempts) {
        // 线性退避：200ms, 400ms，总重试等待约 600ms
        final delayMs = 200 * attempt;
        print(
          '[AudioHandler] ⏳ 设置音源失败，第 $attempt 次尝试后将在 '
          '${delayMs}ms 后重试: ${item.mediaItem.title}',
        );
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    print(
      '[AudioHandler] ❌ 设置音源在重试 $maxAttempts 次后仍失败: '
      '${item.mediaItem.title}',
    );
    return null;
  }

  /// 调整底层播放队列顺序（与 UI 拖动保持一致）
  ///
  /// 仅在当前队列不为空时生效，不会打断当前播放的歌曲，
  /// 只更新后续播放顺序以及 currentIndex。
  ///
  /// 参数使用 ReorderableListView 的原始索引，内部会做标准调整。
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final queue = currentQueue.queueRx.value;
    if (queue.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    // ReorderableListView 允许 newIndex == length，表示插入到末尾之后
    if (newIndex < 0 || newIndex > queue.length) return;
    if (oldIndex == newIndex) return;

    // ReorderableListView 标准调整逻辑
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    print('[AudioHandler] 🔄 reorderQueue: $oldIndex -> $newIndex');

    final updatedQueue = List<TrackItem>.from(queue);
    final movedItem = updatedQueue.removeAt(oldIndex);
    updatedQueue.insert(newIndex, movedItem);
    currentQueue.queueRx.value = updatedQueue;

    // 保持当前正在播放的条目不变，只更新其索引
    final current = currentItem.value;
    if (current != null) {
      final newCurrentIndex = updatedQueue.indexWhere((t) => t.id == current.id);
      if (newCurrentIndex != -1) {
        currentIndex.value = newCurrentIndex;
        print('[AudioHandler] 📍 当前播放索引更新: $newCurrentIndex');
      }
    }

    // 打印队列顺序用于调试
    print('[AudioHandler] 📋 新队列顺序: ${updatedQueue.map((t) => t.mediaItem.title).toList()}');

    await onQueueChanged();
  }

  @override
  void onSourceError(
    TrackItem? item,
    int index,
    Object error,
    StackTrace stackTrace,
  ) {
    final media = item?.mediaItem;
    if (media != null && onPlaybackError != null) {
      onPlaybackError!(media, error, stackTrace);
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
