import 'package:drift/drift.dart';

import '../config_module.dart';
import '../../database/database.dart';

class UserSettingsConfigModule extends ConfigModule {
  UserSettingsConfigModule(this._db);

  final MusicDatabase _db;

  @override
  String get id => 'user_settings';

  @override
  String get name => 'Bilibili/下载设置';

  @override
  String get description => '音质偏好、下载策略、缓存上限等';

  @override
  int get version => 1;

  @override
  Future<Map<String, dynamic>> exportData(
      {bool includeSensitive = false}) async {
    final settings = await _db.getUserSettings();
    return {
      'defaultPlayQuality': settings.defaultPlayQuality,
      'defaultDownloadQuality': settings.defaultDownloadQuality,
      'autoSelectQuality': settings.autoSelectQuality,
      'wifiOnlyDownload': settings.wifiOnlyDownload,
      'maxConcurrentDownloads': settings.maxConcurrentDownloads,
      'autoRetryFailed': settings.autoRetryFailed,
      'autoCacheSizeGB': settings.autoCacheSizeGB,
      'downloadDirectory': settings.downloadDirectory,
    };
  }

  @override
  Future<void> importData(Map<String, dynamic> data,
      {required bool merge}) async {
    final existing = await _db.getUserSettings();

    int? _readInt(String key) {
      if (!data.containsKey(key)) return null;
      final raw = data[key];
      return raw is int ? raw : int.tryParse(raw.toString());
    }

    bool? _readBool(String key) {
      if (!data.containsKey(key)) return null;
      final raw = data[key];
      if (raw is bool) return raw;
      final s = raw.toString().toLowerCase();
      return s == 'true' || s == '1';
    }

    String? _readStringNullable(String key) {
      if (!data.containsKey(key)) return null;
      final raw = data[key];
      return raw == null ? null : raw.toString();
    }

    final updated = existing.copyWith(
      defaultPlayQuality:
          _readInt('defaultPlayQuality') ?? existing.defaultPlayQuality,
      defaultDownloadQuality: _readInt('defaultDownloadQuality') ??
          existing.defaultDownloadQuality,
      autoSelectQuality:
          _readBool('autoSelectQuality') ?? existing.autoSelectQuality,
      wifiOnlyDownload:
          _readBool('wifiOnlyDownload') ?? existing.wifiOnlyDownload,
      maxConcurrentDownloads: _readInt('maxConcurrentDownloads') ??
          existing.maxConcurrentDownloads,
      autoRetryFailed:
          _readBool('autoRetryFailed') ?? existing.autoRetryFailed,
      autoCacheSizeGB:
          _readInt('autoCacheSizeGB') ?? existing.autoCacheSizeGB,
      downloadDirectory: data.containsKey('downloadDirectory')
          ? Value(_readStringNullable('downloadDirectory'))
          : const Value.absent(),
    );

    await _db.updateUserSettings(updated);
  }
}
