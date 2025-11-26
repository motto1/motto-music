import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:motto_music/models/bilibili/audio_quality.dart';
import 'package:motto_music/services/bilibili/stream_service.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/storage/player_state_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Bilibili 自动缓存服务（LockCachingAudioSource 方案）
/// 通过 just_audio 的 LockCachingAudioSource 在播放时同步写入缓存文件，
/// 并以内置 LRU 机制控制缓存空间。
class BilibiliAutoCacheService {
  static BilibiliAutoCacheService? _instance;

  final BilibiliStreamService _streamService;
  final CookieManager _cookieManager;

  late final String _cacheDirectoryPath;
  bool _initialized = false;
  bool _cleaning = false;

  BilibiliAutoCacheService._({
    required BilibiliStreamService streamService,
    required CookieManager cookieManager,
  })  : _streamService = streamService,
        _cookieManager = cookieManager;

  static Future<BilibiliAutoCacheService> getInstance({
    required BilibiliStreamService streamService,
    required CookieManager cookieManager,
  }) async {
    if (_instance == null) {
      _instance = BilibiliAutoCacheService._(
        streamService: streamService,
        cookieManager: cookieManager,
      );
      await _instance!._ensureInitialized();
    }
    return _instance!;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final cacheDir = await getApplicationCacheDirectory();
    _cacheDirectoryPath = p.join(cacheDir.path, 'bilibili_auto');
    final dir = Directory(_cacheDirectoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _purgeTempFiles();
    _initialized = true;
    print('📁 初始化 Bilibili 自动缓存（LockCachingAudioSource 模式）: $_cacheDirectoryPath');
  }

  Future<void> _purgeTempFiles() async {
    final dir = Directory(_cacheDirectoryPath);
    await for (final entity in dir.list(recursive: false)) {
      if (entity is File && entity.path.endsWith('.part')) {
        await entity.delete().catchError((_) {});
      }
    }
  }

  String _cacheFilePath(
    String bvid,
    int cid,
    BilibiliAudioQuality quality,
  ) =>
      p.join(_cacheDirectoryPath, '${bvid}_${cid}_${quality.id}.m4s');

  /// 如果缓存文件存在，直接返回对应 File
  Future<File?> getCachedAudioFile({
    required String bvid,
    required int cid,
    required BilibiliAudioQuality quality,
  }) async {
    await _ensureInitialized();
    final file = File(_cacheFilePath(bvid, cid, quality));
    if (await file.exists()) {
      await _touchFile(file);
      return file;
    }
    return null;
  }

  /// 检查缓存是否命中
  Future<bool> isCached({
    required String bvid,
    required int cid,
    required BilibiliAudioQuality quality,
  }) async =>
      await getCachedAudioFile(bvid: bvid, cid: cid, quality: quality) != null;

  /// 获取缓存状态（无/进行中/完成）
  Future<AutoCacheState> getCacheState({
    required String bvid,
    required int cid,
    required BilibiliAudioQuality quality,
  }) async {
    await _ensureInitialized();
    final cacheFile = File(_cacheFilePath(bvid, cid, quality));
    if (await cacheFile.exists()) {
      return AutoCacheState.cached;
    }
    final partialFile = File('${cacheFile.path}.part');
    if (await partialFile.exists()) {
      return AutoCacheState.caching;
    }
    return AutoCacheState.none;
  }

  /// 创建 LockCachingAudioSource，在播放的同时写入缓存
  Future<LockCachingAudioSource> createLockCachingAudioSource({
    required String bvid,
    required int cid,
    required BilibiliAudioQuality quality,
  }) async {
    await _ensureInitialized();
    final streamInfo = await _streamService.getAudioStream(
      bvid: bvid,
      cid: cid,
      quality: quality,
    );
    final cacheFile = File(_cacheFilePath(bvid, cid, quality));
    await cacheFile.parent.create(recursive: true);

    final source = LockCachingAudioSource(
      Uri.parse(streamInfo.url),
      headers: await _buildHeaders(),
      cacheFile: cacheFile,
      onCacheDone: (_) async {
        await _touchFile(cacheFile);
        await _enforceCacheLimit();
      },
    );

    return source;
  }

  Future<Map<String, String>> _buildHeaders() async {
    final cookie = await _cookieManager.getCookieString();
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://www.bilibili.com',
      if (cookie.isNotEmpty) 'Cookie': cookie,
    };
  }

  Future<void> _touchFile(File file) async {
    final now = DateTime.now();
    try {
      await file.setLastAccessed(now);
    } catch (_) {}
    try {
      await file.setLastModified(now);
    } catch (_) {}
  }

