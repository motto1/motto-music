import 'package:motto_music/models/lyrics/lyric_models.dart';

/// 歌词解析工具类
class LyricParser {
  /// 解析 LRC 格式的歌词字符串（支持字级时间戳）
  ///
  /// 支持格式：
  /// 1. 标准LRC: [00:10.50]歌词内容
  /// 2. 字级LRC: [00:10.50]<00:10.50>歌<00:10.80>词<00:11.10>内容
  /// 3. 无字级时间戳时，自动均分估算
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
      final charTimestampRegex = RegExp(r'<(\d{2,}):(\d{2,})(?:[.:](\d{2,3}))?>([^<]+)');

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

        // 解析行级时间戳
        final timestampMatches = timestampRegex.allMatches(trimmedLine).toList();
        if (timestampMatches.isNotEmpty) {
          final lastTimestamp = timestampMatches.last;
          final contentAfterTimestamp = trimmedLine.substring(lastTimestamp.end).trim();

          // 如果时间戳后面没有内容，跳过这一行
          if (contentAfterTimestamp.isEmpty) continue;

          // 解析字级时间戳
          final charMatches = charTimestampRegex.allMatches(contentAfterTimestamp).toList();
          List<CharTimestamp>? charTimestamps;
          String textContent = contentAfterTimestamp;

          if (charMatches.isNotEmpty) {
            // 有字级时间戳，解析
            charTimestamps = [];
            final textBuffer = StringBuffer();

            for (final charMatch in charMatches) {
              final minutes = int.parse(charMatch.group(1)!);
              final seconds = int.parse(charMatch.group(2)!);
              final fractionalPart = charMatch.group(3) ?? '0';
              final milliseconds = int.parse(fractionalPart.padRight(3, '0'));
              final charText = charMatch.group(4)!;

              final startMs = (minutes * 60 * 1000 + seconds * 1000 + milliseconds).toDouble();

              // 将字符串拆分为单个字符
              final chars = charText.runes.map((r) => String.fromCharCode(r)).toList();
              if (chars.length == 1) {
                // 单个字符，endMs与下一个字符的startMs相同（后续计算）
                charTimestamps.add(CharTimestamp(
                  char: chars[0],
                  startMs: startMs,
                  endMs: startMs + 200,  // 默认200ms，后续会修正
                ));
                textBuffer.write(chars[0]);
              } else {
                // 多个字符，均分时间
                final avgDuration = 200.0 / chars.length;
                for (int i = 0; i < chars.length; i++) {
                  charTimestamps.add(CharTimestamp(
                    char: chars[i],
                    startMs: startMs + i * avgDuration,
                    endMs: startMs + (i + 1) * avgDuration,
                  ));
                  textBuffer.write(chars[i]);
                }
              }
            }

            // 修正endMs：设置为下一个字符的startMs
            for (int i = 0; i < charTimestamps.length - 1; i++) {
              charTimestamps[i] = CharTimestamp(
                char: charTimestamps[i].char,
                startMs: charTimestamps[i].startMs,
                endMs: charTimestamps[i + 1].startMs,
              );
            }

            textContent = textBuffer.toString();
          } else {
            // 没有字级时间戳，使用均分算法估算
            textContent = contentAfterTimestamp;
            final nextLineIdx = lyrics.length;  // 下一行索引

            // 暂时先不生成，在后续处理（需要知道下一行时间）
            // Phase 3实现：这里留空，后续统一计算
            charTimestamps = null;
          }

          // 为每个行级时间戳创建LyricLine
          for (final match in timestampMatches) {
            final minutes = int.parse(match.group(1)!);
            final seconds = int.parse(match.group(2)!);
            final fractionalPart = match.group(3) ?? '0';
            final milliseconds = int.parse(fractionalPart.padRight(3, '0'));

            final timestamp = minutes * 60.0 + seconds + milliseconds / 1000.0;

            lyrics.add(LyricLine(
              timestamp: timestamp,
              text: textContent,
              charTimestamps: charTimestamps,
            ));
          }
        }
      }

      // 按时间戳排序
      lyrics.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // 为没有字级时间戳的行生成估算值
      for (int i = 0; i < lyrics.length; i++) {
        if (lyrics[i].charTimestamps == null && lyrics[i].text.isNotEmpty) {
          final currentLineStartMs = lyrics[i].timestamp * 1000;
          final nextLineStartMs = (i + 1 < lyrics.length)
              ? lyrics[i + 1].timestamp * 1000
              : currentLineStartMs + 3000;  // 默认3秒

          final durationMs = nextLineStartMs - currentLineStartMs;
          final chars = lyrics[i].text.runes.map((r) => String.fromCharCode(r)).toList();
          final avgDuration = durationMs / chars.length;

          final estimatedTimestamps = List.generate(chars.length, (j) {
            return CharTimestamp(
              char: chars[j],
              startMs: currentLineStartMs + j * avgDuration,
              endMs: currentLineStartMs + (j + 1) * avgDuration,
            );
          });

          lyrics[i] = lyrics[i].copyWith(charTimestamps: estimatedTimestamps);
        }
      }

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
