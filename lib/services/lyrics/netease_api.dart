import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:motto_music/models/lyrics/netease_models.dart';
import 'package:motto_music/models/lyrics/lyric_models.dart';
import 'package:motto_music/utils/lyric_parser.dart';
import 'dart:math' show exp;

class NeteaseApiException implements Exception {
  final String message;
  final int? code;

  NeteaseApiException(this.message, {this.code});

  @override
  String toString() => 'NeteaseApiException: $message (code: $code)';
}

class NeteaseApi {
  static const String _baseUrl = 'https://music.163.com';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// 搜索歌曲
  Future<List<LyricSearchResult>> search({
    required String keywords,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      // 使用网易云的公开搜索接口
      final url = Uri.parse('$_baseUrl/api/cloudsearch/pc');
      
      final response = await http.post(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': _baseUrl,
        },
        body: {
          's': keywords,
          'type': '1', // 1 = 单曲
          'limit': limit.toString(),
          'offset': offset.toString(),
        },
      );

      if (response.statusCode != 200) {
        throw NeteaseApiException(
          '搜索请求失败',
          code: response.statusCode,
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final searchResponse = NeteaseSearchResponse.fromJson(data);

      if (searchResponse.code != 200) {
        throw NeteaseApiException(
          '搜索失败',
          code: searchResponse.code,
        );
      }

      final songs = searchResponse.result?.songs ?? [];
      return songs
          .map((song) => LyricSearchResult(
                source: 'netease',
                duration: song.dt / 1000.0, // ms 转 s
                title: song.name,
                artist: song.ar.isNotEmpty ? song.ar[0].name : '未知艺术家',
                remoteId: song.id,
              ))
          .toList();
    } catch (e) {
      if (e is NeteaseApiException) rethrow;
      throw NeteaseApiException('搜索歌曲时发生错误: $e');
    }
  }

  /// 获取歌词
  Future<NeteaseLyricResponse> getLyrics(int id) async {
    try {
      final url = Uri.parse('$_baseUrl/api/song/lyric');
      
      final response = await http.post(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': _baseUrl,
        },
        body: {
          'id': id.toString(),
          'lv': '-1',
          'tv': '-1',
        },
      );

      if (response.statusCode != 200) {
        throw NeteaseApiException(
          '获取歌词请求失败',
          code: response.statusCode,
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return NeteaseLyricResponse.fromJson(data);
    } catch (e) {
      if (e is NeteaseApiException) rethrow;
      throw NeteaseApiException('获取歌词时发生错误: $e');
    }
  }

  /// 解析歌词
  ParsedLrc parseLyrics(NeteaseLyricResponse lyricsResponse) {
    final parsedRawLyrics = LyricParser.parseLrc(lyricsResponse.lrc.lyric);

    // 如果没有翻译歌词，直接返回原始歌词
    if (lyricsResponse.tlyric == null ||
        lyricsResponse.tlyric!.lyric.trim().isEmpty) {
      return parsedRawLyrics;
    }

    // 解析翻译歌词
    final parsedTranslatedLyrics =
        LyricParser.parseLrc(lyricsResponse.tlyric!.lyric);

    if (parsedTranslatedLyrics.lyrics == null) {
      return parsedRawLyrics;
    }

    // 合并原始歌词和翻译
    return LyricParser.mergeLrc(parsedRawLyrics, parsedTranslatedLyrics);
  }

  /// 搜索并返回最佳匹配的歌词
  Future<ParsedLrc> searchBestMatchedLyrics({
    required String keyword,
    required int targetDurationMs,
  }) async {
    final searchResults = await search(keywords: keyword, limit: 10);

    if (searchResults.isEmpty) {
      throw NeteaseApiException('未搜索到相关歌曲\n\n搜索关键词：$keyword');
    }

    // 使用第一个搜索结果（网易云的搜索已经按相关度排序）
    final bestMatch = searchResults.first;

    // 获取歌词
    final lyricsResponse = await getLyrics(bestMatch.remoteId);

    // 解析歌词
    return parseLyrics(lyricsResponse);
  }

  /// 计算最佳匹配（备用方法，当需要更精确匹配时使用）
  NeteaseSong _findBestMatch(
    List<NeteaseSong> songs,
    String keyword,
    int targetDurationMs,
  ) {
    const durationWeight = 10.0;
    const sigmaMs = 1500.0;

    final scoredSongs = songs.map((song) {
      double score = 0;

      // 名称匹配
      if (song.name == keyword) {
        score += 10;
      }
      if (keyword.contains(song.name)) {
        score += 5;
      }

      // 别名匹配
      for (final alias in song.alia) {
        if (keyword.contains(alias)) {
          score += 2;
        }
      }

      // 艺术家匹配
      for (final artist in song.ar) {
        if (keyword.contains(artist.name)) {
          score += 1;
        }
      }

      // 时长匹配（使用高斯分布）
      final durationDiff = song.dt - targetDurationMs;
      final durationScore = durationWeight *
          exp(-(durationDiff * durationDiff) / (2 * sigmaMs * sigmaMs));

      score += durationScore;

      return (song: song, score: score);
    }).toList();

    final bestMatch = scoredSongs.reduce((best, current) {
      return current.score > best.score ? current : best;
    });

    return bestMatch.score > 0 ? bestMatch.song : songs.first;
  }
}

// 全局单例
final neteaseApi = NeteaseApi();
