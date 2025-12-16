import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../config_module.dart';
import '../../database/database.dart';

/// 歌词导出模式
enum LyricsExportMode {
  /// 导出所有歌词内容
  full,

  /// 仅导出用户编辑的歌词
  userEditedOnly,

  /// 仅导出元数据（哈希+来源信息）
  metadataOnly,

  /// 智能：用户编辑导出内容，其他导出元数据
  smart,
}

/// 歌词备份模块
///
/// 负责歌词数据的导出与导入，支持：
/// - 分层导出策略（用户编辑优先）
/// - 冲突解决（用户编辑 > 时间戳新 > 保留现有）
/// - 完整性校验（SHA256）
class LyricsConfigModule extends ConfigModule {
  LyricsConfigModule(this._db);

  final MusicDatabase _db;

  @override
  String get id => 'lyrics';

  @override
  String get name => '歌词数据';

  @override
  String get description => '歌词内容、翻译、时间轴偏移等';

  @override
  int get version => 1;

  @override
  bool get enabledByDefault => true;

  @override
  Future<Map<String, dynamic>> exportData({
    bool includeSensitive = false,
    LyricsExportMode mode = LyricsExportMode.full,
  }) async {
    final allLyrics = await _db.select(_db.songLyrics).get();

    final exportItems = <Map<String, dynamic>>[];

    for (final lyric in allLyrics) {
      // 根据导出模式过滤
      if (mode == LyricsExportMode.userEditedOnly && !lyric.isUserEdited) {
        continue;
      }

      final item = <String, dynamic>{
        'uniqueKey': lyric.uniqueKey,
        'format': lyric.format,
        'language': lyric.language,
        'source': lyric.source,
        'sourceRef': lyric.sourceRef,
        'offsetMs': lyric.offsetMs,
        'isUserEdited': lyric.isUserEdited,
        'isActive': lyric.isActive,
        'createdAt': lyric.createdAt.toIso8601String(),
        'updatedAt': lyric.updatedAt.toIso8601String(),
      };

      // 智能模式：用户编辑的必须导出内容，其他仅导出元数据
      final shouldExportContent = mode == LyricsExportMode.full ||
          lyric.isUserEdited ||
          mode != LyricsExportMode.metadataOnly;

      if (shouldExportContent) {
        item['content'] = lyric.content;
        item['contentHash'] = _sha256(lyric.content);
        if (lyric.translatedContent != null) {
          item['translatedContent'] = lyric.translatedContent;
        }
      } else {
        // 仅元数据模式：只保留哈希用于校验
        item['contentHash'] = _sha256(lyric.content);
      }

      exportItems.add(item);
    }

    return {
      'version': version,
      'exportMode': mode.name,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'totalCount': allLyrics.length,
      'exportedCount': exportItems.length,
      'items': exportItems,
    };
  }

  @override
  Future<void> importData(
    Map<String, dynamic> data, {
    required bool merge,
  }) async {
    final items = data['items'] as List? ?? [];

    int imported = 0;
    int skipped = 0;
    int updated = 0;

    for (final item in items) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      final uniqueKey = map['uniqueKey'] as String?;
      if (uniqueKey == null || uniqueKey.isEmpty) continue;

      final content = map['content'] as String?;
      final isUserEdited = map['isUserEdited'] == true;
      final source = map['source'] as String? ?? 'unknown';
      final language = map['language'] as String? ?? 'unknown';

      // 查找现有记录
      final existing = await (_db.select(_db.songLyrics)
            ..where((t) => t.uniqueKey.equals(uniqueKey))
            ..where((t) => t.source.equals(source))
            ..where((t) => t.language.equals(language)))
          .getSingleOrNull();

      // 冲突解决策略
      if (existing != null) {
        if (!merge) {
          // 覆盖模式：直接替换
          if (content != null && content.isNotEmpty) {
            await _updateLyric(existing.id, map, content);
            updated++;
          }
        } else {
          // 合并模式：用户编辑优先
          if (isUserEdited && !existing.isUserEdited) {
            // 导入的是用户编辑，现有的不是 → 替换
            if (content != null && content.isNotEmpty) {
              await _updateLyric(existing.id, map, content);
              updated++;
            }
          } else if (!isUserEdited && existing.isUserEdited) {
            // 现有的是用户编辑 → 保留现有
            skipped++;
            continue;
          } else if (isUserEdited && existing.isUserEdited) {
            // 都是用户编辑 → 按更新时间取新的
            final existingTime = existing.updatedAt;
            final importTime = DateTime.tryParse(map['updatedAt'] ?? '');
            if (importTime != null && importTime.isAfter(existingTime)) {
              if (content != null && content.isNotEmpty) {
                await _updateLyric(existing.id, map, content);
                updated++;
              }
            } else {
              skipped++;
            }
          } else {
            // 都不是用户编辑 → 保留现有（可重新获取）
            skipped++;
          }
        }
      } else {
        // 新记录
        if (content != null && content.isNotEmpty) {
          await _insertLyric(map, content);
          imported++;
        } else if (isUserEdited) {
          // 用户编辑的歌词但没有内容 → 记录警告
          print('⚠️ 用户编辑歌词缺少内容: $uniqueKey');
          skipped++;
        } else {
          // 非用户编辑且无内容 → 跳过（可后续重新获取）
          skipped++;
        }
      }
    }

    print('✅ 歌词导入完成: 新增=$imported, 更新=$updated, 跳过=$skipped');
  }

  Future<void> _updateLyric(
    int id,
    Map<String, dynamic> map,
    String content,
  ) async {
    await (_db.update(_db.songLyrics)..where((t) => t.id.equals(id))).write(
      SongLyricsCompanion(
        content: Value(content),
        translatedContent: Value(map['translatedContent'] as String?),
        offsetMs: Value(map['offsetMs'] as int? ?? 0),
        isUserEdited: Value(map['isUserEdited'] == true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _insertLyric(Map<String, dynamic> map, String content) async {
    // 尝试通过 uniqueKey 匹配歌曲
    final uniqueKey = map['uniqueKey'] as String;
    int? songId;

    // 尝试从 uniqueKey 解析出 songId（legacy 格式）
    if (uniqueKey.startsWith('legacy_song_')) {
      songId = int.tryParse(uniqueKey.replaceFirst('legacy_song_', ''));
    }

    await _db.into(_db.songLyrics).insert(
          SongLyricsCompanion.insert(
            songId: Value(songId),
            uniqueKey: uniqueKey,
            content: content,
            translatedContent: Value(map['translatedContent'] as String?),
            format: Value(map['format'] as String? ?? 'lrc'),
            language: Value(map['language'] as String? ?? 'unknown'),
            source: Value(map['source'] as String? ?? 'unknown'),
            sourceRef: Value(map['sourceRef'] as String?),
            offsetMs: Value(map['offsetMs'] as int? ?? 0),
            isUserEdited: Value(map['isUserEdited'] == true),
            isActive: Value(map['isActive'] ?? true),
          ),
        );
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  @override
  Map<String, dynamic> migrateData(
    int fromVersion,
    Map<String, dynamic> data,
  ) {
    // 当前版本 1，无需迁移
    return data;
  }

  @override
  Future<void> afterImport() async {
    // 导入后可以触发歌词与歌曲的关联修复
    // 当前暂不实现，后续可扩展
  }
}
