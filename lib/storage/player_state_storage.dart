import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../contants/app_contants.dart' show PlayerPage, PlayMode, SortState;

class PlayerStateStorage {
  static PlayerStateStorage? _instance;

  static Future<PlayerStateStorage> getInstance() async {
    if (_instance != null) return _instance!;
    _instance = await _load();
    return _instance!;
  }

  PlayerStateStorage._();

  static const String _isPlayingKey = 'is_playing';
  static const String _positionKey = 'playback_position';
  static const String _songKey = 'current_song';
  static const String _playModeKey = 'play_mode';
  static const String _volumeKey = 'volume';
  static const String _pageKey = 'current_page';
  static const String _sortKey = 'sort_state';
  static const String _playlistKey = 'playlist';
  static const String _bilibiliCacheSizeKey = 'bilibili_cache_size_gb';
  static const String _bilibiliPlayQualityKey = 'bilibili_play_quality';
  static const String _lyricsNotificationEnabledKey = 'lyrics_notification_enabled';
  static const String _lockScreenEnabledKey = 'lockscreen_lyrics_enabled';
  static const String _fadeInDurationKey = 'fade_in_duration_ms';
  static const String _fadeOutDurationKey = 'fade_out_duration_ms';
  static const String _gaplessEnabledKey = 'gapless_enabled';

  // 私有成员
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Song? _currentSong;
  PlayMode _playMode = PlayMode.shuffle;
  double _volume = 1.0;
  PlayerPage _currentPage = PlayerPage.home;
  Map<String, SortState> _pageSortStates = {};
  List<Song> _playlist = [];
  int _bilibiliCacheSizeGB = 5; // 默认 5GB
  int _defaultBilibiliPlayQuality = 30232; // 默认高音质 (128kbps)
  bool _lyricsNotificationEnabled = false;
  bool _lockScreenEnabled = false;
  int _fadeInDurationMs = 500; // 默认500ms淡入
  int _fadeOutDurationMs = 500; // 默认500ms淡出
  bool _gaplessEnabled = true; // 默认启用无缝播放

  /// 对外只读属性
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Song? get currentSong => _currentSong;
  PlayMode get playMode => _playMode;
  double get volume => _volume;
  PlayerPage get currentPage => _currentPage;
  Map<String, SortState> get pageSortStates =>
      Map.unmodifiable(_pageSortStates);
  List<Song> get playlist => List.unmodifiable(_playlist);
  int get bilibiliCacheSizeGB => _bilibiliCacheSizeGB;
  int get defaultBilibiliPlayQuality => _defaultBilibiliPlayQuality;
  bool get lyricsNotificationEnabled => _lyricsNotificationEnabled;
  bool get lockScreenEnabled => _lockScreenEnabled;
  int get fadeInDurationMs => _fadeInDurationMs;
  int get fadeOutDurationMs => _fadeOutDurationMs;
  bool get gaplessEnabled => _gaplessEnabled;

  /// 启动时初始化，从本地读取
  static Future<PlayerStateStorage> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final state = PlayerStateStorage._();

    state._isPlaying = prefs.getBool(_isPlayingKey) ?? false;

    // 兼容旧版本：历史数据以「秒」为单位存储，从 1.0 开始改为毫秒。
    // 为避免老数据恢复错误，这里根据数值大小做一次智能判定：
    // - 小于 100000 时按秒处理（约 < 27 小时）
    // - 否则按毫秒处理
    final rawPosition = prefs.getInt(_positionKey) ?? 0;
    if (rawPosition <= 0) {
      state._position = Duration.zero;
    } else if (rawPosition < 100000) {
      state._position = Duration(seconds: rawPosition);
    } else {
      state._position = Duration(milliseconds: rawPosition);
    }

    // 尝试加载当前歌曲，如果失败则清空（兼容旧版本数据）
    final songJson = prefs.getString(_songKey);
    if (songJson != null) {
      try {
        state._currentSong = Song.fromJson(jsonDecode(songJson));
      } catch (e) {
        // 旧数据格式不兼容，清空
        await prefs.remove(_songKey);
        state._currentSong = null;
      }
    }

    final modeIndex = prefs.getInt(_playModeKey);
    if (modeIndex != null &&
        modeIndex >= 0 &&
        modeIndex < PlayMode.values.length) {
      state._playMode = PlayMode.values[modeIndex];
    }

    state._volume = prefs.getDouble(_volumeKey) ?? 1.0;
    state._bilibiliCacheSizeGB = prefs.getInt(_bilibiliCacheSizeKey) ?? 5;
    state._defaultBilibiliPlayQuality = prefs.getInt(_bilibiliPlayQualityKey) ?? 30232;
    state._lyricsNotificationEnabled = prefs.getBool(_lyricsNotificationEnabledKey) ?? false;
    state._lockScreenEnabled = prefs.getBool(_lockScreenEnabledKey) ?? false;
    state._fadeInDurationMs = prefs.getInt(_fadeInDurationKey) ?? 500;
    state._fadeOutDurationMs = prefs.getInt(_fadeOutDurationKey) ?? 500;
    state._gaplessEnabled = prefs.getBool(_gaplessEnabledKey) ?? true;

