import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 简化的元数据存储类
class CachedMetadata {
  final String filePath;
  final int fileSize;
  final DateTime lastModified;
  final Map<String, dynamic> metadataMap;
  final DateTime cachedAt;
  final String? artworkBase64;

  CachedMetadata({
    required this.filePath,
    required this.fileSize,
    required this.lastModified,
    required this.metadataMap,
    required this.cachedAt,
    this.artworkBase64,
  });

  /// 检查文件是否已修改
  bool isFileModified(File file) {
    final stat = file.statSync();
    return stat.size != fileSize || stat.modified != lastModified;
  }

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'fileSize': fileSize,
        'lastModified': lastModified.toIso8601String(),
        'metadata': metadataMap,
        'cachedAt': cachedAt.toIso8601String(),
        if (artworkBase64 != null) 'artwork': artworkBase64,
      };

  static CachedMetadata fromJson(Map<String, dynamic> json) {
    return CachedMetadata(
      filePath: json['filePath'] as String,
      fileSize: json['fileSize'] as int,
      lastModified: DateTime.parse(json['lastModified'] as String),
      metadataMap: json['metadata'] as Map<String, dynamic>,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      artworkBase64: json['artwork'] as String?,
    );
  }

  MetadataResult toResult() => MetadataResult(
        metadataMap: metadataMap,
        artworkBytes:
            artworkBase64 != null ? base64Decode(artworkBase64!) : null,
      );
}

/// 元数据读取结果（包含封面等附加数据）
class MetadataResult {
  final Map<String, dynamic> metadataMap;
  final Uint8List? artworkBytes;

  const MetadataResult({
    required this.metadataMap,
    this.artworkBytes,
  });

  String? get title => metadataMap['title'] as String?;
  String? get artist => metadataMap['artist'] as String?;
  String? get album => metadataMap['album'] as String?;
  String? get lyrics => metadataMap['lyrics'] as String?;
  int? get bitrate =>metadataMap['bitrate'] as int?;
  int? get sampleRate => metadataMap['sampleRate'] as int?;
  Duration? get duration =>
      metadataMap['duration'] != null && metadataMap['duration'] is int
          ? Duration(seconds: metadataMap['duration'] as int)
          : null;

  bool get hasArtwork => artworkBytes != null && artworkBytes!.isNotEmpty;
}

/// 元数据缓存服务
/// 解决：1) 避免重复解析音频文件 2) 使用文件路径哈希作为唯一标识
class MetadataCacheService {
  static MetadataCacheService? _instance;
  static MetadataCacheService get instance => _instance ??= MetadataCacheService._();

  MetadataCacheService._();

  String? _cacheDir;

  /// 初始化缓存目录
  Future<void> init() async {
    final appDir = await getApplicationSupportDirectory();
    _cacheDir = p.join(appDir.path, 'metadata_cache');
    await Directory(_cacheDir!).create(recursive: true);
    print('✅ MetadataCacheService 初始化完成: $_cacheDir');
  }

  /// 生成文件路径的哈希值（作为唯一标识）
  String _generateFileHash(String filePath) {
    return md5.convert(utf8.encode(filePath)).toString();
  }

  /// 获取缓存文件路径
  String _getCacheFilePath(String filePath) {
    final hash = _generateFileHash(filePath);
    return p.join(_cacheDir!, '$hash.json');
  }

  /// 将元数据对象转为 Map
  Map<String, dynamic> _metadataToMap(dynamic metadata) {
    // 安全地提取属性，避免访问不存在的 getter
    try {
      return {
        'title': metadata.title,
        'artist': metadata.artist,
        'album': metadata.album,
        // 注意: genre 属性在当前版本的 audio_metadata_reader 中不存在
        // 'genre': metadata.genre,
        'year': metadata.year,
        'duration': metadata.duration?.inSeconds,
        'trackNumber': metadata.trackNumber,
        'trackTotal': metadata.trackTotal,
        'discNumber': metadata.discNumber,
        'discTotal': metadata.discTotal,
        'lyrics': metadata.lyrics,
        'bitrate': metadata.bitrate,
        'sampleRate': metadata.sampleRate,
      };
    } catch (e) {
      print('⚠️ 元数据转换出错: $e');
      // 如果转换失败，至少返回基本信息
      return {
        'title': metadata.title ?? 'Unknown',
        'artist': metadata.artist ?? 'Unknown Artist',
        'album': metadata.album ?? 'Unknown Album',
      };
    }
  }

  Future<MetadataResult?> getCachedMetadata(
    File audioFile, {
    bool requireArtwork = false,
  }) async {
    final cached = await _loadCachedEntry(
      audioFile,
      requireArtwork: requireArtwork,
    );
    if (cached == null) return null;
    print('🎯 元数据缓存命中: ${audioFile.path}');
    return cached.toResult();
  }

