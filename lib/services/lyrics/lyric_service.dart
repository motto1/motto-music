import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:motto_music/models/lyrics/lyric_models.dart';
import 'package:motto_music/services/lyrics/netease_api.dart';
import 'package:motto_music/database/database.dart';

class LyricService {
  final NeteaseApi _neteaseApi;
  final MusicDatabase _db;

  LyricService(this._neteaseApi, this._db);

  /// 生成歌曲的唯一标识（支持本地文件和 Bilibili 来源）
  ///
  /// ⭐ 公开方法，供外部调用以确保一致性
  String generateUniqueKey(Song track) {
    return _generateUniqueKey(track);
  }

  /// 生成未哈希的原始键（用于数据库存储，便于调试）
  String generateRawKey(Song track) {
    if (track.source == 'bilibili' && track.bvid != null) {
      final bvid = track.bvid!;
      final cid = track.cid ?? 0;
      return 'bilibili_${bvid}_$cid';
    }

    final title = _normalizeText(track.title);
    final artist = _normalizeText(track.artist ?? '未知艺术家');
    final duration = track.duration ?? 0;

    if (title.isNotEmpty && artist != '未知艺术家') {
      return 'local_${title}_${artist}_$duration';
    }

    if (track.filePath.isNotEmpty) {
      return 'file_${track.filePath}';
    }

    return 'fallback_${track.id}';
  }

  /// 内部实现：生成歌曲的唯一标识
  ///
  /// 策略：
  /// 1. Bilibili 歌曲：使用 bvid + cid（唯一且稳定）
  /// 2. 本地歌曲：使用 标题 + 艺术家 + 时长（跨文件路径的稳定标识）
  String _generateUniqueKey(Song track) {
    // ========== Bilibili 歌曲 ==========
    // 使用 bvid + cid 作为唯一标识（最稳定）
    if (track.source == 'bilibili' && track.bvid != null) {
      final bvid = track.bvid!;
      final cid = track.cid ?? 0;
      final key = 'bilibili_${bvid}_$cid';
      return md5.convert(utf8.encode(key)).toString();
    }

    // ========== 本地歌曲（优先使用音乐元数据）==========
    // 策略：标题 + 艺术家 + 时长 → 确保同一首歌在不同路径下共享缓存
    final title = _normalizeText(track.title);
    final artist = _normalizeText(track.artist ?? '未知艺术家');
    final duration = track.duration ?? 0;

    // 如果有有效的标题和艺术家，使用元数据作为唯一键
    if (title.isNotEmpty && artist != '未知艺术家') {
      final metadataKey = 'local_${title}_${artist}_$duration';
      return md5.convert(utf8.encode(metadataKey)).toString();
    }

    // ========== 后备方案：使用文件路径 ==========
    // 当元数据不完整时，回退到文件路径（保证有唯一键）
    if (track.filePath.isNotEmpty) {
      final fileKey = 'file_${track.filePath}';
      return md5.convert(utf8.encode(fileKey)).toString();
    }

    // ========== 最后的后备：使用 songId ==========
    // 仅在完全没有其他信息时使用
    return md5.convert(utf8.encode('fallback_${track.id}')).toString();
  }