    final pageIndex = prefs.getInt(_pageKey);
    if (pageIndex != null &&
        pageIndex >= 0 &&
        pageIndex < PlayerPage.values.length) {
      state._currentPage = PlayerPage.values[pageIndex];
    }

    final sortJsonStr = prefs.getString(_sortKey);
    if (sortJsonStr != null) {
      final Map<String, dynamic> sortJson = jsonDecode(sortJsonStr);
      sortJson.forEach((page, value) {
        state._pageSortStates[page] = SortState.fromJson(value);
      });
    }

    // 尝试加载播放列表，如果失败则清空（兼容旧版本数据）
    final playlistStr = prefs.getString(_playlistKey);
    if (playlistStr != null) {
      try {
        final List<dynamic> listJson = jsonDecode(playlistStr);
        state._playlist = listJson
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // 旧数据格式不兼容，清空
        await prefs.remove(_playlistKey);
        state._playlist = [];
      }
    }

    return state;
  }

  /// 内部保存方法
  Future<void> _savePlaybackState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isPlayingKey, _isPlaying);
    // 从 1.0 开始按毫秒保存播放位置，恢复时会自动兼容旧版本的秒级数据。
    await prefs.setInt(_positionKey, _position.inMilliseconds);
    if (_currentSong != null) {
      await prefs.setString(_songKey, jsonEncode(_currentSong!.toJson()));
    }
  }

  Future<void> _savePlayMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_playModeKey, _playMode.index);
  }

  Future<void> _saveVolume() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, _volume);
  }

  Future<void> _saveCurrentPage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pageKey, _currentPage.index);
  }

  Future<void> _saveSortState() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> jsonMap = {};
    _pageSortStates.forEach((page, sortState) {
      jsonMap[page] = sortState.toJson();
    });
    await prefs.setString(_sortKey, jsonEncode(jsonMap));
  }

  Future<void> _savePlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final listJson = _playlist.map((s) => s.toJson()).toList();
    await prefs.setString(_playlistKey, jsonEncode(listJson));
  }

  Future<void> _saveBilibiliCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bilibiliCacheSizeKey, _bilibiliCacheSizeGB);
  }

  Future<void> _saveBilibiliPlayQuality() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bilibiliPlayQualityKey, _defaultBilibiliPlayQuality);
  }

  Future<void> _saveLyricsNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lyricsNotificationEnabledKey, _lyricsNotificationEnabled);
  }

  Future<void> _saveLockScreenEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockScreenEnabledKey, _lockScreenEnabled);
  }
}

/// 对外操作扩展
extension PlayerStateSetters on PlayerStateStorage {
  Future<void> setCurrentSong(Song song) async {
    _currentSong = song;
    await _savePlaybackState();
  }

  Future<void> setPlaylist(List<Song> songs) async {
    _playlist = songs;
    await _savePlaylist();
  }

  Future<void> addToPlaylist(Song song) async {
    _playlist.add(song);
    await _savePlaylist();
  }

  Future<void> removeFromPlaylist(Song song) async {
    _playlist.removeWhere((s) => s.id == song.id);
    await _savePlaylist();
  }

  Future<void> setPlayingState(bool playing, {Duration? pos}) async {
    _isPlaying = playing;
    if (pos != null) _position = pos;
    await _savePlaybackState();
  }

  Future<void> setPlayMode(PlayMode mode) async {
    _playMode = mode;
    await _savePlayMode();
  }

  Future<void> setVolume(double vol) async {
    _volume = vol;
    await _saveVolume();
  }

  Future<void> setCurrentPage(PlayerPage page) async {
    _currentPage = page;
    await _saveCurrentPage();
  }

  Future<void> setPageSort(
    String page,
    String? field,
    String? direction,
  ) async {
    _pageSortStates[page] = SortState(field: field, direction: direction);
    await _saveSortState();
  }

  SortState getPageSort(String page) => _pageSortStates[page] ?? SortState();

  Future<void> setBilibiliCacheSize(int sizeGB) async {
    // 为避免设置页错误导致崩溃，这里做安全收敛。
    final clamped = sizeGB.clamp(1, 50);
    _bilibiliCacheSizeGB = clamped;
    await _saveBilibiliCacheSize();
  }

  Future<void> setDefaultBilibiliPlayQuality(int qualityId) async {
    _defaultBilibiliPlayQuality = qualityId;
    await _saveBilibiliPlayQuality();
  }

  Future<void> setLyricsNotificationEnabled(bool enabled) async {
    _lyricsNotificationEnabled = enabled;
    await _saveLyricsNotificationEnabled();
  }

  Future<void> setLockScreenEnabled(bool enabled) async {
    _lockScreenEnabled = enabled;
    await _saveLockScreenEnabled();
  }

  Future<void> setFadeInDuration(int durationMs) async {
    _fadeInDurationMs = durationMs.clamp(0, 3000);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PlayerStateStorage._fadeInDurationKey, _fadeInDurationMs);
  }

  Future<void> setFadeOutDuration(int durationMs) async {
    _fadeOutDurationMs = durationMs.clamp(0, 3000);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PlayerStateStorage._fadeOutDurationKey, _fadeOutDurationMs);
  }

  Future<void> setGaplessEnabled(bool enabled) async {
    _gaplessEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PlayerStateStorage._gaplessEnabledKey, enabled);
  }
}