  Future<void> removeCachedAudio({
    required String bvid,
    required int cid,
    required BilibiliAudioQuality quality,
  }) async {
    await _ensureInitialized();
    final path = _cacheFilePath(bvid, cid, quality);
    await _deleteCacheFiles(path);
  }

  Future<void> clearAllCache() async {
    await _ensureInitialized();
    final dir = Directory(_cacheDirectoryPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
  }

  Future<AutoCacheStatistics> getCacheStatistics() async {
    await _ensureInitialized();
    final entries = await _collectCacheEntries();
    final totalSize = entries.fold<int>(0, (sum, e) => sum + e.size);
    final maxSize = await _getMaxCacheSizeBytes();

    return AutoCacheStatistics(
      totalSizeBytes: totalSize,
      fileCount: entries.length,
      maxSizeBytes: maxSize,
    );
  }

  Future<int> _getMaxCacheSizeBytes() async {
    final storage = await PlayerStateStorage.getInstance();
    return storage.bilibiliCacheSizeGB * 1024 * 1024 * 1024;
  }

  Future<void> _enforceCacheLimit() async {
    if (_cleaning) return;
    _cleaning = true;
    try {
      final entries = await _collectCacheEntries();
      var totalSize = entries.fold<int>(0, (sum, e) => sum + e.size);
      final maxSize = await _getMaxCacheSizeBytes();
      if (totalSize <= maxSize) {
        return;
      }
      entries.sort((a, b) => a.lastAccess.compareTo(b.lastAccess));
      final targetSize = (maxSize * 0.8).round();
      for (final entry in entries) {
        if (totalSize <= targetSize) break;
        await _deleteCacheFiles(entry.file.path);
        totalSize -= entry.size;
      }
    } finally {
      _cleaning = false;
    }
  }

  Future<List<_CacheEntry>> _collectCacheEntries() async {
    final dir = Directory(_cacheDirectoryPath);
    final result = <_CacheEntry>[];
    if (!await dir.exists()) {
      return result;
    }
    await for (final entity in dir.list(recursive: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (path.endsWith('.part')) {
        await entity.delete().catchError((_) {});
        continue;
      }
      if (path.endsWith('.mime')) {
        // .mime 文件伴随主文件，统计时忽略，删除时一并清理
        continue;
      }
      final stat = await entity.stat();
      result.add(
        _CacheEntry(
          file: entity,
          size: stat.size,
          lastAccess: stat.modified,
        ),
      );
    }
    return result;
  }

  Future<void> _deleteCacheFiles(String basePath) async {
    final mainFile = File(basePath);
    if (await mainFile.exists()) {
      await mainFile.delete().catchError((_) {});
    }
    final mimeFile = File('$basePath.mime');
    if (await mimeFile.exists()) {
      await mimeFile.delete().catchError((_) {});
    }
    final partFile = File('$basePath.part');
    if (await partFile.exists()) {
      await partFile.delete().catchError((_) {});
    }
  }
}

class _CacheEntry {
  final File file;
  final int size;
  final DateTime lastAccess;

  _CacheEntry({
    required this.file,
    required this.size,
    required this.lastAccess,
  });
}

/// 自动缓存状态
enum AutoCacheState {
  none,
  caching,
  cached,
}

/// 自动缓存统计信息
class AutoCacheStatistics {
  final int totalSizeBytes;
  final int fileCount;
  final int maxSizeBytes;

  AutoCacheStatistics({
    required this.totalSizeBytes,
    required this.fileCount,
    required this.maxSizeBytes,
  });

  /// 缓存使用百分比
  double get usagePercentage =>
      maxSizeBytes > 0 ? (totalSizeBytes / maxSizeBytes * 100).clamp(0, 100) : 0;

  /// 格式化的总大小
  String get formattedTotalSize {
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(2)} KB';
    } else if (totalSizeBytes < 1024 * 1024 * 1024) {
      return '${(totalSizeBytes / 1024 / 1024).toStringAsFixed(2)} MB';
    } else {
      return '${(totalSizeBytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
  }

  /// 格式化的最大大小
  String get formattedMaxSize {
    return '${(maxSizeBytes / 1024 / 1024 / 1024).toStringAsFixed(0)} GB';
  }

  @override
  String toString() {
    return 'AutoCacheStatistics(文件数: $fileCount, 大小: $formattedTotalSize / $formattedMaxSize, 使用率: ${usagePercentage.toStringAsFixed(1)}%)';
  }
}
