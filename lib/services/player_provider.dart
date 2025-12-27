import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:async';
import 'dart:math' as math;
import '../database/database.dart';
import '../storage/player_state_storage.dart';
import '../contants/app_contants.dart' show PlayMode;
import 'bilibili/stream_service.dart';
import 'bilibili/api_client.dart';
import 'bilibili/api_service.dart';
import 'bilibili/cookie_manager.dart';
import 'bilibili/audio_cache_service.dart';
import 'cache/bilibili_auto_cache_service.dart';
import 'cache/page_cache_service.dart';
import 'cache/album_art_cache_service.dart';
import '../models/bilibili/audio_quality.dart';
import '../models/bilibili/loudness_info.dart';
import 'package:drift/drift.dart';
import 'lyrics/lyric_service.dart';
import '../models/lyrics/lyric_models.dart';
import '../models/bilibili/video.dart' as bili_models;
import '../utils/lyric_parser.dart';
import 'audio_handler_service.dart';
import 'audio_source_registry.dart';
import 'lyrics_notification_service.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 播放器状态管理
/// 
/// 负责整合 AudioHandler 和应用业务逻辑
class PlayerProvider with ChangeNotifier, WidgetsBindingObserver {
  MottoAudioHandler? _audioHandler;

  bool _lifecycleObserverRegistered = false;

  PlayerStateStorage? playerState;
  late final BilibiliStreamService _bilibiliStreamService;
  late final BilibiliAudioCacheService _bilibiliAudioCacheService;
  late final BilibiliAutoCacheService _bilibiliAutoCacheService;
  late final BilibiliApiService _bilibiliApiService;
  late final CookieManager _cookieManager;
  
  Song? _currentSong;
  bool _isLoading = false;
  String? _errorMessage;

  double _volume = 1.0;
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  Duration _duration = Duration.zero;

  PlayMode _playMode = PlayMode.loop;

