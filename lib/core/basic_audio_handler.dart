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

  /// 淡入淡出
  Timer? _fadeTimer;
  bool _isFading = false;

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
    // 检查Gapless设置，决定是否停止淡入淡出
    try {
      final storage = await PlayerStateStorage.getInstance();
      if (storage.gaplessEnabled) {
        stopFade();
        print('[BasicAudioHandler] ✅ Gapless已启用，停止淡入淡出');
      } else {
        print('[BasicAudioHandler] ⏸️ Gapless已禁用，保持淡入淡出');
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

  /// 淡入（从0到目标音量）
  Future<void> fadeIn(int durationMs) async {
    if (durationMs <= 0) return;
    print('[BasicAudioHandler] 🎚️ 开始淡入: ${durationMs}ms');
    _fadeTimer?.cancel();
    _isFading = true;

    final targetVolume = (_userVolume * _loudnessGain).clamp(0.0, 1.0);
    const steps = 20;
    final stepDuration = durationMs ~/ steps;

    for (int i = 0; i <= steps && _isFading; i++) {
      final volume = (targetVolume * i / steps).clamp(0.0, 1.0);
      await player.setVolume(volume);
      if (i < steps) await Future.delayed(Duration(milliseconds: stepDuration));
    }

    _isFading = false;
    print('[BasicAudioHandler] ✅ 淡入完成');
  }

  /// 淡出（从当前音量到0）
  Future<void> fadeOut(int durationMs) async {
    if (durationMs <= 0) return;
    print('[BasicAudioHandler] 🎚️ 开始淡出: ${durationMs}ms');
    _fadeTimer?.cancel();
    _isFading = true;

    final currentVolume = (_userVolume * _loudnessGain).clamp(0.0, 1.0);
    const steps = 20;
    final stepDuration = durationMs ~/ steps;

    for (int i = steps; i >= 0 && _isFading; i--) {
      final volume = (currentVolume * i / steps).clamp(0.0, 1.0);
      await player.setVolume(volume);
      if (i > 0) await Future.delayed(Duration(milliseconds: stepDuration));
    }

    _isFading = false;
    print('[BasicAudioHandler] ✅ 淡出完成');
  }

  /// 停止淡入淡出
  void stopFade() {
    if (_isFading) {
      print('[BasicAudioHandler] ⏹️ 停止淡入淡出（Gapless切换）');
    }
    _isFading = false;
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
    } catch (e) {
      print('[BasicAudioHandler] ❌ setSource 失败: $e');
      return null;
    }
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
