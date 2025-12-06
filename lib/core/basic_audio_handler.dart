/// BasicAudioHandler 兼容层
/// 模拟 namida 的 basic_audio_handler 包核心功能
/// 
/// 由于 basic_audio_handler 是私有包，这里提供最小化实现
/// 保证与 namida audio_handler.dart 的兼容性

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../storage/player_state_storage.dart';

/// 播放项基类（模拟 namida Playable）
abstract class Playable {
  String get id;
}

/// 响应式基类（模拟 namida Rx）
class RxBaseCore<T> {
  T _value;
  final _listeners = <VoidCallback>[];

  RxBaseCore(this._value);

  T get value => _value;
  set value(T newValue) {
    if (_value != newValue) {
      _value = newValue;
      _notifyListeners();
    }
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}

class Rxn<T> extends RxBaseCore<T?> {
  Rxn([T? initial]) : super(initial);
}

extension RxExt<T> on T {
  RxBaseCore<T> get obs => RxBaseCore<T>(this);
}

/// 队列包装器
class QueueWrapper<Q> {
  final RxBaseCore<List<Q>> queueRx = RxBaseCore<List<Q>>([]);
}

/// BasicAudioHandler 基类 - 模拟 namida 核心
abstract class BasicAudioHandler<Q extends Playable> extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  /// Just Audio 播放器实例
  final AudioPlayer player = AudioPlayer();

  /// 响应式状态
  final RxBaseCore<Q?> currentItem = RxBaseCore<Q?>(null);
  final RxBaseCore<int> currentIndex = RxBaseCore<int>(0);
  final RxBaseCore<bool> isPlaying = RxBaseCore<bool>(false);
  final RxBaseCore<bool> playWhenReady = RxBaseCore<bool>(true);
  final RxBaseCore<int> currentPositionMS = RxBaseCore<int>(0);
  final Rxn<Duration> currentItemDuration = Rxn<Duration>();

  /// 队列管理
  final QueueWrapper<Q> currentQueue = QueueWrapper<Q>();

  /// 响度增益
  double _loudnessGain = 1.0;
  double _userVolume = 1.0;

  /// 引擎级播放列表启用状态（具体行为由子类决定）
  bool enginePlaylistEnabled = false;

  /// 淡入淡出
  Timer? _fadeTimer;
  bool _isFading = false;
  int _fadeGeneration = 0; // 用于并发控制，避免旧淡入/淡出继续执行

  /// 定时器：更新播放位置
  Timer? _positionTimer; // UI更新定时器（200ms）
  Timer? _notificationTimer; // 通知栏更新定时器（1000ms）

  /// 通知栏位置更新回调（由子类实现）
  void onNotificationPositionUpdate(int positionMs) {
    // 子类可覆盖此方法用于通知栏歌词高亮
  }

  BasicAudioHandler() {
    _init();
  }