  // 细粒度状态通知器（供 UI 精准监听）
  final ValueNotifier<Song?> currentSongNotifier = ValueNotifier<Song?>(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<Song>> playlistNotifier =
      ValueNotifier<List<Song>>(<Song>[]);

  // ==================== 睡眠定时（Sleep Timer） ====================
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndAt;
  String? _sleepTimerBoundTrackKey; // 仅用于“播放完当前歌曲”
  bool _sleepTimerUntilEndOfTrack = false;

  /// 剩余时间（null 表示未开启）
  final ValueNotifier<Duration?> sleepTimerRemainingNotifier =
      ValueNotifier<Duration?>(null);

  bool get isSleepTimerActive => sleepTimerRemainingNotifier.value != null;

  // 索引映射架构：单一歌曲列表 + 播放顺序索引
  List<Song> _songs = [];
  List<int> _playOrder = [];
  int _currentOrderIndex = 0;

  final math.Random _random = math.Random();
  final PageCacheService _pageCache = PageCacheService();
  final Set<String> _lockCachingInProgress = {}; // 防止同一首歌重复创建 LockCachingAudioSource
  Directory? _notificationArtCacheDir;
  Directory? _coverCacheDir;

  // 歌词相关状态
  ParsedLrc? _currentLyrics;
  bool _isLoadingLyrics = false;
  String? _lyricsError;
  int _currentLyricLineIndex = -1;  // 当前歌词行索引
  bool _lyricsNotificationEnabled = false;
  bool _lockScreenEnabled = false;
  int _lyricsLoadGeneration = 0; // 用于取消旧歌词请求回流

  StreamSubscription? _positionSub;
  StreamSubscription? _playbackStateSub;

  // 最近一次播放失败状态（用于状态记录与后续网络恢复策略）
  Song? _lastPlaybackFailedSong;
  bool _lastPlaybackFailedNetworkRelated = false;
  DateTime? _lastPlaybackFailedAt;

  // 通知栏歌词服务
  final LyricsNotificationService _lyricsNotificationService = LyricsNotificationService();

  String _trackKeyForSong(Song? song) {
    if (song == null) return '';
    // 数据库正式歌曲：id 稳定且唯一
    if (song.id > 0) return song.id.toString();
    // 临时/在线歌曲：使用 bvid + cid/pageNumber 组合兜底
    final bvid = song.bvid;
    if (bvid != null && bvid.isNotEmpty) {
      final cidPart =
          (song.cid != null && song.cid! > 0) ? song.cid.toString() : '0';
      final pagePart = (song.pageNumber != null && song.pageNumber! > 0)
          ? song.pageNumber.toString()
          : '0';
      return 'bilibili:$bvid:$cidPart:$pagePart';
    }
    // 最后兜底：保持与现有逻辑兼容（可能为负数）
    return song.id.toString();
  }

  // Getters
  Song? get currentSong => _currentSong;
  bool get isPlaying => _audioHandler?.playing ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ValueNotifier<Duration> get position => _position;
  Duration get duration => _duration;
  PlayMode get playMode => _playMode;
  // 返回可修改的副本，避免外部直接修改内部状态
  List<Song> get playlist {
    if (_songs.isEmpty || _playOrder.isEmpty) {
      return const [];
    }
    // 基于索引映射生成当前播放顺序视图
    return _playOrder
        .where((i) => i >= 0 && i < _songs.length)
        .map((i) => _songs[i])
        .toList();
  }

  /// 当前歌曲在播放队列中的索引（与 [playlist] 对齐）
  int get currentIndex {
    if (_playOrder.isEmpty) return -1;
    return _currentOrderIndex.clamp(0, _playOrder.length - 1) as int;
  }
  double get volume => _volume;

  // 最近一次播放失败信息（暂未在 UI 中使用，但用于后续扩展）
  Song? get lastPlaybackFailedSong => _lastPlaybackFailedSong;
  bool get lastPlaybackFailedNetworkRelated => _lastPlaybackFailedNetworkRelated;
  DateTime? get lastPlaybackFailedAt => _lastPlaybackFailedAt;

  // 歌词相关 Getters
  ParsedLrc? get currentLyrics => _currentLyrics;
  bool get isLoadingLyrics => _isLoadingLyrics;
  String? get lyricsError => _lyricsError;
  bool get lyricsNotificationEnabled => _lyricsNotificationEnabled;
  bool get lockScreenEnabled => _lockScreenEnabled;

  void _updateCurrentSongNotifier() {
    currentSongNotifier.value = _currentSong;
  }

  void _updatePlaylistNotifier() {
    // 为避免在语义树刷新过程中同步修改列表导致的断言问题，
    // 将播放列表的可见更新推迟到当前帧结束后执行。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      playlistNotifier.value = List<Song>.from(playlist);
      debugPrint(
        '[PlayerProvider] 🎵 playlistNotifier 更新: 长度=${playlistNotifier.value.length}, '
        '_songs=${_songs.length}, _playOrder=$_playOrder',
      );
    });
  }

  bool get hasPrevious {
    if (_playMode == PlayMode.shuffle) return true;
    return _playOrder.isNotEmpty && _currentOrderIndex > 0;
  }

  bool get hasNext {
    if (_playMode == PlayMode.shuffle) return true;
    return _playOrder.isNotEmpty &&
        _currentOrderIndex < _playOrder.length - 1;
  }

  static final Set<VoidCallback> _songChangeListeners = <VoidCallback>{};

  static void addSongChangeListener(VoidCallback listener) {
    _songChangeListeners.add(listener);
  }

  static void removeSongChangeListener(VoidCallback listener) {
    _songChangeListeners.remove(listener);
  }

  static void _notifySongChange() {
    for (final listener in List<VoidCallback>.from(_songChangeListeners)) {
      try {
        listener();
      } catch (e, stackTrace) {
        debugPrint('[PlayerProvider] 通知最近播放数据时出错: $e');
        debugPrint(stackTrace.toString());
      }
    }
  }

  // AudioHandler 初始化
  Future<void> initWithAudioHandler(MottoAudioHandler? handler) async {
    _audioHandler = handler;

    if (!_lifecycleObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverRegistered = true;
    }

    // 初始化 Bilibili 相关服务
    final cookieManager = CookieManager();
    _cookieManager = cookieManager;
    final apiClient = BilibiliApiClient(cookieManager);
    _bilibiliStreamService = BilibiliStreamService(apiClient);
    _bilibiliApiService = BilibiliApiService(apiClient);
    _bilibiliAudioCacheService = BilibiliAudioCacheService(
      MusicDatabase.database,
      _bilibiliStreamService,
    );

    // 初始化自动缓存服务（方案B - 自动缓存层）
    _bilibiliAutoCacheService = await BilibiliAutoCacheService.getInstance(
      streamService: _bilibiliStreamService,
      cookieManager: cookieManager,
    );

    debugPrint('[PlayerProvider] ✅ Bilibili 双层缓存服务已初始化');

    // 设置懒加载解析回调
    if (_audioHandler != null) {
      _audioHandler!.onLazyResolve = _resolveLazyMediaItem;
      _audioHandler!.onPlaybackError = _handlePlaybackError;
      debugPrint('[PlayerProvider] ✅ 懒加载解析与播放失败回调已设置');
    }

    _initializeListeners();
    await _restoreState();
    await _restoreSleepTimerFromStorage();
    _migrateAlbumArtCache();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // 目标：退后台/恢复后仍按 endAt 计算剩余时间；若已到点则立刻暂停
    final endAt = _sleepTimerEndAt;
    if (endAt == null) {
      if (playerState != null && playerState!.sleepTimerEndAtEpochMs != null) {
        unawaited(_restoreSleepTimerFromStorage());
      }
      return;
    }

    final remaining = endAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      debugPrint('[SleepTimer] ⏰ 应用恢复时已到点，执行暂停并清理');
      unawaited(pause());
      cancelSleepTimer();
      return;
    }

    sleepTimerRemainingNotifier.value = remaining;
    debugPrint('[SleepTimer] 🔄 应用恢复，剩余 ${remaining.inSeconds}s');
  }

  /// 懒加载解析回调：根据 MediaItem 中的信息解析音频源
  Future<(String?, Map<String, String>?, bool)?> _resolveLazyMediaItem(
    MediaItem item,
  ) async {
    debugPrint('[PlayerProvider] 🔄 懒加载解析: ${item.title}');

    try {
      // 从 extras 中获取歌曲信息
      final songId = item.extras?['songId'] as int? ?? -1;
      final source = item.extras?['source'] as String? ?? 'local';
      final filePath = item.extras?['filePath'] as String? ?? '';
      final bvid = item.extras?['bvid'] as String? ?? '';
      final cid = item.extras?['cid'] as int? ?? 0;
      final pageNumber = item.extras?['pageNumber'] as int?;
      final bilibiliVideoId = item.extras?['bilibiliVideoId'] as int?;

      // 本地文件：直接返回文件路径
      if (source != 'bilibili' && filePath.isNotEmpty) {
        debugPrint('[PlayerProvider] ✅ 懒加载解析完成（本地文件）: $filePath');
        return (filePath, null, true);
      }

      // Bilibili 音频：需要解析流 URL
      if (source == 'bilibili' && bvid.isNotEmpty) {
        // 尝试从播放列表中找到对应的 Song 对象
        Song? song;
        final now = DateTime.now();
        final fallbackSong = Song(
          id: songId > 0 ? songId : -1,
          title: item.title,
          artist: item.artist,
          filePath: '',
          source: 'bilibili',
          bvid: bvid,
          cid: cid > 0 ? cid : null,
          pageNumber: pageNumber,
          bilibiliVideoId: bilibiliVideoId,
          dateAdded: now,
          isFavorite: false,
          lastPlayedTime: now,
          playedCount: 0,
        );

        final currentList = playlist;
        if (songId > 0) {
          song = currentList.firstWhere(
            (s) => s.id == songId,
            orElse: () => currentList.firstWhere(
              (s) => s.bvid == bvid && (s.cid == cid || cid == 0),
              orElse: () => fallbackSong,
            ),
          );
        } else {
          song = currentList.firstWhere(
            (s) => s.bvid == bvid && (s.cid == cid || cid == 0),
            orElse: () => fallbackSong,
          );
        }

        // 解析音频源
        final resolved = await _resolveAudioSource(song);
        if (resolved.path != null) {
          final pathPreview = resolved.path!.length > 50
              ? '${resolved.path!.substring(0, 50)}...'
              : resolved.path!;
          debugPrint('[PlayerProvider] ✅ 懒加载解析完成（Bilibili）: $pathPreview');
          return (resolved.path, resolved.headers, resolved.type == 'file');
        }
      }

      debugPrint('[PlayerProvider] ❌ 懒加载解析失败: 无法获取音频源');
      return null;
    } catch (e, stack) {
      debugPrint('[PlayerProvider] ❌ 懒加载解析异常: $e');
      debugPrint(stack.toString());
      return null;
    }
  }

  void _initializeListeners() {
    // 只在有 audioHandler 时设置监听
    if (_audioHandler == null) return;

    // 初始化通知栏歌词服务
    _lyricsNotificationService.init();

    // 监听播放位置
    _positionSub = Stream.periodic(
      const Duration(milliseconds: 200),
      (_) => _audioHandler!.position,
    ).listen((pos) {
      _position.value = pos;
      if (_audioHandler!.duration != null) {
        _duration = _audioHandler!.duration!;
      }

      // 实时更新通知栏歌词（根据播放位置）
      _updateNotificationLyrics(pos);
    });

    // ⭐ 监听队列索引变化（关键修复：自动切歌时更新界面）
    _audioHandler!.currentIndex.addListener(() {
      debugPrint('[PlayerProvider] 🔄 队列索引变化: ${_audioHandler!.currentIndex.value}');

      // 若启用了“播放完当前歌曲”睡眠定时，切歌时自动取消，避免误暂停下一首
      if (_sleepTimerUntilEndOfTrack) {
        debugPrint('[SleepTimer] ℹ️ 队列索引变化，自动取消“到曲末”睡眠定时');
        cancelSleepTimer();
      }
      _updateCurrentSongFromHandler();
      _notifySongChange();
    });

    // 监听播放状态变化
    _playbackStateSub = _audioHandler!.playbackState.listen((state) {
      _lyricsNotificationService.updatePlayState(state.playing);
      isPlayingNotifier.value = state.playing;
      notifyListeners();

      // 检测播放完成
      if (state.processingState == AudioProcessingState.completed) {
        _onSongComplete();
      }
    });
  }

  Future<void> _restoreState() async {
    playerState = await PlayerStateStorage.getInstance();
    _currentSong = playerState?.currentSong;
    final restoredPlaylist = playerState?.playlist;
    // 索引映射模式下，同步初始化 _songs/_playOrder/_currentOrderIndex
    _songs = restoredPlaylist != null ? List.from(restoredPlaylist) : [];
    _playOrder = List.generate(_songs.length, (i) => i);
    if (_currentSong != null && _songs.isNotEmpty) {
      final idx = _songs.indexWhere((s) => s.id == _currentSong!.id);
      _currentOrderIndex = idx >= 0 ? idx : 0;
    } else {
      _currentOrderIndex = 0;
    }
    _volume = playerState?.volume ?? 1.0;
    _playMode = playerState?.playMode ?? PlayMode.loop;
    _position.value = playerState?.position ?? Duration.zero;
    _lyricsNotificationEnabled =
        playerState?.lyricsNotificationEnabled ?? false;
    _lockScreenEnabled =
        playerState?.lockScreenEnabled ?? false;
    await _lyricsNotificationService.setNotificationEnabled(_lyricsNotificationEnabled);
    await _lyricsNotificationService.setLockScreenEnabled(_lockScreenEnabled);
    
    if (_currentSong != null && restoredPlaylist != null && restoredPlaylist.isNotEmpty) {
      // 使用索引映射还原队列与当前索引
      final playlistForHandler = _playOrder
          .where((i) => i >= 0 && i < _songs.length)
          .map((i) => _songs[i])
          .toList(growable: false);
      final initialIndex = _currentOrderIndex.clamp(
        0,
        playlistForHandler.isEmpty ? 0 : playlistForHandler.length - 1,
      );
      await _setPlaylistToHandler(playlistForHandler, initialIndex: initialIndex);
    }
    
    await _audioHandler?.setVolume(_volume);
    if (_currentSong != null) {
      _lyricsNotificationService.updateMetadata(
        title: _currentSong!.title,
        artist: _currentSong!.artist,
        songId: _trackKeyForSong(_currentSong),
      );
    }
    _updateCurrentSongNotifier();
    _updatePlaylistNotifier();
    notifyListeners();
  }

  Future<void> setLyricsNotificationEnabled(bool enabled) async {
    if (_lyricsNotificationEnabled == enabled) return;
    _lyricsNotificationEnabled = enabled;
    await _lyricsNotificationService.setNotificationEnabled(enabled);
    if (playerState != null) {
      await playerState!.setLyricsNotificationEnabled(enabled);
    }
    notifyListeners();
  }

  Future<void> setLockScreenEnabled(bool enabled) async {
    if (_lockScreenEnabled == enabled) return;
    _lockScreenEnabled = enabled;
    await _lyricsNotificationService.setLockScreenEnabled(enabled);
    if (playerState != null) {
      await playerState!.setLockScreenEnabled(enabled);
    }
    if (enabled) {
      final trackKey = _trackKeyForSong(_currentSong);
      _lyricsNotificationService.updateMetadata(
        title: _currentSong?.title,
        artist: _currentSong?.artist,
        songId: trackKey.isEmpty ? null : trackKey,
      );
      // 若已有歌词，立刻下发全量歌词，避免锁屏首次进入为空
      final lyricsLines = _currentLyrics?.lyrics;
      if (lyricsLines != null) {
        final allLyricsData = lyricsLines.map((line) {
          List<Map<String, dynamic>>? charTimestampsMap;
          if (line.charTimestamps != null) {
            charTimestampsMap = line.charTimestamps!.map((ct) {
              return {
                'char': ct.char,
                'startMs': ct.startMs.toInt(),
                'endMs': ct.endMs.toInt(),
              };
            }).toList();
          }

          return {
            'text': line.text,
            'startMs': (line.timestamp * 1000).toInt(),
            'endMs': (line.timestamp * 1000 + 5000).toInt(),
            'charTimestamps': charTimestampsMap,
          };
        }).toList();

        await _lyricsNotificationService.updateAllLyrics(
          lyrics: allLyricsData,
          currentIndex: -1,
          songId: trackKey.isEmpty ? null : trackKey,
        );
      }
      _currentLyricLineIndex = -1;
      _updateNotificationLyrics(_position.value);
    }
    notifyListeners();
  }

  int get fadeInDurationMs => playerState?.fadeInDurationMs ?? 500;
  int get fadeOutDurationMs => playerState?.fadeOutDurationMs ?? 500;
  bool get gaplessEnabled => playerState?.gaplessEnabled ?? true;

  Future<void> setFadeInDuration(int durationMs) async {
    await playerState?.setFadeInDuration(durationMs);
    notifyListeners();
  }

  Future<void> setFadeOutDuration(int durationMs) async {
    await playerState?.setFadeOutDuration(durationMs);
    notifyListeners();
  }

  Future<void> setGaplessEnabled(bool enabled) async {
    await playerState?.setGaplessEnabled(enabled);
    notifyListeners();
  }

  void _handlePlaybackError(
    MediaItem mediaItem,
    Object error,
    StackTrace stackTrace,
  ) {
    // 关联到 Song（如果 extras 中带有 songId）
    Song? song;
    final extras = mediaItem.extras ?? const <String, dynamic>{};
    final songId = extras['songId'] as int?;
    if (songId != null && songId > 0) {
      final currentList = playlist;
      final index = currentList.indexWhere((s) => s.id == songId);
      if (index != -1) {
        song = currentList[index];
      } else if (_currentSong != null && _currentSong!.id == songId) {
        song = _currentSong;
      }
    }

    final sourceType = extras['sourceType'] as String?;
    final errorText = error.toString();

    final isNetworkLikeSource =
        sourceType == 'url' || sourceType == 'lock_caching';
    final isLikelyNetworkError = isNetworkLikeSource &&
        (errorText.contains('SocketException') ||
            errorText.contains('Failed host lookup') ||
            errorText.contains('Connection reset') ||
            errorText.contains('timed out'));

    _lastPlaybackFailedSong = song;
    _lastPlaybackFailedNetworkRelated = isLikelyNetworkError;
    _lastPlaybackFailedAt = DateTime.now();

    final title = song?.title ?? mediaItem.title;
    if (isLikelyNetworkError) {
      _errorMessage = '网络问题导致无法播放: $title';
    } else {
      _errorMessage = '无法播放: $title (${error.runtimeType})';
    }

    debugPrint('[PlayerProvider] ❌ 播放失败: $_errorMessage');
    debugPrint(stackTrace.toString());
    notifyListeners();
  }

  /// 设置播放列表到 AudioHandler
  ///
  /// 采用懒加载策略：只为当前要播放的歌曲解析音频源，
  /// 其他歌曲使用轻量级元数据，在实际播放时再解析。
  Future<void> _setPlaylistToHandler(
    List<Song> songs, {
    int initialIndex = 0,
  }) async {
    if (_audioHandler == null) {
      debugPrint('[播放调试] ❌ AudioHandler 为 null，无法设置播放列表');
      return;
    }

    debugPrint('[播放调试] 🔄 懒加载模式：转换 ${songs.length} 首歌曲为 MediaItem...');
    final mediaItems = <MediaItem>[];

    // 只为当前歌曲完整解析，其他歌曲使用轻量级元数据
    for (var i = 0; i < songs.length; i++) {
      final song = songs[i];
      final isInitial = i == initialIndex;

      if (isInitial) {
        // 当前要播放的歌曲：完整解析音频源
        mediaItems.add(await _convertSongToMediaItem(song));
      } else {
        // 其他歌曲：只设置元数据，标记需要延迟解析
        mediaItems.add(_convertSongToMediaItemLazy(song));
      }
    }

    debugPrint('[播放调试] ✅ MediaItem 转换完成（仅解析当前歌曲），设置到 AudioHandler');
    await _audioHandler!.setPlaylist(mediaItems, initialIndex: initialIndex);
    debugPrint('[播放调试] ✅ 播放列表已设置到 AudioHandler');
  }

  /// 轻量级转换：只设置元数据，不解析音频源
  ///
  /// 用于播放列表中非当前播放的歌曲，避免批量 API 请求
  ///
  /// 懒加载策略：
  /// - 元数据：立即设置（标题、艺术家、封面URI）
  /// - 音频源：延迟解析（标记 needsResolve=true）
  /// - 封面处理：
  ///   * 网络URL → Uri.parse() 直接使用
  ///   * 本地文件 → Uri.file() 转换为 file:// URI
  ///   * 空路径 → artUri = null（显示默认图标）
  ///
  /// 播放时机：
  /// - 当用户切换到该歌曲时，AudioHandler 会触发 onLazyResolve
  /// - 此时才调用 _convertSongToMediaItem 完整解析音频源
  MediaItem _convertSongToMediaItemLazy(Song song) {
    // 构建封面 URI（支持网络 URL 和本地文件）
    Uri? artUri;
    if (song.albumArtPath != null && song.albumArtPath!.isNotEmpty) {
      final path = song.albumArtPath!;
      if (path.startsWith('http://') || path.startsWith('https://')) {
        // 网络 URL：直接使用
        artUri = Uri.parse(path);
      } else {
        // 本地文件：使用 file:// URI
        // MediaMetadata 会自动处理 file:// 协议
        artUri = Uri.file(path);
      }
    }

    // 标记需要延迟解析
    final extras = <String, dynamic>{
      'sourceType': 'lazy', // 标记为懒加载
      'needsResolve': true, // 需要在播放时解析
      'songId': song.id,
      'bvid': song.bvid ?? '',
      'cid': song.cid ?? 0,
      'source': song.source,
      'filePath': song.filePath,
      'pageNumber': song.pageNumber,
      'bilibiliVideoId': song.bilibiliVideoId,
    };

    return MediaItem(
      id: song.id.toString(),
      title: song.title,
      artist: song.artist ?? '未知艺术家',
      album: song.album ?? '',
      duration: Duration(seconds: song.duration ?? 0),
      artUri: artUri,
      extras: extras,
    );
  }

  /// 将 Song 转换为 MediaItem
  Future<MediaItem> _convertSongToMediaItem(Song song) async {
    final resolvedSong = await _ensureLocalAlbumArt(song);
    // 构建封面 URI
    Uri? artUri;
    if (resolvedSong.albumArtPath != null &&
        resolvedSong.albumArtPath!.isNotEmpty) {
      artUri = await _buildNotificationArtUri(resolvedSong.albumArtPath!);
    }

    final resolvedSource = await _resolveAudioSource(resolvedSong);
    final sourceType = resolvedSource.type;
    final headers = resolvedSource.headers;

    final extras = <String, dynamic>{
      'sourceType': sourceType,
      if (resolvedSource.path != null) 'sourcePath': resolvedSource.path,
      if (headers != null) 'headers': headers,
      if (resolvedSource.loudness != null) 'loudness': resolvedSource.loudness!.toJson(),
      'songId': resolvedSong.id,
      'bvid': resolvedSong.bvid ?? '',
      'cid': resolvedSong.cid ?? 0,
    };

    return MediaItem(
      id: resolvedSong.id.toString(),
      title: resolvedSong.title,
      artist: resolvedSong.artist ?? '未知艺术家',
      album: resolvedSong.album ?? '',
      duration: Duration(seconds: resolvedSong.duration ?? 0),
      artUri: artUri,
      extras: extras,
    );
  }

  Future<Uri?> _buildNotificationArtUri(String rawPath) async {
    final cacheDir = await _ensureNotificationArtCacheDir();
    final digest = sha1.convert(utf8.encode(rawPath)).toString();
    final cachedFile = File('${cacheDir.path}/$digest.png');

    if (await cachedFile.exists()) {
      return Uri.file(cachedFile.path);
    }

    try {
      final bytes = await _loadArtworkBytes(rawPath);
      if (bytes == null || bytes.isEmpty) {
        return _fallbackArtUri(rawPath);
      }

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return _fallbackArtUri(rawPath);
      }

      final minSide = math.min(decoded.width, decoded.height);
      img.Image square = decoded;
      if (decoded.width != decoded.height) {
        final cropX = ((decoded.width - minSide) / 2).round();
        final cropY = ((decoded.height - minSide) / 2).round();
        square = img.copyCrop(
          decoded,
          x: cropX,
          y: cropY,
          width: minSide,
          height: minSide,
        );
      }

      if (minSide > 512) {
        square = img.copyResize(
          square,
          width: 512,
          height: 512,
          interpolation: img.Interpolation.cubic,
        );
      }

      await cachedFile.create(recursive: true);
      await cachedFile.writeAsBytes(img.encodePng(square));
      return Uri.file(cachedFile.path);
    } catch (e, stackTrace) {
      debugPrint('[PlayerProvider] 通知封面处理失败: $e');
      debugPrint(stackTrace.toString());
      return _fallbackArtUri(rawPath);
    }
  }

  Future<Directory> _ensureNotificationArtCacheDir() async {
    if (_notificationArtCacheDir != null &&
        await _notificationArtCacheDir!.exists()) {
      return _notificationArtCacheDir!;
    }
    final baseDir = await getTemporaryDirectory();
    final dir = Directory('${baseDir.path}/notification_art');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _notificationArtCacheDir = dir;
    return dir;
  }

  Future<Uint8List?> _loadArtworkBytes(String rawPath) async {
    try {
      if (rawPath.startsWith('http')) {
        final uri = Uri.parse(rawPath);
        final client = HttpClient();
        try {
          final request = await client.getUrl(uri);

          // ⭐ 关键修复：为Bilibili CDN添加必要的请求头
          if (uri.host.contains('hdslb.com') || uri.host.contains('bilibili.com')) {
            debugPrint('[PlayerProvider] 🔧 检测到Bilibili CDN，添加请求头');
            request.headers.set('Referer', 'https://www.bilibili.com');
            request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
            request.headers.set('Accept', 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8');

            // 如果有Cookie，也添加上
            final cookie = await _cookieManager.getCookieString();
            if (cookie.isNotEmpty) {
              request.headers.set('Cookie', cookie);
            }
          }

          final response = await request.close();
          debugPrint('[PlayerProvider] 封面请求响应: ${response.statusCode} - $rawPath');

          if (response.statusCode == HttpStatus.ok) {
            final bytes = await consolidateHttpClientResponseBytes(response);
            debugPrint('[PlayerProvider] ✅ 封面加载成功: ${bytes.length} bytes');
            return bytes;
          } else {
            debugPrint('[PlayerProvider] ❌ 封面请求失败: HTTP ${response.statusCode}');
          }
        } finally {
          client.close(force: true);
        }
        return null;
      }

      final file = File(rawPath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e, stackTrace) {
      debugPrint('[PlayerProvider] ❌ 加载封面失败: $e');
      debugPrint(stackTrace.toString());
    }
    return null;
  }

  Uri? _fallbackArtUri(String rawPath) {
    if (rawPath.startsWith('http')) {
      try {
        return Uri.parse(rawPath);
      } catch (_) {
        return null;
      }
    }

    final file = File(rawPath);
    if (file.existsSync()) {
      return Uri.file(file.path);
    }
    return null;
  }

  Future<_ResolvedAudioSource> _resolveAudioSource(Song song) async {
    if (song.source == 'bilibili') {
      final biliSource = await _resolveBilibiliAudioSource(song);
      if (biliSource != null) {
        return biliSource;
      }
      debugPrint(
        '[播放调试] ⚠️ 无法解析 Bilibili 音频源，尝试使用本地文件: ${song.title}',
      );
    }

    if (song.filePath.isEmpty) {
      throw Exception('歌曲 ${song.title} 缺少可用音频路径');
    }
    return _ResolvedAudioSource.file(song.filePath);
  }

  Future<_ResolvedAudioSource?> _resolveBilibiliAudioSource(Song song) async {
    final bvid = song.bvid;
    if (bvid == null || bvid.isEmpty) {
      return null;
    }

    final cid = await _resolveBilibiliCid(song, bvid);
    if (cid == null) {
      debugPrint('[播放调试] ⚠️ 无法获取 ${song.title} 的 CID');
      return null;
    }

    // 获取用户设置的默认播放音质
    final storage = await PlayerStateStorage.getInstance();
    final defaultQualityId = storage.defaultBilibiliPlayQuality;
    final playQuality = BilibiliAudioQuality.fromId(defaultQualityId);

    debugPrint('[播放调试] 🎵 解析 Bilibili 音频源: ${song.title}');
    debugPrint('[播放调试]    默认音质: ${playQuality.displayName}');

    try {
      // ========== 优先级1: 检查手动下载（最高音质） ==========
      final downloadedPath = await _bilibiliAudioCacheService.getCachedAudioPath(
        bvid: bvid,
        cid: cid,
        quality: playQuality,
      ).timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (downloadedPath != null && downloadedPath.isNotEmpty) {
        debugPrint('[播放调试] ✅ 使用手动下载: $downloadedPath');

        // 优先从数据库读取响度信息
        final loudness = _getLoudnessFromSong(song);
        if (loudness != null) {
          debugPrint('[播放调试] ✅ 从数据库读取响度信息');
          return _ResolvedAudioSource._('file', downloadedPath, null, loudness);
        }

        // 数据库无响度，从 API 获取并保存
        try {
          final streamInfo = await _bilibiliStreamService.getAudioStream(
            bvid: bvid,
            cid: cid,
            quality: playQuality,
          ).timeout(const Duration(seconds: 3));

          if (streamInfo.loudness != null) {
            await _saveLoudnessToDatabase(song.id, streamInfo.loudness!);
          }

          return _ResolvedAudioSource._('file', downloadedPath, null, streamInfo.loudness);
        } catch (e) {
          debugPrint('[播放调试] ⚠️ 获取响度信息失败: $e');
          return _ResolvedAudioSource.file(downloadedPath);
        }
      }

      // ========== 优先级2: LockCaching 缓存文件命中 ==========
      final cachedFile = await _bilibiliAutoCacheService.getCachedAudioFile(
        bvid: bvid,
        cid: cid,
        quality: playQuality,
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (cachedFile != null) {
        debugPrint('[播放调试] ✅ 自动缓存命中: ${cachedFile.path}');

        // 优先从数据库读取响度信息
        final loudness = _getLoudnessFromSong(song);
        if (loudness != null) {
          debugPrint('[播放调试] ✅ 从数据库读取响度信息');
          return _ResolvedAudioSource._('file', cachedFile.path, null, loudness);
        }

        // 数据库无响度，从 API 获取并保存
        try {
          final streamInfo = await _bilibiliStreamService.getAudioStream(
            bvid: bvid,
            cid: cid,
            quality: playQuality,
          ).timeout(const Duration(seconds: 3));

          if (streamInfo.loudness != null) {
            await _saveLoudnessToDatabase(song.id, streamInfo.loudness!);
          }

          return _ResolvedAudioSource._('file', cachedFile.path, null, streamInfo.loudness);
        } catch (e) {
          debugPrint('[播放调试] ⚠️ 获取响度信息失败: $e');
          return _ResolvedAudioSource.file(cachedFile.path);
        }
      }

      // ========== 优先级3: 使用 LockCachingAudioSource 播放并自动缓存 ==========
      final sourceId = 'bilibili_${bvid}_${cid}_${playQuality.id}';
      
      // 防止重复创建
      if (_lockCachingInProgress.contains(sourceId)) {
        debugPrint('[播放调试] ⏳ LockCachingAudioSource 正在创建中，等待...');
        await Future.delayed(const Duration(milliseconds: 100));
        return _resolveBilibiliAudioSource(song);
      }

      _lockCachingInProgress.add(sourceId);
      try {
        debugPrint('[播放调试] 🔄 创建 LockCachingAudioSource 进行播放和缓存');

        final lockCachingSource = await _bilibiliAutoCacheService.createLockCachingAudioSource(
          bvid: bvid,
          cid: cid,
          quality: playQuality,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('创建缓存音频源超时'),
        );

        AudioSourceRegistry.register(sourceId, lockCachingSource);

        debugPrint('[播放调试] ✅ LockCachingAudioSource 已注册: $sourceId');

        // 获取响度信息（createLockCachingAudioSource 内部已调用 getAudioStream）
        // 这里需要从 service 缓存或重新获取
        final streamInfo = await _bilibiliStreamService.getAudioStream(
          bvid: bvid,
          cid: cid,
          quality: playQuality,
        );

        return _ResolvedAudioSource.lockCaching(sourceId, loudness: streamInfo.loudness);
      } finally {
        _lockCachingInProgress.remove(sourceId);
      }
    } catch (e, stackTrace) {
      debugPrint('[播放调试] ❌ 解析音频源失败: $e');
      debugPrint('[播放调试] 堆栈: $stackTrace');
      return null;
    }
  }

  Future<List<bili_models.BilibiliVideoPage>> _getVideoPagesWithCache(
    String bvid,
  ) async {
    final cached = await _pageCache.getCachedVideoPages(bvid);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final fetched = await _bilibiliApiService.getVideoPages(bvid);
    if (fetched.isNotEmpty) {
      await _pageCache.cacheVideoPages(bvid, fetched);
    }
    return fetched;
  }

  Future<Song> _ensureLocalAlbumArt(
    Song song, {
    bool updateState = true,
  }) async {
    final artPath = song.albumArtPath;
    if (artPath == null || artPath.isEmpty) {
      return song;
    }

    // 仅在封面 URL 确认属于 B 站域名（bilibili.com / hdslb.com）时，才去取 Cookie，
    // 避免对非 B 站封面做多余的 Cookie 获取。
    String? cookie;
    if (AlbumArtCacheService.isBilibiliImageUrl(artPath)) {
      final rawCookie = await _cookieManager.getCookieString();
      if (rawCookie.isNotEmpty) {
        cookie = rawCookie;
      }
    }

    final localPath = await AlbumArtCacheService.instance
        .ensureLocalPath(artPath, cookie: cookie);
    if (localPath == null ||
        localPath.isEmpty ||
        localPath == artPath) {
      return song;
    }

    final updatedSong = song.copyWith(albumArtPath: Value(localPath));
    if (updateState) {
      await _applyAlbumArtUpdate(song, updatedSong);
    } else if (song.id > 0) {
      await MusicDatabase.database.updateSong(updatedSong);
    }
    return updatedSong;
  }

  Future<void> _applyAlbumArtUpdate(Song original, Song updated) async {
    _songs = _replaceSongInList(_songs, updated);

    if (_currentSong?.id == updated.id) {
      _currentSong = updated;
    }

    // 同步更新持久化播放列表（如果存在）
    if (_playOrder.isNotEmpty) {
      final playlistForHandler =
          _playOrder.map((i) => _songs[i]).toList(growable: false);
      playerState?.setPlaylist(playlistForHandler);
    }

    if (original.id > 0 &&
        original.albumArtPath != updated.albumArtPath) {
      await MusicDatabase.database.updateSong(updated);
    }
    notifyListeners();
  }

  Future<void> _migrateAlbumArtCache({int batchSize = 50}) async {
    try {
      final db = MusicDatabase.database;
      while (true) {
        final songs = await (db.select(db.songs)
              ..where(
                (tbl) =>
                    tbl.source.equals('bilibili') &
                    tbl.albumArtPath.isNotNull() &
                    (tbl.albumArtPath.like('http://%') |
                        tbl.albumArtPath.like('https://%')),
              )
              ..limit(batchSize))
            .get();

        if (songs.isEmpty) break;

        debugPrint('[PlayerProvider] 🎨 封面缓存迁移: ${songs.length} 首');
        for (final song in songs) {
          await _ensureLocalAlbumArt(song, updateState: false);
        }

        if (songs.length < batchSize) break;
      }
    } catch (e, stackTrace) {
      debugPrint('[PlayerProvider] ⚠️ 封面迁移失败: $e');
      debugPrint(stackTrace.toString());
    }
  }

  List<Song> _replaceSongInList(List<Song> list, Song updated) {
    return list
        .map((song) => song.id == updated.id ? updated : song)
        .toList();
  }

  /// 从 Song 对象读取响度信息
  LoudnessInfo? _getLoudnessFromSong(Song song) {
    if (song.loudnessMeasuredI == null || song.loudnessTargetI == null) {
      return null;
    }

    return LoudnessInfo(
      measuredI: song.loudnessMeasuredI!,
      targetI: song.loudnessTargetI!,
      measuredTp: song.loudnessMeasuredTp ?? -1.0,
    );
  }

  /// 保存响度信息到数据库
  Future<void> _saveLoudnessToDatabase(int songId, LoudnessInfo loudness) async {
    try {
      await (MusicDatabase.database.update(MusicDatabase.database.songs)
            ..where((t) => t.id.equals(songId)))
          .write(
        SongsCompanion(
          loudnessMeasuredI: Value(loudness.measuredI),
          loudnessTargetI: Value(loudness.targetI),
          loudnessMeasuredTp: Value(loudness.measuredTp),
          loudnessData: Value(loudness.toJson().toString()),
        ),
      );
      debugPrint('[播放调试] ✅ 响度信息已保存到数据库');
    } catch (e) {
      debugPrint('[播放调试] ⚠️ 保存响度信息失败: $e');
    }
  }

  Future<int?> _resolveBilibiliCid(Song song, String bvid) async {
    if (song.cid != null && song.cid! > 0) {
      return song.cid;
    }

    if (song.bilibiliVideoId != null) {
      final video =
          await MusicDatabase.database.getBilibiliVideoById(song.bilibiliVideoId!);
      if (video != null && video.cid > 0) {
        return video.cid;
      }
    }

    try {
      final pages = await _getVideoPagesWithCache(bvid);
      if (pages.isEmpty) {
        return null;
      }

      if (song.pageNumber != null) {
        for (final bili_models.BilibiliVideoPage page in pages) {
          if (page.page == song.pageNumber) {
            return page.cid;
          }
        }
      }
      return pages.first.cid;
    } catch (e) {
      debugPrint('[播放调试] ⚠️ 获取视频分P信息失败: $e');
      return null;
    }
  }

  // ==================== 播放控制方法 ====================

  Future<void> playSong(
    Song song, {
    List<Song>? playlist,
    int? index,
    bool shuffle = true,
    bool playNow = true,
  }) async {
    await _playSongWithIndexMapping(
      song,
      playlist: playlist,
      index: index,
      shuffle: shuffle,
      playNow: playNow,
    );
  }

  Future<void> _updatePlayCount(Song song) async {
    try {
      Song? updatedForQueue;

      if (song.id < 0) {
        // 临时Song对象（在线收藏夹）
        Song? existingSong;
        if (song.bvid != null && song.cid != null) {
          existingSong = await MusicDatabase.database.getSongByBvidAndCid(
            song.bvid!,
            song.cid!,
          );
        }

        if (existingSong != null) {
          await MusicDatabase.database.updateSong(
            existingSong.copyWith(
              lastPlayedTime: DateTime.now(),
              playedCount: existingSong.playedCount + 1,
            ),
          );
          final updated = existingSong.copyWith(
            lastPlayedTime: DateTime.now(),
            playedCount: existingSong.playedCount + 1,
          );
          _currentSong = updated;
          updatedForQueue = updated;
        } else {
          final newId = await MusicDatabase.database.insertSong(
            song
                .copyWith(
                  lastPlayedTime: DateTime.now(),
                  playedCount: 1,
                )
                .toCompanion(false),
          );
          final updated = song.copyWith(
            id: newId,
            lastPlayedTime: DateTime.now(),
            playedCount: 1,
          );
          _currentSong = updated;
          updatedForQueue = updated;
        }
      } else {
        final updated = song.copyWith(
          lastPlayedTime: DateTime.now(),
          playedCount: song.playedCount + 1,
        );
        await MusicDatabase.database.updateSong(updated);
        _currentSong = updated;
        updatedForQueue = updated;
      }

      // 将最新的歌曲信息同步到当前队列中，避免当前播放歌曲只在数据库中更新而 playlist 里仍然是旧对象
      if (updatedForQueue != null && _songs.isNotEmpty) {
        final originalBvid = song.bvid;
        final originalCid = song.cid;
        final originalPage = song.pageNumber;

        _songs = _songs.map((s) {
          // 优先根据 id 匹配正式歌曲
          if (song.id > 0 && s.id == song.id) {
            return updatedForQueue!;
          }

          // 对于临时 Bilibili 歌曲，使用 bvid + cid/pageNumber 匹配
          if (song.id < 0 &&
              originalBvid != null &&
              originalBvid.isNotEmpty &&
              s.bvid == originalBvid) {
            if (originalCid != null &&
                originalCid > 0 &&
                s.cid != null &&
                s.cid! > 0 &&
                s.cid == originalCid) {
              return updatedForQueue!;
            }
            if (originalPage != null &&
                originalPage > 0 &&
                s.pageNumber != null &&
                s.pageNumber! > 0 &&
                s.pageNumber == originalPage) {
              return updatedForQueue!;
            }
          }

          return s;
        }).toList(growable: false);

        _updatePlaylistNotifier();
      }

      _updateCurrentSongNotifier();
      _notifySongChange();
    } catch (e) {
      print('⚠️ 数据库更新失败（不影响播放）: $e');
    }
  }

  Future<void> togglePlay() async {
    if (_audioHandler == null) return;
    if (isPlaying) {
      await _audioHandler!.pause();
    } else {
      await _audioHandler!.play();
    }
  }

  Future<void> pause() async {
    if (_audioHandler == null) return;
    await _audioHandler!.pause();
  }

  /// 开启倒计时睡眠定时：到点自动暂停（复用 AudioHandler 的淡出暂停）
  void startSleepTimer(Duration duration) {
    if (duration.inSeconds <= 0) {
      debugPrint('[SleepTimer] ⚠️ duration<=0，忽略 startSleepTimer($duration)');
      return;
    }

    _sleepTimerUntilEndOfTrack = false;
    _sleepTimerBoundTrackKey = null;
    _startSleepTimerInternal(duration);
    _persistSleepTimerState();
  }

  /// 播放完当前歌曲后暂停（基于当前 position/duration 计算剩余时间）
  void startSleepTimerUntilEndOfTrack() {
    final song = _currentSong;
    if (song == null) {
      debugPrint('[SleepTimer] ⚠️ 当前无歌曲，无法设置“播放完当前歌曲”');
      return;
    }

    final boundKey = _trackKeyForSong(song);
    final currentPos = _position.value;
    final currentDur = _duration;

    if (currentDur <= Duration.zero) {
      debugPrint('[SleepTimer] ⚠️ 当前歌曲 duration 不可用，无法设置“到曲末”：dur=$currentDur');
      return;
    }

    final remaining = currentDur - currentPos;
    if (remaining <= Duration.zero) {
      debugPrint('[SleepTimer] ℹ️ 当前已接近/到达曲末，立即暂停');
      unawaited(pause());
      return;
    }

    _sleepTimerUntilEndOfTrack = true;
    _sleepTimerBoundTrackKey = boundKey;
    _startSleepTimerInternal(remaining);
    _persistSleepTimerState();

    debugPrint(
      '[SleepTimer] ✅ 设置“播放完当前歌曲”：title=${song.title}, remaining=${remaining.inSeconds}s, bound=$boundKey',
    );
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndAt = null;
    _sleepTimerBoundTrackKey = null;
    _sleepTimerUntilEndOfTrack = false;
    sleepTimerRemainingNotifier.value = null;
    _clearPersistedSleepTimerState();
    debugPrint('[SleepTimer] 🛑 已取消睡眠定时');
  }

  void _startSleepTimerInternal(Duration duration) {
    _startSleepTimerTo(DateTime.now().add(duration));
  }

  void _persistSleepTimerState() {
    final endAt = _sleepTimerEndAt;
    if (endAt == null) return;

    Future<PlayerStateStorage> storageFuture;
    if (playerState != null) {
      storageFuture = Future.value(playerState!);
    } else {
      storageFuture = PlayerStateStorage.getInstance();
    }

    unawaited(storageFuture.then((storage) async {
      playerState ??= storage;
      await storage.setSleepTimer(
        endAtEpochMs: endAt.millisecondsSinceEpoch,
        untilEndOfTrack: _sleepTimerUntilEndOfTrack,
        boundTrackKey: _sleepTimerBoundTrackKey,
      );
    }));
  }

  void _clearPersistedSleepTimerState() {
    final storage = playerState;
    if (storage != null) {
      unawaited(storage.clearSleepTimer());
      return;
    }
    unawaited(PlayerStateStorage.getInstance().then((s) => s.clearSleepTimer()));
  }

  Future<void> _restoreSleepTimerFromStorage() async {
    final storage = playerState;
    if (storage == null) return;

    final endAtMs = storage.sleepTimerEndAtEpochMs;
    if (endAtMs == null || endAtMs <= 0) return;

    final endAt = DateTime.fromMillisecondsSinceEpoch(endAtMs);
    final remaining = endAt.difference(DateTime.now());

    if (remaining <= Duration.zero) {
      debugPrint('[SleepTimer] ⏰ 恢复时已过期，执行暂停并清理');
      await pause();
      await storage.clearSleepTimer();
      return;
    }

    _sleepTimerUntilEndOfTrack = storage.sleepTimerUntilEndOfTrack;
    _sleepTimerBoundTrackKey = storage.sleepTimerBoundTrackKey;

    if (_sleepTimerUntilEndOfTrack) {
      final currentKey = _trackKeyForSong(_currentSong);
      if (_sleepTimerBoundTrackKey == null ||
          _sleepTimerBoundTrackKey!.isEmpty ||
          _sleepTimerBoundTrackKey != currentKey) {
        debugPrint(
          '[SleepTimer] ℹ️ “到曲末”恢复校验失败（bound=$_sleepTimerBoundTrackKey, current=$currentKey），清理持久化状态',
        );
        _sleepTimerUntilEndOfTrack = false;
        _sleepTimerBoundTrackKey = null;
        await storage.clearSleepTimer();
        return;
      }
    }

    _startSleepTimerTo(endAt);
    debugPrint('[SleepTimer] 🔁 已恢复睡眠定时：剩余 ${remaining.inSeconds}s');
  }

  void _startSleepTimerTo(DateTime endAt) {
    _sleepTimer?.cancel();
    _sleepTimerEndAt = endAt;

    final initialRemaining = endAt.difference(DateTime.now());
    sleepTimerRemainingNotifier.value =
        initialRemaining <= Duration.zero ? Duration.zero : initialRemaining;

    debugPrint(
      '[SleepTimer] ▶️ 开始倒计时：${sleepTimerRemainingNotifier.value?.inSeconds ?? 0}s, endAt=$endAt',
    );

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final endTime = _sleepTimerEndAt;
      if (endTime == null) return;

      final remaining = endTime.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        sleepTimerRemainingNotifier.value = Duration.zero;

        final untilEndOfTrack = _sleepTimerUntilEndOfTrack;
        final boundKey = _sleepTimerBoundTrackKey;
        final currentKey = _trackKeyForSong(_currentSong);

        // 先停止定时器本身，避免重复触发
        _sleepTimer?.cancel();
        _sleepTimer = null;
        _sleepTimerEndAt = null;

        if (untilEndOfTrack && boundKey != null && boundKey != currentKey) {
          debugPrint(
            '[SleepTimer] ℹ️ 到点但曲目已变化（bound=$boundKey, current=$currentKey），不执行暂停',
          );
          cancelSleepTimer();
          return;
        }

        debugPrint('[SleepTimer] ⏰ 到点，执行暂停');
        await pause();
        cancelSleepTimer();
        return;
      }

      sleepTimerRemainingNotifier.value = remaining;
    });
  }

  Future<void> stop() async {
    cancelSleepTimer();
    await _audioHandler?.stop();
    _currentSong = null;
    _currentLyrics = null;
    _lyricsError = null;
    _currentLyricLineIndex = -1;
    _lyricsLoadGeneration++;
    await _lyricsNotificationService.clearLyrics();
    _position.value = Duration.zero;
    _errorMessage = null;
    _updateCurrentSongNotifier();
    isPlayingNotifier.value = false;
    notifyListeners();
  }

  Future<void> previous() async {
    if (_audioHandler == null) return;
    await _audioHandler!.skipToPrevious();
    _updateCurrentSongFromHandler();
    // 将上一首歌计入最近播放
    if (_currentSong != null) {
      await _updatePlayCount(_currentSong!);
    }
  }

  Future<void> next() async {
    if (_audioHandler == null) return;
    final beforeIndex = _audioHandler!.currentQueueIndex;
    debugPrint(
      '[PlayerProvider] ⏭ next() 调用: '
      'handlerIndex(before)=$beforeIndex, '
      '_currentOrderIndex=$_currentOrderIndex, _playOrder=$_playOrder',
    );
    await _audioHandler!.skipToNext();
    final afterIndex = _audioHandler!.currentQueueIndex;
    debugPrint(
      '[PlayerProvider] ⏭ next() 完成: handlerIndex(after)=$afterIndex',
    );
    _updateCurrentSongFromHandler();
    // 将下一首歌计入最近播放
    if (_currentSong != null) {
      await _updatePlayCount(_currentSong!);
    }
  }

  Future<void> seekTo(Duration position) async {
    await _audioHandler?.seek(position);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.5);
    await _audioHandler?.setVolume(_volume);
    playerState?.setVolume(volume);
    notifyListeners();
  }

  Future<void> toggleMute() async {
    if (_volume > 0) {
      await setVolume(0);
    } else {
      await setVolume(1.0);
    }
  }

  void setPlayMode(PlayMode mode) {
    _setPlayModeWithIndexMapping(mode);
  }

  void setPlaylist(List<Song> songs, {int currentIndex = 0}) {
    // 将传入列表视为新的播放队列（顺序模式）
    _songs = List.from(songs);
    _playOrder = List.generate(_songs.length, (i) => i);
    _currentOrderIndex =
        _playOrder.isEmpty ? 0 : currentIndex.clamp(0, _playOrder.length - 1);

    if (_songs.isNotEmpty) {
      _currentSong = _songs[_playOrder[_currentOrderIndex]];
    } else {
      _currentSong = null;
    }

    final playlistForHandler =
        _playOrder.map((i) => _songs[i]).toList(growable: false);
    // 这里只负责内存和持久化，由调用方决定何时重建 AudioHandler 队列
    playerState?.setPlaylist(playlistForHandler);
    _updateCurrentSongNotifier();
    _updatePlaylistNotifier();
    notifyListeners();
  }

  Future<void> addToPlaylist(Song song) async {
    await _addToPlaylistWithIndexMapping(song);
  }

  /// 插播：将歌曲插入到当前播放位置的下一首
  Future<void> insertNext(Song song) async {
    debugPrint(
      '[PlayerProvider] ▶️ insertNext 调用: songId=${song.id}, title=${song.title}',
    );
    await _insertNextWithIndexMapping(song);
  }

  Future<void> removeFromPlaylist(int index) async {
    await _removeFromPlaylistWithIndexMapping(index);
  }

  void reorderPlaylist(int oldIndex, int newIndex) {
    _reorderPlaylistWithIndexMapping(oldIndex, newIndex);
  }

  /// 重新打乱当前播放列表（仅在随机模式下生效）
  void reshufflePlaylist() {
    if (_playMode != PlayMode.shuffle || _songs.isEmpty) return;

    final currentSongIndex =
        _currentSong != null ? _findSongIndex(_currentSong!.id) : -1;
    _playOrder = _generateShuffledOrder(
      keepFirstIndex: currentSongIndex >= 0 ? currentSongIndex : null,
    );
    _currentOrderIndex = 0;

    final playlistForHandler =
        _playOrder.map((i) => _songs[i]).toList(growable: false);
    final initialIndex =
        _currentOrderIndex.clamp(0, _playOrder.length - 1);
    _setPlaylistToHandler(playlistForHandler, initialIndex: initialIndex);
    playerState?.setPlaylist(playlistForHandler);
    _updatePlaylistNotifier();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _onSongComplete() {
    switch (_playMode) {
      case PlayMode.single:
        stop();
        break;
      case PlayMode.singleLoop:
        if (_currentSong != null) {
          seekTo(Duration.zero);
          _audioHandler?.play();
        }
        break;
      case PlayMode.sequence:
        if (hasNext) {
          next();
        } else {
          stop();
        }
        break;
      case PlayMode.loop:
      case PlayMode.shuffle:
        next();
        break;
    }
  }

  void _updateCurrentSongFromHandler() {
    if (_audioHandler == null) return;

    final previousTrackKey = _trackKeyForSong(_currentSong);
    final handlerIndex = _audioHandler!.currentQueueIndex;
    final queueLen = _audioHandler!.queueList.length;
    if (handlerIndex < 0 || handlerIndex >= queueLen) {
      debugPrint(
        '[PlayerProvider] ⚠️ _updateCurrentSongFromHandler: '
        'handlerIndex=$handlerIndex 越界, queueLen=$queueLen',
      );
      return;
    }

    final currentList = playlist;
    if (currentList.isEmpty) {
      debugPrint(
        '[PlayerProvider] ⚠️ _updateCurrentSongFromHandler: playlist 为空, 无法同步当前歌曲',
      );
      return;
    }

    // 直接使用 AudioHandler 的队列索引与 playlist 对齐，避免通过 songId 搜索导致重复 id 时错位
    int effectiveIndex = handlerIndex;
    if (effectiveIndex < 0) {
      effectiveIndex = 0;
    } else if (effectiveIndex >= currentList.length) {
      effectiveIndex = currentList.length - 1;
    }

    _currentSong = currentList[effectiveIndex];
    _currentOrderIndex = effectiveIndex;

    final trackKey = _trackKeyForSong(_currentSong);
    _lyricsNotificationService.updateMetadata(
      title: _currentSong?.title,
      artist: _currentSong?.artist,
      songId: trackKey.isEmpty ? null : trackKey,
    );

    if (trackKey != previousTrackKey) {
      _currentLyrics = null;
      _lyricsError = null;
      _currentLyricLineIndex = -1;
      _lyricsLoadGeneration++;
      unawaited(loadLyrics());
    }
    _updateCurrentSongNotifier();
    debugPrint(
      '[PlayerProvider] 🎧 _updateCurrentSongFromHandler: '
      'handlerIndex=$handlerIndex, effectiveIndex=$effectiveIndex, '
      'currentSongId=${_currentSong?.id}, title=${_currentSong?.title}',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    if (_lifecycleObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _lifecycleObserverRegistered = false;
    }

    _positionSub?.cancel();
    _playbackStateSub?.cancel();
    currentSongNotifier.dispose();
    isPlayingNotifier.dispose();
    playlistNotifier.dispose();
    _sleepTimer?.cancel();
    sleepTimerRemainingNotifier.dispose();
    super.dispose();
  }

  // ==================== 歌词相关方法 ====================

  Future<void> loadLyrics({bool forceRefresh = false}) async {
    final songSnapshot = _currentSong;
    final requestGeneration = ++_lyricsLoadGeneration;
    final trackKeySnapshot = _trackKeyForSong(songSnapshot);
    print('[LyricsNotification] 🎯 loadLyrics() 被调用 (song: ${songSnapshot?.title})');

    bool isStillCurrent() {
      return requestGeneration == _lyricsLoadGeneration &&
          _trackKeyForSong(_currentSong) == trackKeySnapshot;
    }

    if (songSnapshot == null) {
      print('[LyricsNotification] ⚠️ _currentSong为null，跳过加载');
      _currentLyrics = null;
      _lyricsError = null;
      if (isStillCurrent()) {
        notifyListeners();
      }
      return;
    }

    _isLoadingLyrics = true;
    _lyricsError = null;
    if (isStillCurrent()) {
      notifyListeners();
    }

    try {
      print('📝 开始加载歌词: ${songSnapshot.title}');

      // 优先使用数据库中的本地歌词
      if (!forceRefresh &&
          songSnapshot.lyrics != null &&
          songSnapshot.lyrics!.trim().isNotEmpty) {
        try {
          final parsedLyrics = LyricParser.parseLrc(songSnapshot.lyrics!);
          if (isStillCurrent()) {
            _currentLyrics = parsedLyrics.copyWith(source: 'local');
            _lyricsError = null;
            _currentLyricLineIndex = -1;
            _isLoadingLyrics = false;
            notifyListeners();
          }
          return;
        } catch (e) {
          print('⚠️ 本地歌词解析失败: $e');
        }
      }

      // 尝试从网络获取歌词
      final lyrics = await lyricService.smartFetchLyrics(songSnapshot);

      if (lyrics != null && isStillCurrent()) {
        _currentLyrics = lyrics;
        _lyricsError = null;
        _currentLyricLineIndex = -1;  // 重置歌词行索引
        
        // 发送完整歌词列表到锁屏界面
        if (_lockScreenEnabled && lyrics.lyrics != null) {
          final allLyricsData = lyrics.lyrics!.map((line) {
            List<Map<String, dynamic>>? charTimestampsMap;
            if (line.charTimestamps != null) {
              charTimestampsMap = line.charTimestamps!.map((ct) {
                return {
                  'char': ct.char,
                  'startMs': ct.startMs.toInt(),
                  'endMs': ct.endMs.toInt(),
                };
              }).toList();
            }
            
            return {
              'text': line.text,
              'startMs': (line.timestamp * 1000).toInt(),
              'endMs': (line.timestamp * 1000 + 5000).toInt(), // 默认5秒
              'charTimestamps': charTimestampsMap,
            };
          }).toList();
          
          await _lyricsNotificationService.updateAllLyrics(
            lyrics: allLyricsData,
            currentIndex: -1,
            songId: trackKeySnapshot.isEmpty ? null : trackKeySnapshot,
          );
        }
        
        // 立即触发首次通知栏更新
        _updateNotificationLyrics(_position.value);
      } else if (isStillCurrent()) {
        _currentLyrics = null;
        _lyricsError = '未找到歌词';
        // 清除通知栏歌词
        await _lyricsNotificationService.clearLyrics();
      }
    } catch (e) {
      print('❌ 加载歌词失败: $e');
      if (isStillCurrent()) {
        _currentLyrics = null;
        _lyricsError = '加载歌词失败: ${e.toString()}';
        // 清除通知栏歌词
        await _lyricsNotificationService.clearLyrics();
      }
    } finally {
      if (isStillCurrent()) {
        _isLoadingLyrics = false;
        notifyListeners();
      }
    }
  }

  void updateLyrics(ParsedLrc lyrics) {
    _currentLyrics = lyrics;
    _currentLyricLineIndex = -1;  // 重置索引
    _updateNotificationLyrics(_position.value);
    notifyListeners();
  }

  void clearLyrics() {
    _currentLyrics = null;
    _lyricsError = null;
    _currentLyricLineIndex = -1;
    _lyricsNotificationService.clearLyrics();
    notifyListeners();
  }

  /// 实时更新通知栏歌词（根据播放位置）
  void _updateNotificationLyrics(Duration position) {
    // 调试：检查歌词状态
    if (_currentLyrics == null) {
      // print('[LyricsNotification] ⚠️ _currentLyrics为null，跳过更新');
      return;
    }
    if (_currentLyrics!.lyrics == null) {
      print('[LyricsNotification] ⚠️ _currentLyrics.lyrics为null，跳过更新');
      return;
    }

    final positionSec = position.inMilliseconds / 1000.0;
    final lyrics = _currentLyrics!.lyrics!;

    // 查找当前歌词行
    int currentLineIndex = -1;
    for (int i = 0; i < lyrics.length; i++) {
      if (positionSec >= lyrics[i].timestamp) {
        currentLineIndex = i;
      } else {
        break;
      }
    }

    // 仅在歌词行变化时更新通知栏（避免频繁刷新）
    if (currentLineIndex != _currentLyricLineIndex && currentLineIndex >= 0) {
      _currentLyricLineIndex = currentLineIndex;

      final currentLine = lyrics[currentLineIndex];
      final nextLine = (currentLineIndex + 1 < lyrics.length)
          ? lyrics[currentLineIndex + 1]
          : null;

      // 计算当前行结束时间
      final currentLineEndMs = nextLine != null
          ? (nextLine.timestamp * 1000).toInt()
          : (currentLine.timestamp * 1000 + 5000).toInt();  // 默认5秒

      // 将charTimestamps转换为Map格式
      List<Map<String, dynamic>>? charTimestampsMap;
      if (currentLine.charTimestamps != null) {
        charTimestampsMap = currentLine.charTimestamps!.map((ct) {
          return {
            'char': ct.char,
            'startMs': ct.startMs.toInt(),
            'endMs': ct.endMs.toInt(),
          };
        }).toList();
      }

      // 调试：打印歌词更新
      print('[LyricsNotification] 📝 歌词行切换: [$currentLineIndex] ${currentLine.text}');

      // 更新通知栏
      _lyricsNotificationService.updateLyrics(
        currentLine: currentLine.text,
        nextLine: nextLine?.text,
        currentLineStartMs: (currentLine.timestamp * 1000).toInt(),
        currentLineEndMs: currentLineEndMs,
        charTimestamps: charTimestampsMap,
      );
      
      // 锁屏：仅更新行索引（全量歌词在 loadLyrics()/启用锁屏时下发）
      if (_lockScreenEnabled) {
        final trackKey = _trackKeyForSong(_currentSong);
        _lyricsNotificationService.updateLyricIndex(
          currentIndex: currentLineIndex,
          songId: trackKey.isEmpty ? null : trackKey,
        );
      }
    }
  }

  void updateCurrentSong(Song updatedSong) async {
    if (_currentSong?.id == updatedSong.id) {
      _currentSong = updatedSong;

      try {
        await MusicDatabase.database.updateSong(updatedSong);
      } catch (e) {
        print('⚠️ 更新歌曲失败: $e');
      }

      // 更新内存中的歌曲列表
      _songs = _replaceSongInList(_songs, updatedSong);

      // 同步更新持久化播放列表（如果存在）
      if (_playOrder.isNotEmpty) {
        final playlistForHandler =
            _playOrder.map((i) => _songs[i]).toList(growable: false);
        playerState?.setPlaylist(playlistForHandler);
      }

      _updateCurrentSongNotifier();
      _updatePlaylistNotifier();
      notifyListeners();
    }
  }

  // ==================== 索引映射辅助方法 ====================

  int _findSongIndex(int songId) {
    return _songs.indexWhere((s) => s.id == songId);
  }

  /// 更健壮的查找逻辑：优先使用 id，其次使用 Bilibili 标识（bvid + cid / pageNumber）
  int _findSongIndexForQueue(Song song) {
    // 1. 数据库中的正式歌曲：直接用 id 匹配
    if (song.id > 0) {
      return _findSongIndex(song.id);
    }

    // 2. 临时 Bilibili 歌曲：使用 bvid + cid / pageNumber 组合匹配
    if (song.bvid != null && song.bvid!.isNotEmpty) {
      final targetBvid = song.bvid;
      final targetCid = song.cid;
      final targetPage = song.pageNumber;

      return _songs.indexWhere((s) {
        if (s.bvid != targetBvid) return false;

        // 优先根据 cid 精确匹配
        if (targetCid != null && targetCid > 0) {
          if (s.cid != null && s.cid! > 0) {
            return s.cid == targetCid;
          }
        }

        // 其次根据 pageNumber 匹配
        if (targetPage != null && targetPage > 0) {
          if (s.pageNumber != null && s.pageNumber! > 0) {
            return s.pageNumber == targetPage;
          }
        }

        // 兜底：仅按 bvid 匹配
        return true;
      });
    }

    // 3. 没有可用标识，视为不存在
    return -1;
  }

  List<int> _generateSequentialOrder() {
    return List.generate(_songs.length, (i) => i);
  }

  List<int> _generateShuffledOrder({int? keepFirstIndex}) {
    List<int> order = List.generate(_songs.length, (i) => i);
    if (keepFirstIndex != null) {
      order.removeAt(keepFirstIndex);
      order.shuffle(_random);
      order.insert(0, keepFirstIndex);
    } else {
      order.shuffle(_random);
    }
    return order;
  }

  // ==================== 索引映射版本的播放方法 ====================

  Future<void> _playSongWithIndexMapping(
    Song song, {
    List<Song>? playlist,
    int? index,
    bool shuffle = true,
    bool playNow = true,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _currentSong = song;
      notifyListeners();

      if (playlist != null) {
        _songs = List.from(playlist);
        final songIndex = _findSongIndexForQueue(song);
        
        if (_playMode == PlayMode.shuffle && shuffle) {
          _playOrder = _generateShuffledOrder(keepFirstIndex: songIndex);
          _currentOrderIndex = 0;
        } else {
          _playOrder = _generateSequentialOrder();
          _currentOrderIndex = songIndex >= 0 ? songIndex : (index ?? 0);
        }
      } else if (_songs.isEmpty || _findSongIndexForQueue(song) == -1) {
        _songs = [song];
        _playOrder = [0];
        _currentOrderIndex = 0;
      } else {
        final songIndex = _findSongIndexForQueue(song);
        if (songIndex != -1) {
          _currentOrderIndex = _playOrder.indexWhere((i) => i == songIndex);
        }
        // 如果查找失败，使用调用方传入的 index 作为兜底
        if (_currentOrderIndex == -1 || _currentOrderIndex < 0) {
          if (index != null &&
              index >= 0 &&
              index < _playOrder.length) {
            _currentOrderIndex = index;
          } else {
            _currentOrderIndex = 0;
          }
        }
      }

      final playlistForHandler =
          _playOrder.map((i) => _songs[i]).toList(growable: false);
      await _setPlaylistToHandler(playlistForHandler, initialIndex: _currentOrderIndex);

      if (_currentOrderIndex >= 0 && _audioHandler != null) {
        await _audioHandler!.skipToQueueItem(_currentOrderIndex);
        if (playNow) await _audioHandler!.play();
      }

      _isLoading = false;
      notifyListeners();
      await _updatePlayCount(song);
      playerState?.setCurrentSong(song);
      playerState?.setPlaylist(playlistForHandler);
      _updateCurrentSongNotifier();
      _updatePlaylistNotifier();
      loadLyrics();
    } catch (e) {
      _isLoading = false;
      _errorMessage = '播放失败: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> _addToPlaylistWithIndexMapping(Song song) async {
    debugPrint(
      '[PlayerProvider] ➕ addToPlaylist 开始: songId=${song.id}, title=${song.title}, '
      '_songs.length=${_songs.length}, _playOrder=$_playOrder, '
      'currentOrderIndex=$_currentOrderIndex',
    );

    // 记录当前播放状态，用于重建队列后恢复播放进度
    final wasPlaying = _audioHandler?.playing ?? false;
    final currentPosition = _audioHandler?.position ?? Duration.zero;
    debugPrint(
      '[PlayerProvider] ➕ addToPlaylist 状态: wasPlaying=$wasPlaying, '
      'currentPosition=${currentPosition.inMilliseconds}ms',
    );

    // 没有任何队列时，等价于播放单曲但不强制播放
    if (_songs.isEmpty || _playOrder.isEmpty) {
      _songs = [song];
      _playOrder = [0];
      _currentOrderIndex = 0;
      _currentSong ??= song;

      final playlistForHandler = [song];
      await _setPlaylistToHandler(playlistForHandler, initialIndex: 0);
      playerState?.setPlaylist(playlistForHandler);
      _updatePlaylistNotifier();
      debugPrint(
        '[PlayerProvider] ➕ addToPlaylist 结束(空队列分支): _songs.length=${_songs.length}, '
        '_playOrder=$_playOrder, currentOrderIndex=$_currentOrderIndex',
      );
      notifyListeners();
      return;
    }

    // 追加到当前播放队列的末尾（无论顺序/随机模式，一律追加到尾部）
    int songIndex = _findSongIndexForQueue(song);
    if (songIndex == -1) {
      _songs.add(song);
      songIndex = _songs.length - 1;
    }

    _playOrder.add(songIndex);

    final playlistForHandler =
        _playOrder.map((i) => _songs[i]).toList(growable: false);

    // 更新持久化和 UI（当前播放索引保持不变）
    playerState?.setPlaylist(playlistForHandler);
    _updatePlaylistNotifier();

    // 追加到 AudioHandler 队列尾部，避免重建整个队列导致卡顿
    if (_audioHandler != null) {
      final songForQueue = _songs[songIndex];
      final mediaItem = _convertSongToMediaItemLazy(songForQueue);
      await _audioHandler!.addQueueItem(mediaItem);
    }

    debugPrint(
      '[PlayerProvider] ➕ addToPlaylist 结束: _songs.length=${_songs.length}, '
      '_playOrder=$_playOrder, currentOrderIndex=$_currentOrderIndex',
    );
    notifyListeners();
  }

  Future<void> _insertNextWithIndexMapping(Song song) async {
    debugPrint(
      '[PlayerProvider] ⏭ 插播(insertNext) 开始: songId=${song.id}, title=${song.title}, '
      '_songs.length=${_songs.length}, _playOrder=$_playOrder, '
      'currentOrderIndex=$_currentOrderIndex',
    );
    if (_currentOrderIndex < 0 || _songs.isEmpty) {
      _songs = [song];
      _playOrder = [0];
      _currentOrderIndex = 0;
      final playlistForHandler = [song];
      await _setPlaylistToHandler(playlistForHandler, initialIndex: 0);
      playerState?.setPlaylist(playlistForHandler);
      _updatePlaylistNotifier();
      debugPrint(
        '[PlayerProvider] ⏭ 插播结束(空队列分支): _songs.length=${_songs.length}, '
        '_playOrder=$_playOrder, currentOrderIndex=$_currentOrderIndex',
      );
      notifyListeners();
      return;
    }

    final wasPlaying = _audioHandler?.playing ?? false;
    final currentPosition = _audioHandler?.position ?? Duration.zero;
    debugPrint(
      '[PlayerProvider] ⏭ 插播状态: wasPlaying=$wasPlaying, '
      'currentPosition=${currentPosition.inMilliseconds}ms',
    );

    int songIndex = _findSongIndexForQueue(song);
    if (songIndex == -1) {
      _songs.add(song);
      songIndex = _songs.length - 1;
    }

    // 1. 内存与持久化：在当前播放歌曲之后插入索引
    _playOrder.insert(_currentOrderIndex + 1, songIndex);
    final playlistForHandler =
        _playOrder.map((i) => _songs[i]).toList(growable: false);
    playerState?.setPlaylist(playlistForHandler);

    // 2. 底层队列操作：追加 + 重排，避免整队重建导致当前歌曲顿一下
    if (_audioHandler != null) {
      final handlerIndex = _audioHandler!.currentQueueIndex;
      final queueLenBefore = _audioHandler!.queueList.length;
      debugPrint(
        '[PlayerProvider] ⏭ 插播队列状态: handlerIndex=$handlerIndex, '
        'queueLenBefore=$queueLenBefore',
      );

      // 先在队尾追加一条队列项
      final songForQueue = _songs[songIndex];
      final mediaItem = _convertSongToMediaItemLazy(songForQueue);
      await _audioHandler!.addQueueItem(mediaItem);
      final queueLenAfter = _audioHandler!.queueList.length;
      final addedIndex = queueLenBefore; // 新条目总是先追加到末尾

      // 目标位置：当前播放曲目的下一首
      int targetIndex = handlerIndex + 1;
      if (targetIndex < 0) {
        targetIndex = 0;
      } else if (targetIndex >= queueLenAfter) {
        targetIndex = queueLenAfter - 1;
      }

      debugPrint(
        '[PlayerProvider] ⏭ 插播队列重排: addedIndex=$addedIndex, '
        'targetIndex=$targetIndex, queueLenAfter=$queueLenAfter',
      );

      if (addedIndex != targetIndex) {
        await _audioHandler!.reorderQueue(addedIndex, targetIndex);
      }
    }

    _updatePlaylistNotifier();
    debugPrint(
      '[PlayerProvider] ⏭ 插播结束: _songs.length=${_songs.length}, '
      '_playOrder=$_playOrder, currentOrderIndex=$_currentOrderIndex, '
      'currentSongId=${_currentSong?.id}',
    );
    notifyListeners();
  }

  Future<void> _removeFromPlaylistWithIndexMapping(int index) async {
    if (index < 0 || index >= _playOrder.length) return;

    final removedSongIndex = _playOrder[index];
    final removedSong = _songs[removedSongIndex];
    _playOrder.removeAt(index);

    if (index < _currentOrderIndex) {
      _currentOrderIndex--;
    } else if (index == _currentOrderIndex) {
      if (_playOrder.isEmpty) {
        _currentOrderIndex = 0;
        _currentSong = null;
      } else {
        if (_currentOrderIndex >= _playOrder.length) {
          _currentOrderIndex = _playOrder.length - 1;
        }
        _currentSong = _songs[_playOrder[_currentOrderIndex]];
      }
    }

    // 同步更新持久化和 UI
    final playlistForHandler =
        _playOrder.map((i) => _songs[i]).toList(growable: false);
    playerState?.setPlaylist(playlistForHandler);
    // ⚠️ 这里需要同步更新 playlistNotifier，以配合 Dismissible 的语义：
    // 条目一旦被标记为 dismissed，下一帧构建时必须已经从列表中移除，
    // 否则会触发 “A dismissed Dismissible widget is still part of the tree” 断言。
    playlistNotifier.value = List<Song>.from(playlistForHandler);

    // 底层队列：仅在有 AudioHandler 时调用 removeQueueItem，避免整队重建
    if (_audioHandler != null) {
      final mediaItem = _convertSongToMediaItemLazy(removedSong);
      await _audioHandler!.removeQueueItem(mediaItem);
    }

    // 队列为空时停止播放
    if (_playOrder.isEmpty) {
      await stop();
    }

    notifyListeners();
  }

  void _reorderPlaylistWithIndexMapping(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _playOrder.length) return;
    if (newIndex < 0 || newIndex > _playOrder.length) return;
    if (oldIndex == newIndex) return;

    final originalOldIndex = oldIndex;
    final originalNewIndex = newIndex;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final movedIndex = _playOrder.removeAt(oldIndex);
    _playOrder.insert(newIndex, movedIndex);

    if (_currentSong != null) {
      final currentSongIndex = _findSongIndex(_currentSong!.id);
      _currentOrderIndex = _playOrder.indexWhere((i) => i == currentSongIndex);
    }

    if (_audioHandler != null) {
      _audioHandler!.reorderQueue(originalOldIndex, originalNewIndex);
    }

    final playlistForHandler = _playOrder.map((i) => _songs[i]).toList();
    playerState?.setPlaylist(playlistForHandler);

    // 重排场景下直接同步更新，避免额外一帧的 post-frame 重建带来的“跳动”感
    playlistNotifier.value = List<Song>.from(playlistForHandler);
    Future.microtask(() => notifyListeners());
  }

  void _setPlayModeWithIndexMapping(PlayMode mode) {
    if (_playMode == mode) return;

    _playMode = mode;

    if (_songs.isEmpty) {
      notifyListeners();
      playerState?.setPlayMode(mode);
      return;
    }

    final currentSongIndex =
        _currentSong != null ? _findSongIndexForQueue(_currentSong!) : -1;

    if (mode == PlayMode.shuffle) {
      _playOrder = _generateShuffledOrder(keepFirstIndex: currentSongIndex >= 0 ? currentSongIndex : null);
      _currentOrderIndex = 0;
    } else {
      _playOrder = _generateSequentialOrder();
      _currentOrderIndex = currentSongIndex >= 0 ? currentSongIndex : 0;
    }

    final playlistForHandler =
        _playOrder.map((i) => _songs[i]).toList(growable: false);
    final initialIndex = _currentOrderIndex.clamp(0, _playOrder.length - 1);
    _setPlaylistToHandler(playlistForHandler, initialIndex: initialIndex);
    playerState?.setPlaylist(playlistForHandler);

    notifyListeners();
    playerState?.setPlayMode(mode);
    _updatePlaylistNotifier();
  }

  // ==================== 保留兼容性 ====================

  List<Song> currentPlaylists() {
    return List.from(playlist);
  }

  /// 判断两首歌曲在播放队列语义上是否相同（用于高亮/同步 UI）
  bool isSameSongForDisplay(Song? current, Song song) {
    if (current == null) return false;

    // 1. 正式歌曲：优先使用 id
    if (current.id > 0 && song.id > 0 && current.id == song.id) {
      return true;
    }

    // 2. Bilibili 临时歌曲：bvid + cid / pageNumber
    if (current.bvid != null &&
        current.bvid!.isNotEmpty &&
        song.bvid == current.bvid) {
      final currentCid = current.cid ?? 0;
      final songCid = song.cid ?? 0;
      if (currentCid > 0 && songCid > 0 && currentCid == songCid) {
        return true;
      }

      final currentPage = current.pageNumber ?? 0;
      final songPage = song.pageNumber ?? 0;
      if (currentPage > 0 && songPage > 0 && currentPage == songPage) {
        return true;
      }

      // bvid 相同但 cid/pageNumber 都不匹配，视为不同分 P
      return false;
    }

    // 3. 其他情况：退化为 id 对比
    return current.id == song.id;
  }
  
  /// Bilibili 自动缓存统计（供设置页使用）
  Future<AutoCacheStatistics?> getBilibiliAutoCacheStatistics() async {
    try {
      return await _bilibiliAutoCacheService.getCacheStatistics();
    } catch (e) {
      debugPrint('[PlayerProvider] 获取自动缓存统计失败: $e');
      return null;
    }
  }

  /// 清空 Bilibili 自动缓存（供设置页使用）
  Future<void> clearBilibiliAutoCache() async {
    try {
      await _bilibiliAutoCacheService.clearAllCache();
    } catch (e) {
      debugPrint('[PlayerProvider] 清空自动缓存失败: $e');
      rethrow;
    }
  }

  /// 获取 Bilibili 自动缓存目录（供设置页打开目录）
  Future<String?> getBilibiliAutoCacheDirectory() async {
    try {
      // 通过一次统计或命中函数确保服务已初始化，并读取内部目录
      final stats = await _bilibiliAutoCacheService.getCacheStatistics();
      debugPrint('[PlayerProvider] 自动缓存统计: $stats');
      // 目前 AutoCacheService 不暴露目录字段，这里复用一次 getCacheStatistics 仅为确保初始化。
      // 目录路径由 AutoCacheService 内部按应用缓存目录 + /bilibili_auto 生成。
      // 为避免重复逻辑，这里简单重新计算一次。
      final cacheDir = await getApplicationCacheDirectory();
      return p.join(cacheDir.path, 'bilibili_auto');
    } catch (e) {
      debugPrint('[PlayerProvider] 获取自动缓存目录失败: $e');
      return null;
    }
  }
}

class _ResolvedAudioSource {
  final String type;
  final String? path;
  final Map<String, String>? headers;
  final LoudnessInfo? loudness;

  const _ResolvedAudioSource._(this.type, this.path, this.headers, this.loudness);

  factory _ResolvedAudioSource.file(String path) =>
      _ResolvedAudioSource._('file', path, null, null);

  factory _ResolvedAudioSource.url(
    String path, {
    Map<String, String>? headers,
  }) =>
      _ResolvedAudioSource._('url', path, headers, null);

  factory _ResolvedAudioSource.lockCaching(String id, {LoudnessInfo? loudness}) =>
      _ResolvedAudioSource._('lock_caching', id, null, loudness);
}
