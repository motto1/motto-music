import 'dart:io';
import 'package:dio/dio.dart';
import 'package:motto_music/database/database.dart';
import 'package:motto_music/services/bilibili/stream_service.dart';
import 'package:motto_music/models/bilibili/audio_quality.dart';
import 'package:motto_music/utils/common_utils.dart';
import 'package:motto_music/storage/player_state_storage.dart';
import 'package:path/path.dart' as p;

/// Bilibili 本地音频缓存服务
/// 
/// 功能：
/// - 下载 Bilibili 音频到本地存储
/// - LRU 缓存管理（默认 5GB 限制）
/// - 自动清理过期文件
class BilibiliAudioCacheService {
  final MusicDatabase _db;
  final BilibiliStreamService _streamService;
  final Dio _dio;
  
  /// 缓存目录路径
  late final String _cacheDirectoryPath;
  
  /// 暴露 StreamService 给外部使用
  BilibiliStreamService get streamService => _streamService;
  
  /// 动态获取缓存大小限制
  Future<int> get _maxCacheSizeBytes async {
    final storage = await PlayerStateStorage.getInstance();
    return storage.bilibiliCacheSizeGB * 1024 * 1024 * 1024;
  }
  
  BilibiliAudioCacheService(
    this._db,
    this._streamService,
  ) : _dio = Dio() {
    _initCacheDirectory();
  }
  