  void _init() {
    // 监听播放状态
    player.playingStream.listen((playing) {
      isPlaying.value = playing;
    });

    // 监听时长
    player.durationStream.listen((duration) {
      currentItemDuration.value = duration;
    });

    // 定时更新位置（UI用，200ms高刷新率）
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      currentPositionMS.value = player.position.inMilliseconds;
    });

    // 定时更新通知栏（1000ms低频，节省电量）
    _notificationTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      final positionMs = player.position.inMilliseconds;
      onNotificationPositionUpdate(positionMs);
    });

    // 监听播放完成
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        onSongComplete();
      }
    });
  }

  // ========== 播放控制（子类可覆盖）==========

  Future<void> onPlayRaw() async {
    await player.play();
  }

  Future<void> onPauseRaw() async {
    await player.pause();
  }

  @override
  Future<void> play() async {
    playWhenReady.value = true;
    await onPlayRaw();
  }

  @override
  Future<void> pause() async {
    playWhenReady.value = false;
    await onPauseRaw();
  }

  @override
  Future<void> stop() async {
    await player.stop();
    await player.seek(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    await _handleGaplessSkip();
    if (currentIndex.value < currentQueue.queueRx.value.length - 1) {
      await skipToQueueItem(currentIndex.value + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    await _handleGaplessSkip();
    if (currentIndex.value > 0) {
      await skipToQueueItem(currentIndex.value - 1);
    }
  }

  Future<void> _handleGaplessSkip() async {
    // 检查 Gapless 及淡出设置，决定切歌前的过渡策略
    try {
      final storage = await PlayerStateStorage.getInstance();
      final gaplessEnabled = storage.gaplessEnabled;
      final fadeOutMs = storage.fadeOutDurationMs;

      if (gaplessEnabled) {
        // 无缝模式：不做额外淡出，只停止当前淡入/淡出任务
        stopFade();
        print('[BasicAudioHandler] ✅ Gapless已启用，切歌前不额外淡出');
      } else {
        // 非无缝模式：如配置了淡出时长，则在切歌前淡出当前曲目
        if (fadeOutMs > 0) {
          print(
            '[BasicAudioHandler] 🎚️ Gapless已禁用，切歌前淡出: ${fadeOutMs}ms',
          );
          await fadeOut(fadeOutMs);
        } else {
          print(
            '[BasicAudioHandler] ⏸️ Gapless已禁用，但淡出时长为0，直接切歌',
          );
        }
      }
    } catch (e) {
      print('[BasicAudioHandler] ⚠️ 获取Gapless设置失败: $e');
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < currentQueue.queueRx.value.length) {
      currentIndex.value = index;
      currentItem.value = currentQueue.queueRx.value[index];
      await onItemPlay(
        currentQueue.queueRx.value[index],
        index,
        () => skipToNext(),
        null,
      );
    }
  }

  // ========== 队列管理 ==========

  /// 分配新队列
  Future<void> assignNewQueue({
    required int playAtIndex,
    required Iterable<Q> queue,
    bool shuffle = false,
    bool startPlaying = true,
  }) async {
    final newQueue = queue.toList();
    currentQueue.queueRx.value = newQueue;
    playWhenReady.value = startPlaying;

    // 尝试根据当前设置配置引擎级播放列表（若子类有实现）
    bool gaplessEnabled = false;
    try {
      final storage = await PlayerStateStorage.getInstance();
      gaplessEnabled = storage.gaplessEnabled;
    } catch (e) {
      debugPrint('[BasicAudioHandler] ⚠️ 获取 Gapless 设置失败用于引擎队列配置: $e');
    }
    await configureEnginePlaylist(
      queue: newQueue,
      initialIndex: playAtIndex,
      gaplessEnabled: gaplessEnabled,
    );

    if (playAtIndex >= 0 && playAtIndex < newQueue.length) {
      currentIndex.value = playAtIndex;
      currentItem.value = newQueue[playAtIndex];
      await onItemPlay(newQueue[playAtIndex], playAtIndex, () => skipToNext(), null);
    }

    await onQueueChanged();
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    // 子类实现
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    // 子类实现
  }

  /// 添加到队列
  Future<void> addToQueue(Q item) async {
    final queue = List<Q>.from(currentQueue.queueRx.value);
    queue.add(item);
    currentQueue.queueRx.value = queue;
    await onQueueChanged();
  }

  /// 从队列移除
  Future<void> removeFromQueue(int index) async {
    if (index >= 0 && index < currentQueue.queueRx.value.length) {
      final queue = List<Q>.from(currentQueue.queueRx.value);
      queue.removeAt(index);
      currentQueue.queueRx.value = queue;

      if (index < currentIndex.value) {
        currentIndex.value--;
      } else if (index == currentIndex.value && queue.isNotEmpty) {
        final newIndex = currentIndex.value >= queue.length
            ? queue.length - 1
            : currentIndex.value;
        await skipToQueueItem(newIndex);
      }

      await onQueueChanged();
    }
  }

  /// 插入到队列
  Future<void> insertInQueue(Q item, int index) async {
    final queue = List<Q>.from(currentQueue.queueRx.value);
    queue.insert(index.clamp(0, queue.length), item);
    currentQueue.queueRx.value = queue;
    await onQueueChanged();
  }

  /// 清空队列
  Future<void> clearQueue() async {
    currentQueue.queueRx.value = [];
    currentItem.value = null;
    currentIndex.value = 0;
    await stop();
    await onQueueChanged();
  }

  // ========== 音量和速度 ==========

  /// 设置用户音量（0.0-1.5）
  Future<void> setVolume(double volume) async {
    _userVolume = volume.clamp(0.0, 1.5);
    await _applyVolume();
  }

  /// 设置响度增益
  void setLoudnessGain(double gain) {
    _loudnessGain = gain.clamp(0.5, 2.0);
    _applyVolume();
  }

  /// 应用最终音量 = 用户音量 × 响度增益
  Future<void> _applyVolume() async {
    final finalVolume = (_userVolume * _loudnessGain).clamp(0.0, 1.0);
    await player.setVolume(finalVolume);
  }

  Future<void> setSpeed(double speed) async {
    await player.setSpeed(speed);
  }

  /// 供子类覆写：根据当前队列配置底层播放器的播放列表
  ///
  /// 默认实现不启用引擎级播放列表，仅作为扩展点。
  @protected
  Future<void> configureEnginePlaylist({
    required List<Q> queue,
    required int initialIndex,
    required bool gaplessEnabled,
  }) async {
    enginePlaylistEnabled = false;
    debugPrint(
      '[BasicAudioHandler] ⏭️ configureEnginePlaylist 基类实现：不启用引擎队列 '
      '(queue=${queue.length}, initial=$initialIndex, gapless=$gaplessEnabled)',
    );
  }

  /// 淡入（从0到目标音量）
  Future<void> fadeIn(int durationMs) async {
    if (durationMs <= 0) return;
    print('[BasicAudioHandler] 🎚️ 开始淡入: ${durationMs}ms');
    _fadeTimer?.cancel(); // 兼容旧实现，保留但不再使用定时器

    // 增加一代淡入任务，旧任务在下一步检查时自动失效
    _fadeGeneration++;
    final currentGeneration = _fadeGeneration;
    _isFading = true;

    final targetVolume = (_userVolume * _loudnessGain).clamp(0.0, 1.0);
    // 为避免播放起始瞬间突刺音量，先将实际输出音量归零
    await player.setVolume(0.0);

    // 动态步数：目标单步时长约 15ms，限制在 [10, 120] 步
    final estimatedSteps = (durationMs / 15).clamp(10, 120).round();
    final steps = estimatedSteps > 0 ? estimatedSteps : 10;
    final stepDurationMs = (durationMs / steps).clamp(1, durationMs).round();

    for (int i = 0; i <= steps; i++) {
      // 并发检查：若有新的淡入/淡出开始或被 stopFade() 终止，则立即退出
      if (!_isFading || _fadeGeneration != currentGeneration) {
        print('[BasicAudioHandler] ⏹️ 淡入被中断');
        return;
      }

      final t = i / steps;
      // 使用二次曲线，使初始段更平滑
      final curved = t * t;
      final volume = (targetVolume * curved).clamp(0.0, 1.0);
      await player.setVolume(volume);

      if (i < steps) {
        await Future.delayed(Duration(milliseconds: stepDurationMs));
      }
    }

    // 结束时确保到达目标音量
    await player.setVolume(targetVolume);
    _isFading = false;
    print('[BasicAudioHandler] ✅ 淡入完成');
  }

  /// 淡出（从当前音量到0）
  Future<void> fadeOut(int durationMs) async {
    if (durationMs <= 0) return;
    print('[BasicAudioHandler] 🎚️ 开始淡出: ${durationMs}ms');
    _fadeTimer?.cancel(); // 兼容旧实现，保留但不再使用定时器

    // 增加一代淡出任务，旧任务在下一步检查时自动失效
    _fadeGeneration++;
    final currentGeneration = _fadeGeneration;
    _isFading = true;

    final currentVolume = (_userVolume * _loudnessGain).clamp(0.0, 1.0);
    // 动态步数：目标单步时长约 15ms，限制在 [10, 120] 步
    final estimatedSteps = (durationMs / 15).clamp(10, 120).round();
    final steps = estimatedSteps > 0 ? estimatedSteps : 10;
    final stepDurationMs = (durationMs / steps).clamp(1, durationMs).round();

    for (int i = 0; i <= steps; i++) {
      // 并发检查：若有新的淡入/淡出开始或被 stopFade() 终止，则立即退出
      if (!_isFading || _fadeGeneration != currentGeneration) {
        print('[BasicAudioHandler] ⏹️ 淡出被中断');
        return;
      }

      final t = i / steps;
      // 使用二次曲线，使尾部更平滑
      final curved = t * t;
      final volume = (currentVolume * (1.0 - curved)).clamp(0.0, 1.0);
      await player.setVolume(volume);

      if (i < steps) {
        await Future.delayed(Duration(milliseconds: stepDurationMs));
      }
    }

    // 结束时确保完全静音
    await player.setVolume(0.0);
    _isFading = false;
    print('[BasicAudioHandler] ✅ 淡出完成');
  }

  /// 停止淡入淡出
  void stopFade() {
    if (_isFading) {
      print('[BasicAudioHandler] ⏹️ 停止淡入淡出（Gapless切换）');
    }
    _isFading = false;
    _fadeGeneration++; // 递增 generation，使当前/旧淡入淡出循环尽快退出
    _fadeTimer?.cancel();
  }

  // ========== 抽象方法：子类必须实现 ==========

  /// 播放项时调用
  Future<void> onItemPlay(
    Q item,
    int index,
    Function skipItem,
    dynamic preparedItemInfo,
  );

  /// 队列变化时调用
  Future<void> onQueueChanged() async {
    queue.add([]); // 更新系统队列
  }

  /// 歌曲播放完成
  void onSongComplete() {
    if (currentIndex.value < currentQueue.queueRx.value.length - 1) {
      skipToNext();
    }
  }

  /// 设置音频源（使用 URL 字符串）
  Future<Duration?> setSource(
    String? sourceUrl, {
    required Q? item,
    required int index,
    Duration? initialPosition,
    bool isFile = true,
    Map<String, String>? headers,
    AudioVideoSource? audioSource,
  }) async {
    try {
      final Duration? duration;
      if (audioSource != null) {
        duration = await player.setSource(
          audioSource,
          initialPosition: initialPosition,
        );
      } else if (sourceUrl != null && isFile) {
        // 本地文件：需要添加 file:// 前缀
        final uri = Uri.file(sourceUrl).toString();
        duration = await player.setUrl(uri, initialPosition: initialPosition);
      } else if (sourceUrl != null) {
        // 网络 URL：传递 headers 到 just_audio（修复 Bilibili 403 问题）
        duration = await player.setUrl(
          sourceUrl,
          headers: headers,
          initialPosition: initialPosition,
        );
        if (headers != null) {
          print('[BasicAudioHandler] 🔑 使用自定义 headers: ${headers.keys.join(", ")}');
        }
      } else {
        throw ArgumentError('Invalid audio source configuration');
      }
      return duration;
    } catch (e, stack) {
      print('[BasicAudioHandler] ❌ setSource 失败: $e');
      // 交由子类进行错误上报或额外处理（例如状态记录）
      onSourceError(item, index, e, stack);
      return null;
    }
  }

  /// 当底层播放器在设置音源时发生错误的回调钩子
  ///
  /// 默认不做任何事，子类可以重写以便将错误上报到上层（例如 UI 或状态管理）。
  @protected
  void onSourceError(
    Q? item,
    int index,
    Object error,
    StackTrace stackTrace,
  ) {
    // 默认实现为空
  }

  /// 变换 PlaybackEvent 为 PlaybackState
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
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: isPlaying.value,
      queueIndex: itemIndex,
    );
  }

  // ========== 资源清理 ==========

  Future<void> onDispose() async {
    _positionTimer?.cancel();
    _notificationTimer?.cancel();
    await player.dispose();
  }
}
