import '../config_module.dart';
import '../../storage/player_state_storage.dart';
import '../../contants/app_contants.dart' show PlayMode, SortState;

class PlayerPrefsConfigModule extends ConfigModule {
  @override
  String get id => 'player_prefs';

  @override
  String get name => '播放偏好';

  @override
  String get description => '播放模式、音量、排序、歌词与无缝播放等';

  @override
  int get version => 1;

  @override
  Future<Map<String, dynamic>> exportData(
      {bool includeSensitive = false}) async {
    final storage = await PlayerStateStorage.getInstance();
    return {
      'playMode': storage.playMode.index,
      'volume': storage.volume,
      'pageSortStates': storage.pageSortStates
          .map((k, v) => MapEntry(k, v.toJson())),
      'bilibiliCacheSizeGB': storage.bilibiliCacheSizeGB,
      'defaultBilibiliPlayQuality': storage.defaultBilibiliPlayQuality,
      'lyricsNotificationEnabled': storage.lyricsNotificationEnabled,
      'lockScreenEnabled': storage.lockScreenEnabled,
      'fadeInDurationMs': storage.fadeInDurationMs,
      'fadeOutDurationMs': storage.fadeOutDurationMs,
      'gaplessEnabled': storage.gaplessEnabled,
    };
  }

  @override
  Future<void> importData(Map<String, dynamic> data,
      {required bool merge}) async {
    final storage = await PlayerStateStorage.getInstance();

    int? _readInt(String key) {
      if (!data.containsKey(key)) return null;
      final raw = data[key];
      return raw is int ? raw : int.tryParse(raw.toString());
    }

    double? _readDouble(String key) {
      if (!data.containsKey(key)) return null;
      final raw = data[key];
      return raw is double ? raw : double.tryParse(raw.toString());
    }

    bool? _readBool(String key) {
      if (!data.containsKey(key)) return null;
      final raw = data[key];
      if (raw is bool) return raw;
      final s = raw.toString().toLowerCase();
      return s == 'true' || s == '1';
    }

    final playModeIndex = _readInt('playMode');
    if (playModeIndex != null &&
        playModeIndex >= 0 &&
        playModeIndex < PlayMode.values.length) {
      await storage.setPlayMode(PlayMode.values[playModeIndex]);
    }

    final volume = _readDouble('volume');
    if (volume != null) {
      await storage.setVolume(volume.clamp(0.0, 1.0));
    }

    final pageSortStates = data['pageSortStates'];
    if (pageSortStates is Map) {
      for (final entry in pageSortStates.entries) {
        final page = entry.key.toString();
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          final sort = SortState.fromJson(value);
          await storage.setPageSort(page, sort.field, sort.direction);
        }
      }
    }

    final cacheSize = _readInt('bilibiliCacheSizeGB');
    if (cacheSize != null) {
      await storage.setBilibiliCacheSize(cacheSize);
    }

    final playQuality = _readInt('defaultBilibiliPlayQuality');
    if (playQuality != null) {
      await storage.setDefaultBilibiliPlayQuality(playQuality);
    }

    final lyricsNotificationEnabled =
        _readBool('lyricsNotificationEnabled');
    if (lyricsNotificationEnabled != null) {
      await storage.setLyricsNotificationEnabled(lyricsNotificationEnabled);
    }

    final lockScreenEnabled = _readBool('lockScreenEnabled');
    if (lockScreenEnabled != null) {
      await storage.setLockScreenEnabled(lockScreenEnabled);
    }

    final fadeInDurationMs = _readInt('fadeInDurationMs');
    if (fadeInDurationMs != null) {
      await storage.setFadeInDuration(fadeInDurationMs);
    }

    final fadeOutDurationMs = _readInt('fadeOutDurationMs');
    if (fadeOutDurationMs != null) {
      await storage.setFadeOutDuration(fadeOutDurationMs);
    }

    final gaplessEnabled = _readBool('gaplessEnabled');
    if (gaplessEnabled != null) {
      await storage.setGaplessEnabled(gaplessEnabled);
    }
  }
}