  /// 读取或解析元数据（自动缓存）
  Future<MetadataResult> getOrParseMetadata(
    File audioFile, {
    bool includeArtwork = false,
  }) async {
    final cached = await _loadCachedEntry(
      audioFile,
      requireArtwork: includeArtwork,
    );
    if (cached != null) {
      print('🎯 元数据缓存命中: ${audioFile.path}');
      return cached.toResult();
    }

    final metadata = readMetadata(audioFile, getImage: includeArtwork);
    Uint8List? artworkBytes;
    if (includeArtwork && metadata.pictures.isNotEmpty) {
      artworkBytes = metadata.pictures.first.bytes;
    }

    await cacheMetadata(
      audioFile,
      metadata,
      artworkBytes: artworkBytes,
    );
    return MetadataResult(
      metadataMap: _metadataToMap(metadata),
      artworkBytes: artworkBytes,
    );
  }

  /// 缓存元数据
  Future<void> cacheMetadata(
    File audioFile,
    dynamic metadata, {
    Uint8List? artworkBytes,
  }) async {
    try {
      final stat = audioFile.statSync();
      final cached = CachedMetadata(
        filePath: audioFile.path,
        fileSize: stat.size,
        lastModified: stat.modified,
        metadataMap: _metadataToMap(metadata),
        cachedAt: DateTime.now(),
        artworkBase64: artworkBytes != null ? base64Encode(artworkBytes) : null,
      );

      final cacheFile = File(_getCacheFilePath(audioFile.path));
      await cacheFile.writeAsString(jsonEncode(cached.toJson()));
      print('✅ 元数据缓存写入: ${audioFile.path}');
    } catch (e) {
      print('⚠️ 元数据缓存写入失败: ${audioFile.path} - $e');
    }
  }

  /// 批量读取元数据（带缓存）
  /// 返回 Map: filePath -> metadata object (from readMetadata)
  Future<Map<String, dynamic>> batchReadMetadata(List<File> files) async {
    final result = <String, dynamic>{};
    final filesToParse = <File>[];

    print('📊 开始批量读取元数据: ${files.length} 个文件');

    // 第一轮：尝试从缓存读取
    for (final file in files) {
      final cached = await getCachedMetadata(file);
      if (cached != null) {
        // 从缓存中恢复，返回 readMetadata 返回的对象
        result[file.path] = cached.metadataMap;
      } else {
        filesToParse.add(file);
      }
    }

    final hitRate = files.isEmpty ? 0.0 : (result.length / files.length * 100);
    print('📊 缓存命中率: ${result.length}/${files.length} (${hitRate.toStringAsFixed(1)}%)');

    // 第二轮：解析未命中的文件
    for (final file in filesToParse) {
      try {
        final metadata = readMetadata(file, getImage: false);
        result[file.path] = _metadataToMap(metadata);

        // 异步缓存（不阻塞）
        cacheMetadata(file, metadata).catchError((e) {
          print('⚠️ 后台缓存失败: ${file.path} - $e');
        });
      } catch (e) {
        print('⚠️ 元数据解析失败: ${file.path} - $e');
      }
    }

    print('✅ 批量读取完成: ${result.length}/${files.length} 成功');
    return result;
  }

  /// 清除指定文件的缓存
  Future<void> clearCache(String filePath) async {
    final cacheFile = File(_getCacheFilePath(filePath));
    if (await cacheFile.exists()) {
      await cacheFile.delete();
      print('🗑️ 元数据缓存删除: $filePath');
    }
  }

  /// 清空所有缓存
  Future<void> clearAllCache() async {
    final dir = Directory(_cacheDir!);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
      print('🗑️ 所有元数据缓存已清空');
    }
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getStats() async {
    final dir = Directory(_cacheDir!);
    if (!await dir.exists()) {
      return {'count': 0, 'size': 0};
    }

    int count = 0;
    int totalSize = 0;

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        count++;
        totalSize += await entity.length();
      }
    }

    return {
      'count': count,
      'size': totalSize,
      'size_mb': (totalSize / 1024 / 1024).toStringAsFixed(2),
    };
  }

  Future<CachedMetadata?> _loadCachedEntry(
    File audioFile, {
    bool requireArtwork = false,
  }) async {
    final cacheFile = File(_getCacheFilePath(audioFile.path));

    if (!await cacheFile.exists()) {
      return null;
    }

    try {
      final json =
          jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>;
      final cached = CachedMetadata.fromJson(json);

      if (cached.isFileModified(audioFile)) {
        print('⚠️ 文件已修改，删除缓存: ${audioFile.path}');
        await cacheFile.delete();
        return null;
      }

      if (requireArtwork && cached.artworkBase64 == null) {
        // 旧版本缓存缺少封面信息，视为未命中
        return null;
      }

      return cached;
    } catch (e) {
      print('⚠️ 元数据缓存解析失败: ${audioFile.path} - $e');
      await cacheFile.delete();
      return null;
    }
  }
}