  /// 标准化文本（用于一致的哈希生成）
  ///
  /// 清理规则：
  /// - 转换为小写（避免大小写差异）
  /// - 去除首尾空白
  /// - 统一空白字符（多个空格合并为一个）
  String _normalizeText(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' '); // 多个空格合并为一个
  }

  /// 清理关键词（移除特殊符号）
  String _cleanKeyword(String keyword) {
    // 优先提取「」或《》中的内容
    final priorityRegex = RegExp(r'《(.+?)》|「(.+?)」');
    final priorityMatch = priorityRegex.firstMatch(keyword);

    if (priorityMatch != null) {
      return priorityMatch.group(1) ?? priorityMatch.group(2) ?? keyword;
    }

    // 移除【】和""中的内容
    final cleaned = keyword.replaceAll(RegExp(r'【.*?】|".*?"'), '').trim();
    return cleaned.isNotEmpty ? cleaned : keyword;
  }

  /// 从多个数据源获取最佳匹配的歌词
  Future<ParsedLrc> getBestMatchedLyrics({
    required Song track,
    String? preciseKeyword,
  }) async {
    try {
      final keyword = preciseKeyword ?? _cleanKeyword(track.title);
      final durationMs = ((track.duration ?? 0) * 1000).toInt();

      return await _neteaseApi.searchBestMatchedLyrics(
        keyword: keyword,
        targetDurationMs: durationMs,
      );
    } catch (e) {
      throw Exception('获取歌词失败: $e');
    }
  }

  /// 获取歌词缓存文件路径
  Future<File> _getLyricCacheFile(String uniqueKey) async {
    final directory = await getApplicationDocumentsDirectory();
    final lyricsDir = Directory('${directory.path}/lyrics');
    
    if (!await lyricsDir.exists()) {
      await lyricsDir.create(recursive: true);
    }

    final fileName = uniqueKey.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return File('${lyricsDir.path}/$fileName.json');
  }

  /// 智能获取歌词（优先从数据库读取）
  Future<ParsedLrc> smartFetchLyrics(Song track) async {
    try {
      // ⭐ 使用原始键（未哈希）存入数据库，便于调试
      final rawKey = generateRawKey(track);
      final hashedKey = _generateUniqueKey(track);

      // 调试日志：显示缓存键生成策略
      _logCacheKeyInfo(track, hashedKey);

      // 1. 优先从数据库读取
      final dbLyric = await (_db.select(_db.songLyrics)
            ..where((t) => t.uniqueKey.equals(rawKey))
            ..where((t) => t.isActive.equals(true))
            ..orderBy([
              // 用户编辑的优先
              (t) => OrderingTerm.desc(t.isUserEdited),
              // 然后按更新时间
              (t) => OrderingTerm.desc(t.updatedAt),
            ])
            ..limit(1))
          .getSingleOrNull();

      if (dbLyric != null) {
        print('✅ 从数据库加载歌词: ${track.title}');
        return _dbLyricToParsedLrc(dbLyric);
      }

      // 2. 兼容旧版：尝试从文件缓存读取
      final cacheFile = await _getLyricCacheFile(hashedKey);
      if (await cacheFile.exists()) {
        try {
          final content = await cacheFile.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final cachedLyrics = ParsedLrc.fromJson(json);

          print('✅ 从文件缓存加载歌词: ${track.title}');

          // 迁移到数据库
          await _saveLyricsToDatabase(
            track: track,
            lyrics: cachedLyrics,
            rawKey: rawKey,
            isUserEdited: cachedLyrics.source == 'local' ||
                          cachedLyrics.source == 'manual',
          );

          if (cachedLyrics.source != 'local' && cachedLyrics.source != 'manual') {
            return cachedLyrics.copyWith(source: 'cache');
          }
          return cachedLyrics;
        } catch (e) {
          print('⚠️ 读取歌词缓存失败: $e');
        }
      }

      print('🌐 从网络获取歌词: ${track.title}');

      // 3. 从网络获取歌词
      final lyrics = await getBestMatchedLyrics(track: track);
      final neteaseLyrics = lyrics.copyWith(source: 'netease');

      // 保存到数据库
      await _saveLyricsToDatabase(
        track: track,
        lyrics: neteaseLyrics,
        rawKey: rawKey,
        isUserEdited: false,
      );

      // 同时保存到文件缓存（兼容性）
      await _saveLyricsToCache(hashedKey, neteaseLyrics);

      return neteaseLyrics;
    } catch (e) {
      throw Exception('智能获取歌词失败: $e');
    }
  }

  /// 将数据库歌词记录转换为 ParsedLrc
  ParsedLrc _dbLyricToParsedLrc(SongLyric dbLyric) {
    // 尝试解析 LRC 格式
    try {
      final parsed = _parseLrcContent(dbLyric.content);
      return ParsedLrc(
        tags: parsed.tags,
        lyrics: parsed.lyrics,
        rawOriginalLyrics: dbLyric.content,
        rawTranslatedLyrics: dbLyric.translatedContent,
        offset: dbLyric.offsetMs / 1000.0,
        source: dbLyric.isUserEdited ? 'local' : dbLyric.source,
      );
    } catch (e) {
      // 解析失败，返回原始内容
      return ParsedLrc(
        tags: const {},
        lyrics: null,
        rawOriginalLyrics: dbLyric.content,
        rawTranslatedLyrics: dbLyric.translatedContent,
        offset: dbLyric.offsetMs / 1000.0,
        source: dbLyric.isUserEdited ? 'local' : dbLyric.source,
      );
    }
  }

  /// 解析 LRC 内容（简化版，复用现有逻辑）
  ParsedLrc _parseLrcContent(String lrcString) {
    if (lrcString.trim().isEmpty) {
      return ParsedLrc(
        tags: const {},
        lyrics: null,
        rawOriginalLyrics: lrcString,
      );
    }

    final lines = lrcString.split('\n');
    final tags = <String, String>{};
    final lyrics = <LyricLine>[];

    final tagRegex = RegExp(r'^\[([a-zA-Z0-9]+):(.+)\]$');
    final timestampRegex = RegExp(r'\[(\d{2,}):(\d{2,})(?:[.:](\d{2,3}))?\]');

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // 解析标签
      final tagMatch = tagRegex.firstMatch(trimmedLine);
      if (tagMatch != null) {
        tags[tagMatch.group(1)!] = tagMatch.group(2)!;
        continue;
      }

      // 解析时间戳歌词
      final timestampMatches = timestampRegex.allMatches(trimmedLine).toList();
      if (timestampMatches.isNotEmpty) {
        final lastTimestamp = timestampMatches.last;
        final contentAfterTimestamp = trimmedLine.substring(lastTimestamp.end).trim();

        if (contentAfterTimestamp.isEmpty) continue;

        for (final match in timestampMatches) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          final fractionalPart = match.group(3) ?? '0';
          final milliseconds = int.parse(fractionalPart.padRight(3, '0'));

          final timestamp = minutes * 60.0 + seconds + milliseconds / 1000.0;

          lyrics.add(LyricLine(
            timestamp: timestamp,
            text: contentAfterTimestamp,
          ));
        }
      }
    }

    lyrics.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return ParsedLrc(
      tags: tags,
      lyrics: lyrics.isEmpty ? null : lyrics,
      rawOriginalLyrics: lrcString,
    );
  }

  /// 保存歌词到数据库
  Future<void> _saveLyricsToDatabase({
    required Song track,
    required ParsedLrc lyrics,
    required String rawKey,
    required bool isUserEdited,
  }) async {
    try {
      // 检查是否已存在
      final existing = await (_db.select(_db.songLyrics)
            ..where((t) => t.uniqueKey.equals(rawKey))
            ..where((t) => t.source.equals(lyrics.source)))
          .getSingleOrNull();

      if (existing != null) {
        // 更新现有记录
        await (_db.update(_db.songLyrics)
              ..where((t) => t.id.equals(existing.id)))
            .write(SongLyricsCompanion(
          content: Value(lyrics.rawOriginalLyrics),
          translatedContent: Value(lyrics.rawTranslatedLyrics),
          offsetMs: Value((lyrics.offset * 1000).round()),
          isUserEdited: Value(isUserEdited),
          updatedAt: Value(DateTime.now()),
        ));
      } else {
        // 插入新记录
        await _db.into(_db.songLyrics).insert(
              SongLyricsCompanion.insert(
                songId: Value(track.id > 0 ? track.id : null),
                uniqueKey: rawKey,
                content: lyrics.rawOriginalLyrics,
                translatedContent: Value(lyrics.rawTranslatedLyrics),
                format: const Value('lrc'),
                language: const Value('unknown'),
                source: Value(lyrics.source),
                offsetMs: Value((lyrics.offset * 1000).round()),
                isUserEdited: Value(isUserEdited),
                isActive: const Value(true),
              ),
            );
      }
    } catch (e) {
      print('⚠️ 保存歌词到数据库失败: $e');
    }
  }

  /// 调试日志：显示缓存键生成策略
  void _logCacheKeyInfo(Song track, String uniqueKey) {
    if (track.source == 'bilibili') {
      print('🔑 [Bilibili] key: $uniqueKey (bvid: ${track.bvid}, cid: ${track.cid})');
    } else {
      final title = _normalizeText(track.title);
      final artist = _normalizeText(track.artist ?? '未知艺术家');
      final hasMetadata = title.isNotEmpty && artist != '未知艺术家';

      if (hasMetadata) {
        print('🔑 [元数据] key: $uniqueKey (标题: $title, 艺术家: $artist, 时长: ${track.duration}s)');
      } else if (track.filePath.isNotEmpty) {
        print('🔑 [文件路径] key: $uniqueKey (路径: ${track.filePath})');
      } else {
        print('🔑 [后备ID] key: $uniqueKey (songId: ${track.id})');
      }
    }
  }

  /// 保存歌词到缓存文件
  Future<void> _saveLyricsToCache(String uniqueKey, ParsedLrc lyrics) async {
    try {
      final cacheFile = await _getLyricCacheFile(uniqueKey);
      final json = jsonEncode(lyrics.toJson());
      await cacheFile.writeAsString(json);
    } catch (e) {
      print('保存歌词缓存失败: $e');
    }
  }

  /// 手动保存歌词（用于手动搜索或编辑后）
  Future<ParsedLrc> saveLyricsToFile({
    required ParsedLrc lyrics,
    required String uniqueKey,
  }) async {
    try {
      await _saveLyricsToCache(uniqueKey, lyrics);
      return lyrics;
    } catch (e) {
      throw Exception('保存歌词文件失败: $e');
    }
  }

  /// 根据搜索结果项获取歌词
  Future<ParsedLrc> fetchLyrics({
    required LyricSearchResult item,
    required String uniqueKey,
  }) async {
    try {
      if (item.source == 'netease') {
        final lyricsResponse = await _neteaseApi.getLyrics(item.remoteId);
        final lyrics = _neteaseApi.parseLyrics(lyricsResponse);
        
        // 标记为网易云来源
        final neteaseeLyrics = lyrics.copyWith(source: 'netease');
        
        // 保存到缓存
        await saveLyricsToFile(lyrics: neteaseeLyrics, uniqueKey: uniqueKey);
        
        return neteaseeLyrics;
      } else {
        throw Exception('未知歌曲源: ${item.source}');
      }
    } catch (e) {
      throw Exception('获取歌词失败: $e');
    }
  }

  /// 手动搜索歌词
  Future<List<LyricSearchResult>> manualSearchLyrics({
    required String keyword,
    int limit = 30,
  }) async {
    try {
      return await _neteaseApi.search(keywords: keyword, limit: limit);
    } catch (e) {
      throw Exception('搜索歌词失败: $e');
    }
  }

  /// 清除所有歌词缓存
  Future<bool> clearAllLyrics() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final lyricsDir = Directory('${directory.path}/lyrics');

      if (await lyricsDir.exists()) {
        await lyricsDir.delete(recursive: true);
        await lyricsDir.create(recursive: true);
        print('歌词缓存已清理');
      }

      return true;
    } catch (e) {
      print('清理歌词缓存失败: $e');
      return false;
    }
  }

  /// 删除单个歌曲的歌词缓存
  Future<bool> deleteLyricCache(String uniqueKey) async {
    try {
      final cacheFile = await _getLyricCacheFile(uniqueKey);
      
      if (await cacheFile.exists()) {
        await cacheFile.delete();
        print('已删除歌词缓存: $uniqueKey');
      }

      return true;
    } catch (e) {
      print('删除歌词缓存失败: $e');
      return false;
    }
  }

  /// 标记歌词为用户编辑
  Future<void> markAsUserEdited(Song track) async {
    final rawKey = generateRawKey(track);
    try {
      await (_db.update(_db.songLyrics)
            ..where((t) => t.uniqueKey.equals(rawKey)))
          .write(SongLyricsCompanion(
        isUserEdited: const Value(true),
        updatedAt: Value(DateTime.now()),
      ));
    } catch (e) {
      print('⚠️ 标记用户编辑失败: $e');
    }
  }
}

// 全局单例 - 延迟初始化
LyricService? _lyricServiceInstance;

LyricService get lyricService {
  _lyricServiceInstance ??= LyricService(neteaseApi, MusicDatabase.database);
  return _lyricServiceInstance!;
}

/// 重新初始化 LyricService（用于数据库重建等场景）
void reinitializeLyricService() {
  _lyricServiceInstance = LyricService(neteaseApi, MusicDatabase.database);
}
