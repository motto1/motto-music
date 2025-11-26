import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:motto_music/models/lyrics/lyric_models.dart';
import 'package:motto_music/services/lyrics/netease_api.dart';
import 'package:motto_music/database/database.dart';

class LyricService {
  final NeteaseApi _neteaseApi;

  LyricService(this._neteaseApi);

  /// 生成歌曲的唯一标识（支持本地文件和 Bilibili 来源）
  ///
  /// ⭐ 公开方法，供外部调用以确保一致性
  String generateUniqueKey(Song track) {
    return _generateUniqueKey(track);
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

  /// 智能获取歌词（优先从缓存读取）
  Future<ParsedLrc> smartFetchLyrics(Song track) async {
    try {
      // ⭐ 使用智能唯一键生成（支持 Bilibili 和本地文件）
      final uniqueKey = _generateUniqueKey(track);
      final cacheFile = await _getLyricCacheFile(uniqueKey);

      // 调试日志：显示缓存键生成策略
      _logCacheKeyInfo(track, uniqueKey);

      // 尝试从缓存读取
      if (await cacheFile.exists()) {
        try {
          final content = await cacheFile.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final cachedLyrics = ParsedLrc.fromJson(json);

          print('✅ 从缓存加载歌词: ${track.title}');

          // 标记为缓存来源（如果原始来源不是local或manual）
          if (cachedLyrics.source != 'local' && cachedLyrics.source != 'manual') {
            return cachedLyrics.copyWith(source: 'cache');
          }
          return cachedLyrics;
        } catch (e) {
          print('⚠️ 读取歌词缓存失败: $e');
          // 缓存读取失败，继续获取新歌词
        }
      }

      print('🌐 从网络获取歌词: ${track.title}');

      // 从网络获取歌词
      final lyrics = await getBestMatchedLyrics(track: track);
      // 网络获取的歌词标记为 netease
      final neteaseeLyrics = lyrics.copyWith(source: 'netease');

      // 保存到缓存
      await _saveLyricsToCache(uniqueKey, neteaseeLyrics);

      return neteaseeLyrics;
    } catch (e) {
      throw Exception('智能获取歌词失败: $e');
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
}

// 全局单例
final lyricService = LyricService(neteaseApi);
