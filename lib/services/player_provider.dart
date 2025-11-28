import 'package:flutter/foundation.dart';
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
import '../models/bilibili/audio_quality.dart';
import 'package:drift/drift.dart';
import 'lyrics/lyric_service.dart';
import '../models/lyrics/lyric_models.dart';
import '../models/bilibili/video.dart' as bili_models;
import '../utils/lyric_parser.dart';
import 'audio_handler_service.dart';
import 'lyrics_notification_service.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'audio_source_registry.dart';

/// 播放器状态管理
/// 
/// 负责整合 AudioHandler 和应用业务逻辑
class PlayerProvider with ChangeNotifier {
  MottoAudioHandler? _audioHandler;
  
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

  List<Song> _playlist = [];
  List<Song> _originalPlaylist = [];
  List<Song> _shuffledPlaylist = [];
  int _currentIndex = -1;

  final math.Random _random = math.Random();
  Directory? _notificationArtCacheDir;

  // 歌词相关状态
  ParsedLrc? _currentLyrics;
  bool _isLoadingLyrics = false;
  String? _lyricsError;
  int _currentLyricLineIndex = -1;  // 当前歌词行索引
  bool _lyricsNotificationEnabled = false;
  bool _lockScreenEnabled = false;

  StreamSubscription? _positionSub;
  StreamSubscription? _playbackStateSub;

  // 通知栏歌词服务
  final LyricsNotificationService _lyricsNotificationService = LyricsNotificationService();

  // Getters
  Song? get currentSong => _currentSong;
  bool get isPlaying => _audioHandler?.playing ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ValueNotifier<Duration> get position => _position;
  Duration get duration => _duration;
  PlayMode get playMode => _playMode;
  List<Song> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  double get volume => _volume;

  // 歌词相关 Getters
  ParsedLrc? get currentLyrics => _currentLyrics;
  bool get isLoadingLyrics => _isLoadingLyrics;
  String? get lyricsError => _lyricsError;
  bool get lyricsNotificationEnabled => _lyricsNotificationEnabled;
  bool get lockScreenEnabled => _lockScreenEnabled;

  bool get hasPrevious =>
      playMode == PlayMode.shuffle ? true : _currentIndex > 0;
  bool get hasNext => playMode == PlayMode.shuffle
      ? true
      : _currentIndex < _playlist.length - 1;

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

