import 'package:motto_music/models/lyrics/lyric_models.dart';

/// 歌词解析工具类
class LyricParser {
  /// 解析 LRC 格式的歌词字符串
  static ParsedLrc parseLrc(String lrcString) {
    if (lrcString.trim().isEmpty) {
      return ParsedLrc(
        tags: const {},
        lyrics: null,
        rawOriginalLyrics: lrcString,
      );
    }

    try {
      final lines = lrcString.split('\n');
      final tags = <String, String>{};
      final lyrics = <LyricLine>[];

      final tagRegex = RegExp(r'^\[([a-zA-Z0-9]+):(.+)\]$');
      final timestampRegex = RegExp(r'\[(\d{2,}):(\d{2,})(?:[.:](\d{2,3}))?\]');

      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        // 检查是否为标签行
        final metadataMatch = tagRegex.firstMatch(trimmedLine);
        if (metadataMatch != null) {
          final key = metadataMatch.group(1)!;
          final value = metadataMatch.group(2)!.trim();
          tags[key] = value;
          continue;
        }

        // 解析时间戳
        final timestampMatches = timestampRegex.allMatches(trimmedLine).toList();
        if (timestampMatches.isNotEmpty) {
          final lastTimestamp = timestampMatches.last;
          final textContent = trimmedLine
              .substring(lastTimestamp.end)
              .trim();

          // 如果时间戳后面没有内容，跳过这一行
          if (textContent.isEmpty) continue;

          for (final match in timestampMatches) {
            final minutes = int.parse(match.group(1)!);
            final seconds = int.parse(match.group(2)!);
            final fractionalPart = match.group(3) ?? '0';
            final milliseconds = int.parse(fractionalPart.padRight(3, '0'));

            final timestamp = minutes * 60.0 + seconds + milliseconds / 1000.0;

            lyrics.add(LyricLine(
              timestamp: timestamp,
              text: textContent,
            ));
          }
        }
      }

      // 按时间戳排序
      lyrics.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return ParsedLrc(
        tags: tags,
        lyrics: lyrics.isEmpty ? null : lyrics,
        rawOriginalLyrics: lrcString,
      );
    } catch (e) {
      print('解析歌词失败: $e');
      return ParsedLrc(
        tags: const {},
        lyrics: null,
        rawOriginalLyrics: lrcString,
      );
    }
  }

  /// 将翻译歌词合并到原始歌词中
  /// 只有时间戳完全相同的行才会被合并
  static ParsedLrc mergeLrc(ParsedLrc originalLrc, ParsedLrc translatedLrc) {
    if (originalLrc.lyrics == null || translatedLrc.lyrics == null) {
      return originalLrc;
    }

    final translationMap = <double, String>{};
    for (final line in translatedLrc.lyrics!) {
      translationMap[line.timestamp] = line.text;
    }

    if (translationMap.isEmpty) {
      return originalLrc;
    }

    final mergedLyrics = originalLrc.lyrics!.map((line) {
      final translation = translationMap[line.timestamp];
      if (translation != null) {
        return line.copyWith(translation: translation);
      }
      return line;
    }).toList();

    final mergedTags = <String, String>{
      ...translatedLrc.tags,
      ...originalLrc.tags,
    };

    return ParsedLrc(
      tags: mergedTags,
      lyrics: mergedLyrics,
      rawOriginalLyrics: originalLrc.rawOriginalLyrics,
      rawTranslatedLyrics: translatedLrc.rawOriginalLyrics,
      offset: originalLrc.offset,
    );
  }

  /// 格式化时长为 HH:MM:SS 格式
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }
}