  /// 初始化缓存目录
  Future<void> _initCacheDirectory() async {
    final baseDir = await CommonUtils.getAppBaseDirectory();
    _cacheDirectoryPath = p.join(baseDir, 'bilibili_audio_cache');
    
    final cacheDir = Directory(_cacheDirectoryPath);
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
      print('📁 创建缓存目录: $_cacheDirectoryPath');
    }
  }
  
  /// 获取缓存的音频文件路径
  /// 
  /// 如果本地缓存存在则返回本地路径，否则返回 null
  Future<String?> getCachedAudioPath({
    required String bvid,
    required int cid,
    required BilibiliAudioQuality quality,
  }) async {
    final cache = await _db.getCachedAudio(
      bvid: bvid,
      cid: cid,
      quality: quality.id,
    );
    
    if (cache == null) {
      return null;
    }
    
    // 验证文件是否存在
    final file = File(cache.localFilePath);
    if (!await file.exists()) {
      // 文件不存在，删除数据库记录
      print('⚠️ 缓存文件不存在，删除记录: ${cache.localFilePath}');
      await _db.deleteCachedAudio(cache.id);
      return null;
    }
    
    print('✅ 使用本地缓存: ${cache.localFilePath}');
    return cache.localFilePath;
  }
  
  /// 后台下载并缓存音频文件（不阻塞播放）
  /// 
  /// 返回 Future，但调用方可以不等待
  Future<String> downloadInBackground({
    required String bvid,
    required int cid,
    required BilibiliAudioQuality quality,
  }) async {
    try {
      print('🔽 后台下载: $bvid (CID: $cid, 音质: ${quality.displayName})');
      
      // 1. 获取音频流 URL
      final streamInfo = await _streamService.getAudioStream(
        bvid: bvid,
        cid: cid,
        quality: quality,
      );
      
      // 2. 生成本地文件路径
      final fileName = '${bvid}_${cid}_${quality.id}.m4s';
      final localFilePath = p.join(_cacheDirectoryPath, fileName);
      
      // 3. 下载文件（静默下载，不显示详细进度）
      await _dio.download(
        streamInfo.url,
        localFilePath,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://www.bilibili.com',
          },
        ),
      );
      
      // 4. 获取文件大小
      final file = File(localFilePath);
      final fileSize = await file.length();
      
      print('✅ 后台下载完成: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      // 5. 保存到数据库
      await _db.saveCachedAudio(
        BilibiliAudioCacheCompanion.insert(
          bvid: bvid,
          cid: cid,
          quality: quality.id,
          localFilePath: localFilePath,
          fileSize: fileSize,
          lastAccessTime: DateTime.now(),
        ),
      );
      
      // 6. 检查并清理缓存
      await _checkAndCleanCache();
      
      return localFilePath;
    } catch (e) {
      print('❌ 后台下载失败: $e');
      rethrow;
    }
  }
  
  /// 下载并缓存音频文件
  /// 
  /// 返回本地文件路径
  Future<String> downloadAndCacheAudio({
    required String bvid,
    required int cid,
    required BilibiliAudioQuality quality,
    Function(int received, int total)? onProgress,
  }) async {
    print('🔽 开始下载音频: $bvid (CID: $cid, 音质: ${quality.displayName})');
    
    // 1. 获取音频流 URL
    final streamInfo = await _streamService.getAudioStream(
      bvid: bvid,
      cid: cid,
      quality: quality,
    );
    
    // 2. 生成本地文件路径
    final fileName = '${bvid}_${cid}_${quality.id}.m4s';
    final localFilePath = p.join(_cacheDirectoryPath, fileName);
    
    // 3. 下载文件
    await _dio.download(
      streamInfo.url,
      localFilePath,
      options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://www.bilibili.com',
        },
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final progress = (received / total * 100).toStringAsFixed(1);
          print('  下载进度: $progress% ($received/$total)');
        }
        onProgress?.call(received, total);
      },
    );
    
    // 4. 获取文件大小
    final file = File(localFilePath);
    final fileSize = await file.length();
    
    print('✅ 下载完成: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
    
    // 5. 保存到数据库
    await _db.saveCachedAudio(
      BilibiliAudioCacheCompanion.insert(
        bvid: bvid,
        cid: cid,
        quality: quality.id,
        localFilePath: localFilePath,
        fileSize: fileSize,
        lastAccessTime: DateTime.now(),
      ),
    );
    
    // 6. 检查并清理缓存
    await _checkAndCleanCache();
    
    return localFilePath;
  }
  
  /// 获取或下载音频文件
  /// 
  /// 优先使用本地缓存，如果不存在则下载
  Future<String> getOrDownloadAudio({
    required String bvid,
    required int cid,
    required BilibiliAudioQuality quality,
    Function(int received, int total)? onProgress,
  }) async {
    // 1. 尝试从缓存获取
    final cachedPath = await getCachedAudioPath(
      bvid: bvid,
      cid: cid,
      quality: quality,
    );
    
    if (cachedPath != null) {
      return cachedPath;
    }
    
    // 2. 缓存不存在，下载文件
    return await downloadAndCacheAudio(
      bvid: bvid,
      cid: cid,
      quality: quality,
      onProgress: onProgress,
    );
  }
  
  /// 检查并清理缓存（LRU 策略）
  Future<void> _checkAndCleanCache() async {
    final totalSize = await _db.getTotalCacheSize();
    final maxSize = await _maxCacheSizeBytes;
    
    print('📊 当前缓存大小: ${(totalSize / 1024 / 1024 / 1024).toStringAsFixed(2)} GB');
    
    if (totalSize <= maxSize) {
      return;
    }
    
    print('⚠️ 缓存超出限制，开始清理...');
    
    // 获取所有缓存，按最后访问时间排序（最旧的在前）
    final allCaches = await _db.getAllCaches(oldestFirst: true);
    
    int freedSize = 0;
    int deletedCount = 0;
    
    // 删除最旧的文件，直到释放足够空间
    for (final cache in allCaches) {
      if (totalSize - freedSize <= maxSize * 0.8) {
        // 清理到 80% 就停止
        break;
      }
      
      // 删除物理文件
      final file = File(cache.localFilePath);
      if (await file.exists()) {
        await file.delete();
        print('  🗑️ 删除: ${p.basename(cache.localFilePath)}');
      }
      
      // 删除数据库记录
      await _db.deleteCachedAudio(cache.id);
      
      freedSize += cache.fileSize;
      deletedCount++;
    }
    
    print('✅ 清理完成: 删除 $deletedCount 个文件，释放 ${(freedSize / 1024 / 1024).toStringAsFixed(2)} MB');
  }
  
  /// 手动清理所有缓存
  Future<void> clearAllCache() async {
    print('🗑️ 清理所有音频缓存...');
    
    // 1. 获取所有缓存记录
    final allCaches = await _db.getAllCaches(oldestFirst: false);
    
    // 2. 删除所有物理文件
    for (final cache in allCaches) {
      final file = File(cache.localFilePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    // 3. 清空数据库
    final deletedCount = await _db.clearAllAudioCache();
    
    print('✅ 已清理 $deletedCount 个缓存文件');
  }
  
  /// 获取缓存统计信息
  Future<CacheStatistics> getCacheStatistics() async {
    final totalSize = await _db.getTotalCacheSize();
    final count = await _db.getCacheCount();
    final maxSize = await _maxCacheSizeBytes;
    
    return CacheStatistics(
      totalSizeBytes: totalSize,
      fileCount: count,
      maxSizeBytes: maxSize,
    );
  }
  
  /// 获取缓存目录路径
  String get cacheDirectoryPath => _cacheDirectoryPath;
  
  /// 删除指定歌曲的缓存
  Future<void> deleteSongCache({
    required String bvid,
    required int cid,
  }) async {
    print('🗑️ 删除歌曲缓存: $bvid (CID: $cid)');
    
    // 获取该歌曲的所有缓存（所有音质）
    final allCaches = await _db.getAllCaches(oldestFirst: false);
    final songCaches = allCaches.where(
      (c) => c.bvid == bvid && c.cid == cid,
    );
    
    // 删除物理文件
    for (final cache in songCaches) {
      final file = File(cache.localFilePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    // 删除数据库记录
    await _db.deleteCachedAudioByBvidCid(bvid: bvid, cid: cid);
    
    print('✅ 已删除 ${songCaches.length} 个缓存文件');
  }
}

/// 缓存统计信息
class CacheStatistics {
  final int totalSizeBytes;
  final int fileCount;
  final int maxSizeBytes;
  
  CacheStatistics({
    required this.totalSizeBytes,
    required this.fileCount,
    required this.maxSizeBytes,
  });
  
  /// 缓存使用百分比
  double get usagePercentage => (totalSizeBytes / maxSizeBytes * 100).clamp(0, 100);
  
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
    return 'CacheStatistics(文件数: $fileCount, 大小: $formattedTotalSize / $formattedMaxSize, 使用率: ${usagePercentage.toStringAsFixed(1)}%)';
  }
}