    _initializeListeners();
    await _restoreState();
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
      _updateCurrentSongFromHandler();
      _notifySongChange();
    });

    // 监听播放状态变化
    _playbackStateSub = _audioHandler!.playbackState.listen((state) {
      _lyricsNotificationService.updatePlayState(state.playing);
      
      // 深度混合方案：播放状态变化时触发锁屏显示
      if (state.playing && _lockScreenEnabled) {
        _lyricsNotificationService.tryShowLockScreen();
      }
      
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
    _playlist = playerState?.playlist ?? [];
    _originalPlaylist = playerState?.playlist ?? [];
    _shuffledPlaylist = playerState?.playlist ?? [];
    _volume = playerState?.volume ?? 1.0;
    _playMode = playerState?.playMode ?? PlayMode.loop;
    _position.value = playerState?.position ?? Duration.zero;
    _lyricsNotificationEnabled =
        playerState?.lyricsNotificationEnabled ?? false;
    _lockScreenEnabled =
        playerState?.lockScreenEnabled ?? false;
    await _lyricsNotificationService.setNotificationEnabled(_lyricsNotificationEnabled);
    await _lyricsNotificationService.setLockScreenEnabled(_lockScreenEnabled);
    
    if (_currentSong != null && _playlist.isNotEmpty) {
      _currentIndex = _playlist.indexWhere((s) => s.id == _currentSong!.id);
      // 恢复播放列表而不自动播放
      await _setPlaylistToHandler(_playlist, initialIndex: _currentIndex);
    }
    
    await _audioHandler?.setVolume(_volume);
    if (_currentSong != null) {
      _lyricsNotificationService.updateMetadata(
        title: _currentSong!.title,
        artist: _currentSong!.artist,
        coverUrl: _currentSong!.albumArtPath,
      );
    }
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
      _lyricsNotificationService.updateMetadata(
        title: _currentSong?.title,
        artist: _currentSong?.artist,
        coverUrl: _currentSong?.albumArtPath,
      );
      _currentLyricLineIndex = -1;
      _updateNotificationLyrics(_position.value);
    }
    notifyListeners();
  }

  /// 设置播放列表到 AudioHandler
  Future<void> _setPlaylistToHandler(
    List<Song> songs, {
    int initialIndex = 0,
  }) async {
    if (_audioHandler == null) {
      debugPrint('[播放调试] ❌ AudioHandler 为 null，无法设置播放列表');
      return;
    }
    
    debugPrint('[播放调试] 🔄 开始转换 ${songs.length} 首歌曲为 MediaItem...');
    final mediaItems = await Future.wait(
      songs.map((song) => _convertSongToMediaItem(song)).toList(),
    );
    
    debugPrint('[播放调试] ✅ MediaItem 转换完成，设置到 AudioHandler');
    await _audioHandler!.setPlaylist(mediaItems, initialIndex: initialIndex);
    debugPrint('[播放调试] ✅ 播放列表已设置到 AudioHandler');
  }

  /// 将 Song 转换为 MediaItem
  Future<MediaItem> _convertSongToMediaItem(Song song) async {
    // 构建封面 URI
    Uri? artUri;
    if (song.albumArtPath != null && song.albumArtPath!.isNotEmpty) {
      artUri = await _buildNotificationArtUri(song.albumArtPath!);
    }

    final resolvedSource = await _resolveAudioSource(song);
    final sourceType = resolvedSource.type;
    final headers = resolvedSource.headers;

    final extras = <String, dynamic>{
      'sourceType': sourceType,
      if (resolvedSource.path != null) 'sourcePath': resolvedSource.path,
      if (headers != null) 'headers': headers,
      'songId': song.id,
      'bvid': song.bvid ?? '',
      'cid': song.cid ?? 0,
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
          final response = await request.close();
          if (response.statusCode == HttpStatus.ok) {
            return await consolidateHttpClientResponseBytes(response);
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
      debugPrint('[PlayerProvider] 加载封面失败: $e');
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
      );
      if (downloadedPath != null && downloadedPath.isNotEmpty) {
        debugPrint('[播放调试] ✅ 使用手动下载: $downloadedPath');
        return _ResolvedAudioSource.file(downloadedPath);
      }

      // ========== 优先级2: LockCaching 缓存文件命中 ==========
      final cachedFile = await _bilibiliAutoCacheService.getCachedAudioFile(
        bvid: bvid,
        cid: cid,
        quality: playQuality,
      );
      if (cachedFile != null) {
        debugPrint('[播放调试] ✅ 自动缓存命中: ${cachedFile.path}');
        return _ResolvedAudioSource.file(cachedFile.path);
      }

      // ========== 默认: 创建 LockCachingAudioSource，边播边写 ==========
      debugPrint('[播放调试] ⚡ LockCachingAudioSource 开始流式缓存');
      final lockCachingSource =
          await _bilibiliAutoCacheService.createLockCachingAudioSource(
        bvid: bvid,
        cid: cid,
        quality: playQuality,
      );
      final sourceId = _buildLockCacheId(song, playQuality);
      AudioSourceRegistry.register(sourceId, lockCachingSource);
      return _ResolvedAudioSource.lockCaching(sourceId);
    } catch (e) {
      debugPrint('[播放调试] ❌ LockCachingAudioSource 初始化失败: $e');
      // ========== 回退方案: 直接流式播放 ==========
      try {
        final streamInfo = await _bilibiliStreamService.getAudioStream(
          bvid: bvid,
          cid: cid,
          quality: playQuality,
        );

        final cookie = await _cookieManager.getCookieString();
        final headers = <String, String>{
          'Referer': 'https://www.bilibili.com',
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 BiliApp/6.66.0',
          if (cookie.isNotEmpty) 'Cookie': cookie,
        };

        debugPrint('[播放调试] ⚡ 使用流式播放: ${streamInfo.url.substring(0, 50)}...');
        return _ResolvedAudioSource.url(
          streamInfo.url,
          headers: headers,
        );
      } catch (streamError) {
        debugPrint('[播放调试] ❌ 获取流 URL 失败: $streamError');
        return null;
      }
    }
  }

  String _buildLockCacheId(
    Song song,
    BilibiliAudioQuality quality,
  ) =>
      'lockcache_${song.id}_${quality.id}_${DateTime.now().microsecondsSinceEpoch}';

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
      final pages = await _bilibiliApiService.getVideoPages(bvid);
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
    try {
      debugPrint('[播放调试] ========== 开始播放 ==========');
      debugPrint('[播放调试] 歌曲: ${song.title}');
      debugPrint('[播放调试] 艺术家: ${song.artist ?? "未知"}');
      debugPrint('[播放调试] 来源: ${song.source}');

      _isLoading = true;
      _errorMessage = null;
      _currentSong = song;
      notifyListeners();

      // 处理播放列表逻辑
      if (playlist != null) {
        _originalPlaylist = List.from(playlist);

        if (_playMode == PlayMode.shuffle && shuffle) {
          _createShuffledPlaylist();
          _playlist = _shuffledPlaylist;
          _currentIndex = _shuffledPlaylist.indexWhere((s) => s.id == song.id);
        } else {
          _playlist = List.from(playlist);
          _currentIndex = index ?? 0;
          if (_playMode == PlayMode.shuffle) {
            _createShuffledPlaylist();
          }
        }
      } else if (_originalPlaylist.isEmpty ||
          !_originalPlaylist.any((s) => s.id == song.id)) {
        _originalPlaylist = [song];
        _shuffledPlaylist = [song];
        _playlist = [song];
        _currentIndex = 0;
      } else {
        if (_playMode == PlayMode.shuffle) {
          _currentIndex = _shuffledPlaylist.indexWhere((s) => s.id == song.id);
          _playlist = _shuffledPlaylist;
        } else {
          _currentIndex = _originalPlaylist.indexWhere((s) => s.id == song.id);
          _playlist = _originalPlaylist;
        }
      }

      // 设置播放列表到 AudioHandler
      debugPrint('[播放调试] 📋 设置播放列表，总数: ${_playlist.length}, 当前索引: $_currentIndex');
      debugPrint('[播放调试] AudioHandler 状态: ${_audioHandler == null ? "❌ NULL" : "✅ 已初始化"}');
      await _setPlaylistToHandler(_playlist, initialIndex: _currentIndex);

      // 跳转到指定歌曲并播放
      if (_currentIndex >= 0 && _audioHandler != null) {
        debugPrint('[播放调试] 🎯 跳转到索引 $_currentIndex 并播放');
        await _audioHandler!.skipToQueueItem(_currentIndex);
        if (playNow) {
          debugPrint('[播放调试] ▶️ 发送播放命令');
          await _audioHandler!.play();
        }
      } else {
        debugPrint('[播放调试] ❌ 无法播放: AudioHandler = ${_audioHandler == null ? "null" : "OK"}, index = $_currentIndex');
      }

      _isLoading = false;
      notifyListeners();

      // 更新数据库播放计数
      await _updatePlayCount(song);

      // 保存状态
      playerState?.setCurrentSong(song);
      playerState?.setPlaylist(_playlist);

      // 自动加载歌词
      print('[LyricsNotification] 🚀 准备调用loadLyrics()');
      loadLyrics();
    } catch (e) {
      print('❌ 播放失败: $e');
      _isLoading = false;
      _errorMessage = '播放失败: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> _updatePlayCount(Song song) async {
    try {
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
          _currentSong = existingSong.copyWith(
            lastPlayedTime: DateTime.now(),
            playedCount: existingSong.playedCount + 1,
          );
        } else {
          final newId = await MusicDatabase.database.insertSong(
            song
                .copyWith(
                  lastPlayedTime: DateTime.now(),
                  playedCount: 1,
                )
                .toCompanion(false),
          );
          _currentSong = song.copyWith(
            id: newId,
            lastPlayedTime: DateTime.now(),
            playedCount: 1,
          );
        }
      } else {
        await MusicDatabase.database.updateSong(
          song.copyWith(
            lastPlayedTime: DateTime.now(),
            playedCount: song.playedCount + 1,
          ),
        );
      }
      _notifySongChange();
    } catch (e) {
      print('⚠️ 数据库更新失败（不影响播放）: $e');
    }
  }

  void _createShuffledPlaylist() {
    if (_originalPlaylist.isEmpty) return;

    _shuffledPlaylist = List.from(_originalPlaylist);

    if (_currentSong != null) {
      _shuffledPlaylist.removeWhere((song) => song.id == _currentSong!.id);
      _shuffledPlaylist.insert(0, _currentSong!);
    }

    if (_shuffledPlaylist.length > 1) {
      final songsToShuffle = _shuffledPlaylist.sublist(1);
      songsToShuffle.shuffle(_random);
      _shuffledPlaylist = [_shuffledPlaylist.first, ...songsToShuffle];
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

  Future<void> stop() async {
    await _audioHandler?.stop();
    _currentSong = null;
    _position.value = Duration.zero;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> previous() async {
    if (_audioHandler == null) return;
    await _audioHandler!.skipToPrevious();
    _updateCurrentSongFromHandler();
    _notifySongChange();
  }

  Future<void> next() async {
    if (_audioHandler == null) return;
    await _audioHandler!.skipToNext();
    _updateCurrentSongFromHandler();
    _notifySongChange();
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
    if (_playMode == mode) return;

    final previousMode = _playMode;
    _playMode = mode;
    _handlePlayModeChange(previousMode, mode);
    notifyListeners();
    playerState?.setPlayMode(mode);
  }

  void _handlePlayModeChange(PlayMode previousMode, PlayMode newMode) {
    if (previousMode == PlayMode.shuffle && newMode != PlayMode.shuffle) {
      _restoreOriginalPlaylist();
    } else if (previousMode != PlayMode.shuffle &&
        newMode == PlayMode.shuffle) {
      _switchToShuffleMode();
    }
  }

  void _restoreOriginalPlaylist() {
    if (_originalPlaylist.isEmpty) return;
    _playlist = List.from(_originalPlaylist);
    if (_currentSong != null) {
      _currentIndex = _originalPlaylist.indexWhere(
        (s) => s.id == _currentSong!.id,
      );
      if (_currentIndex == -1) _currentIndex = 0;
    }
  }

  void _switchToShuffleMode() {
    if (_originalPlaylist.isEmpty) return;
    _createShuffledPlaylist();
    _playlist = _shuffledPlaylist;
    if (_currentSong != null) {
      _currentIndex = _shuffledPlaylist.indexWhere(
        (s) => s.id == _currentSong!.id,
      );
      if (_currentIndex == -1) _currentIndex = 0;
    }
  }

  void setPlaylist(List<Song> songs, {int currentIndex = 0}) {
    _originalPlaylist = List.from(songs);
    _currentIndex = currentIndex.clamp(0, songs.length - 1);

    if (_playMode == PlayMode.shuffle) {
      if (songs.isNotEmpty) {
        _currentSong = songs[_currentIndex];
        _createShuffledPlaylist();
        _playlist = _shuffledPlaylist;
        _currentIndex = _shuffledPlaylist.indexWhere(
          (s) => s.id == _currentSong!.id,
        );
      }
    } else {
      _playlist = List.from(songs);
    }

    if (songs.isNotEmpty) {
      _currentSong = songs[currentIndex.clamp(0, songs.length - 1)];
    }
    notifyListeners();
  }

  void addToPlaylist(Song song) async {
    _originalPlaylist.add(song);

    if (_playMode == PlayMode.shuffle) {
      if (_shuffledPlaylist.isEmpty) {
        _shuffledPlaylist.add(song);
      } else {
        final randomIndex = _random.nextInt(_shuffledPlaylist.length + 1);
        _shuffledPlaylist.insert(randomIndex, song);
      }
      _playlist = _shuffledPlaylist;
    } else {
      _playlist.add(song);
    }

    // 更新 AudioHandler 队列
    if (_audioHandler != null) {
      final mediaItem = await _convertSongToMediaItem(song);
      await _audioHandler!.addQueueItem(mediaItem);
    }

    notifyListeners();
  }

  void removeFromPlaylist(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    final removedSong = _playlist[index];
    _playlist.removeAt(index);
    _originalPlaylist.removeWhere((song) => song.id == removedSong.id);

    if (_playMode == PlayMode.shuffle) {
      _shuffledPlaylist.removeWhere((song) => song.id == removedSong.id);
    }

    // 更新 AudioHandler 队列
    if (_audioHandler != null) {
      final mediaItem = await _convertSongToMediaItem(removedSong);
      await _audioHandler!.removeQueueItem(mediaItem);
    }

    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_currentIndex >= _playlist.length) {
        _currentIndex = _playlist.length - 1;
      }
      if (_playlist.isEmpty) {
        stop();
      } else {
        _currentSong = _playlist[_currentIndex];
      }
    }
    notifyListeners();
  }

  void reorderPlaylist(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _playlist.length) return;
    if (newIndex < 0 || newIndex >= _playlist.length) return;
    if (oldIndex == newIndex) return;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final movedSong = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, movedSong);

    _originalPlaylist.clear();
    _originalPlaylist.addAll(_playlist);

    if (_currentSong != null) {
      _currentIndex = _playlist.indexWhere((song) => song.id == _currentSong!.id);
    }

    playerState?.setPlaylist(_playlist);
    notifyListeners();
  }

  void reshufflePlaylist() {
    if (_playMode != PlayMode.shuffle || _originalPlaylist.isEmpty) return;

    _createShuffledPlaylist();
    _playlist = _shuffledPlaylist;

    if (_currentSong != null) {
      _currentIndex = _shuffledPlaylist.indexWhere(
        (s) => s.id == _currentSong!.id,
      );
      if (_currentIndex == -1) _currentIndex = 0;
    }
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
    final currentItem = _audioHandler!.queueList[_audioHandler!.currentQueueIndex].mediaItem;
    final songId = int.tryParse(currentItem.id) ?? -1;
    _currentSong = _playlist.firstWhere(
      (s) => s.id == songId,
      orElse: () => _playlist.first,
    );
    _currentIndex = _audioHandler!.currentQueueIndex;
    _lyricsNotificationService.updateMetadata(
      title: _currentSong?.title,
      artist: _currentSong?.artist,
      coverUrl: _currentSong?.albumArtPath,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playbackStateSub?.cancel();
    super.dispose();
  }

  // ==================== 歌词相关方法 ====================

  Future<void> loadLyrics({bool forceRefresh = false}) async {
    print('[LyricsNotification] 🎯 loadLyrics() 被调用 (song: ${_currentSong?.title})');

    if (_currentSong == null) {
      print('[LyricsNotification] ⚠️ _currentSong为null，跳过加载');
      _currentLyrics = null;
      _lyricsError = null;
      notifyListeners();
      return;
    }

    _isLoadingLyrics = true;
    _lyricsError = null;
    notifyListeners();

    try {
      print('📝 开始加载歌词: ${_currentSong!.title}');

      // 优先使用数据库中的本地歌词
      if (!forceRefresh &&
          _currentSong!.lyrics != null &&
          _currentSong!.lyrics!.trim().isNotEmpty) {
        try {
          final parsedLyrics = LyricParser.parseLrc(_currentSong!.lyrics!);
          _currentLyrics = parsedLyrics.copyWith(source: 'local');
          _lyricsError = null;
          _isLoadingLyrics = false;
          notifyListeners();
          return;
        } catch (e) {
          print('⚠️ 本地歌词解析失败: $e');
        }
      }

      // 尝试从网络获取歌词
      final lyrics = await lyricService.smartFetchLyrics(_currentSong!);

      if (lyrics != null) {
        _currentLyrics = lyrics;
        _lyricsError = null;
        _currentLyricLineIndex = -1;  // 重置歌词行索引
        // 立即触发首次通知栏更新
        _updateNotificationLyrics(_position.value);
      } else {
        _currentLyrics = null;
        _lyricsError = '未找到歌词';
        // 清除通知栏歌词
        await _lyricsNotificationService.clearLyrics();
      }
    } catch (e) {
      print('❌ 加载歌词失败: $e');
      _currentLyrics = null;
      _lyricsError = '加载歌词失败: ${e.toString()}';
      // 清除通知栏歌词
      await _lyricsNotificationService.clearLyrics();
    } finally {
      _isLoadingLyrics = false;
      notifyListeners();
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

      final index = _playlist.indexWhere((s) => s.id == updatedSong.id);
      if (index != -1) {
        _playlist[index] = updatedSong;
      }

      final originalIndex =
          _originalPlaylist.indexWhere((s) => s.id == updatedSong.id);
      if (originalIndex != -1) {
        _originalPlaylist[originalIndex] = updatedSong;
      }

      notifyListeners();
    }
  }



  // ==================== 保留兼容性 ====================
  
  List<Song> currentPlaylists() {
    return _playlist;
  }
  
  // audioLoaderService 已废弃（新架构中不再需要）
  dynamic get audioLoaderService => null;
  
  // 暂时保留,但实际不再使用  
  dynamic get player => null;
}

class _ResolvedAudioSource {
  final String type;
  final String? path;
  final Map<String, String>? headers;

  const _ResolvedAudioSource._(this.type, this.path, this.headers);

  factory _ResolvedAudioSource.file(String path) =>
      _ResolvedAudioSource._('file', path, null);

  factory _ResolvedAudioSource.url(
    String path, {
    Map<String, String>? headers,
  }) =>
      _ResolvedAudioSource._('url', path, headers);

  factory _ResolvedAudioSource.lockCaching(String id) =>
      _ResolvedAudioSource._('lock_caching', id, null);
}
