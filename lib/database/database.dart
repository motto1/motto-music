import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:motto_music/utils/common_utils.dart';
import 'package:motto_music/utils/platform_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import '../services/cache/album_art_cache_service.dart';
part 'database.g.dart';

class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  TextColumn get filePath => text().unique()(); // ⭐ 唯一约束：防止重复导入同一文件
  TextColumn get lyrics => text().nullable()();
  IntColumn get bitrate => integer().nullable()();
  IntColumn get sampleRate => integer().nullable()();
  IntColumn get duration => integer().nullable()(); // Duration in seconds
  TextColumn get albumArtPath => text().nullable()();
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastPlayedTime =>
      dateTime().withDefault(currentDateAndTime)();
  IntColumn get playedCount => integer().withDefault(const Constant(0))();
  
  // Bilibili 相关字段
  TextColumn get source => text().withDefault(const Constant('local'))(); // 'local' | 'bilibili'
  TextColumn get bvid => text().nullable()(); // Bilibili 视频 BV 号
  IntColumn get cid => integer().nullable()(); // Bilibili 分P的 CID
  IntColumn get pageNumber => integer().nullable()(); // 分P序号
  IntColumn get bilibiliVideoId => integer().nullable()
      .references(BilibiliVideos, #id, onDelete: KeyAction.setNull)(); // 外键
  IntColumn get bilibiliFavoriteId => integer().nullable()
      .references(BilibiliFavorites, #id, onDelete: KeyAction.setNull)(); // 所属收藏夹

  // 音质管理字段
  TextColumn get downloadedQualities => text().nullable()(); // 已下载的音质列表（如 "30280,30232"）
  IntColumn get currentQuality => integer().nullable()(); // 当前播放的音质 ID

  // 响度均衡字段
  RealColumn get loudnessMeasuredI => real().nullable()(); // 实际响度 (LUFS)
  RealColumn get loudnessTargetI => real().nullable()(); // 目标响度 (LUFS)
  RealColumn get loudnessMeasuredTp => real().nullable()(); // 真峰值 (dBTP)
  TextColumn get loudnessData => text().nullable()(); // 完整响度 JSON（包含 multi_scene_args）
}

/// Bilibili 视频表
class BilibiliVideos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bvid => text().unique()(); // BV 号（唯一）
  IntColumn get aid => integer()(); // AV 号
  IntColumn get cid => integer()(); // 默认分P的 CID
  TextColumn get title => text()(); // 视频标题
  TextColumn get coverUrl => text().nullable()(); // 封面图
  IntColumn get duration => integer()(); // 时长（秒）
  TextColumn get author => text()(); // UP主昵称
  IntColumn get authorMid => integer()(); // UP主 UID
  DateTimeColumn get publishDate => dateTime()(); // 发布时间
  TextColumn get description => text().nullable()(); // 简介
  BoolColumn get isMultiPage => boolean().withDefault(const Constant(false))(); // 是否多P
  IntColumn get pageCount => integer().withDefault(const Constant(1))(); // 分P数量
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Bilibili 收藏夹表
class BilibiliFavorites extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get remoteId => integer().unique()(); // Bilibili 收藏夹 ID（唯一）
  TextColumn get title => text()(); // 收藏夹标题
  TextColumn get description => text().nullable()(); // 简介
  TextColumn get coverUrl => text().nullable()(); // 封面
  IntColumn get mediaCount => integer().withDefault(const Constant(0))(); // 媒体数量
  DateTimeColumn get syncedAt => dateTime()(); // 最后同步时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isAddedToLibrary => boolean().withDefault(const Constant(false))(); // 是否已添加到音乐库
  BoolColumn get isLocal => boolean().withDefault(const Constant(false))(); // 是否为本地收藏夹
}

/// Bilibili 本地音频缓存表
/// 
/// 存储下载到本地的音频文件信息
class BilibiliAudioCache extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bvid => text()(); // BV 号
  IntColumn get cid => integer()(); // CID
  IntColumn get quality => integer()(); // 音质 ID
  TextColumn get localFilePath => text()(); // 本地文件路径
  IntColumn get fileSize => integer()(); // 文件大小（字节）
  DateTimeColumn get lastAccessTime => dateTime()(); // 最后访问时间（用于 LRU）
  DateTimeColumn get downloadedAt => dateTime().withDefault(currentDateAndTime)(); // 下载时间
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {bvid, cid, quality}, // 联合唯一索引
  ];
}

/// Bilibili 下载任务表
///
/// 管理用户主动下载的音频文件，支持队列、暂停、重试等功能
class DownloadTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bvid => text()(); // BV 号
  IntColumn get cid => integer()(); // CID
  IntColumn get quality => integer()(); // 音质 ID (30280=FLAC, 30232=High, 30216=Standard)
  TextColumn get title => text()(); // 歌曲标题
  TextColumn get artist => text().nullable()(); // 艺术家
  TextColumn get coverUrl => text().nullable()(); // 封面URL
  IntColumn get duration => integer().nullable()(); // 时长（秒）

  // 下载状态字段
  TextColumn get status => text()(); // pending | downloading | paused | completed | failed
  IntColumn get progress => integer().withDefault(const Constant(0))(); // 进度 0-100
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))(); // 已下载字节数
  IntColumn get totalBytes => integer().nullable()(); // 总字节数
  TextColumn get localPath => text().nullable()(); // 本地存储路径
  TextColumn get errorMessage => text().nullable()(); // 错误信息

  // 时间戳
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)(); // 创建时间
  DateTimeColumn get completedAt => dateTime().nullable()(); // 完成时间
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)(); // 更新时间

  @override
  List<Set<Column>> get uniqueKeys => [
    {bvid, cid, quality}, // 防止重复下载相同音质的歌曲
  ];
}

/// 用户设置表
///
/// 存储用户的音质偏好、下载设置等全局配置
class UserSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  // 音质设置
  IntColumn get defaultPlayQuality => integer().withDefault(const Constant(30251))(); // 默认播放音质（Hi-Res）
  IntColumn get defaultDownloadQuality => integer().withDefault(const Constant(30251))(); // 默认下载音质（Hi-Res）
  BoolColumn get autoSelectQuality => boolean().withDefault(const Constant(false))(); // 是否根据网络自动选择音质

  // 下载设置
  BoolColumn get wifiOnlyDownload => boolean().withDefault(const Constant(true))(); // 仅WiFi下载
  IntColumn get maxConcurrentDownloads => integer().withDefault(const Constant(3))(); // 最大并发下载数（1-5）
  BoolColumn get autoRetryFailed => boolean().withDefault(const Constant(true))(); // 自动重试失败的下载
  IntColumn get autoCacheSizeGB => integer().withDefault(const Constant(5))(); // 自动缓存空间限制（GB）
  TextColumn get downloadDirectory => text().nullable()(); // 自定义下载目录

  // 时间戳
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [
  Songs,
  BilibiliVideos,
  BilibiliFavorites,
  BilibiliAudioCache,
  DownloadTasks,
  UserSettings,
])
class MusicDatabase extends _$MusicDatabase {
  static late MusicDatabase _database;
  static MusicDatabase get database => _database;
  
  MusicDatabase._() : super(_openConnection());
  
  /// 测试用构造函数 - 接受自定义 QueryExecutor
  @visibleForTesting
  MusicDatabase.forTesting(QueryExecutor e) : super(e);
  
  static MusicDatabase initialize() {
    _database = MusicDatabase._();
    return _database;
  }

  @override
  int get schemaVersion => 9; // ⭐ 升级版本：添加响度均衡字段

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Schema version 1 -> 2: 添加 Bilibili 相关表和字段
          
          // 为 Songs 表添加 Bilibili 字段
          await m.addColumn(songs, songs.source);
          await m.addColumn(songs, songs.bvid);
          await m.addColumn(songs, songs.cid);
          await m.addColumn(songs, songs.pageNumber);
          await m.addColumn(songs, songs.bilibiliVideoId);
          
          // 创建新的 Bilibili 表
          await m.createTable(bilibiliVideos);
          await m.createTable(bilibiliFavorites);
          await m.createTable(bilibiliAudioCache);
        }
        
        if (from == 2 && to >= 3) {
          // Schema version 2 -> 3: 重构缓存机制
          // 删除旧的 URL 缓存表，创建新的本地文件缓存表
          
          // 注意：由于表结构完全不同，需要删除旧表
          await customStatement('DROP TABLE IF EXISTS bilibili_stream_cache');
          await m.createTable(bilibiliAudioCache);
        }
        
        if (from < 4) {
          // Schema version 3 -> 4: 添加收藏夹手动管理字段
          await customStatement(
            'ALTER TABLE bilibili_favorites ADD COLUMN is_added_to_library INTEGER NOT NULL DEFAULT 0'
          );
        }
        
        if (from < 5) {
          // Schema version 4 -> 5: 添加本地收藏夹标识
          await customStatement(
            'ALTER TABLE bilibili_favorites ADD COLUMN is_local INTEGER NOT NULL DEFAULT 0'
          );
        }
        
        if (from < 6) {
          // Schema version 5 -> 6: 添加歌曲和收藏夹的关联
          await customStatement(
            'ALTER TABLE songs ADD COLUMN bilibili_favorite_id INTEGER REFERENCES bilibili_favorites(id) ON DELETE SET NULL'
          );
        }

        if (from < 7) {
          // Schema version 6 -> 7: 添加 filePath unique 约束，清理重复数据

          // 1. 查找所有重复的 filePath
          final duplicates = await customSelect(
            '''
            SELECT file_path, COUNT(*) as count
            FROM songs
            GROUP BY file_path
            HAVING count > 1
            ''',
            readsFrom: {songs},
          ).get();

          print('🔍 发现 ${duplicates.length} 个重复的 filePath');

          // 2. 对于每个重复的 filePath，只保留最新的一条记录
          for (final row in duplicates) {
            final filePath = row.read<String>('file_path');

            // 保留最新的记录（id 最大），删除其他
            await customStatement(
              '''
              DELETE FROM songs
              WHERE file_path = ?
              AND id NOT IN (
                SELECT id FROM songs
                WHERE file_path = ?
                ORDER BY id DESC
                LIMIT 1
              )
              ''',
              [filePath, filePath],
            );
          }

          // 3. 重建表以添加 unique 约束
          await customStatement('''
            CREATE TABLE songs_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              artist TEXT,
              album TEXT,
              file_path TEXT NOT NULL UNIQUE,
              lyrics TEXT,
              bitrate INTEGER,
              sample_rate INTEGER,
              duration INTEGER,
              album_art_path TEXT,
              date_added INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
              is_favorite INTEGER NOT NULL DEFAULT 0,
              last_played_time INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
              played_count INTEGER NOT NULL DEFAULT 0,
              source TEXT NOT NULL DEFAULT 'local',
              bvid TEXT,
              cid INTEGER,
              page_number INTEGER,
              bilibili_video_id INTEGER REFERENCES bilibili_videos(id) ON DELETE SET NULL,
              bilibili_favorite_id INTEGER REFERENCES bilibili_favorites(id) ON DELETE SET NULL
            )
          ''');

          await customStatement('''
            INSERT INTO songs_new
            SELECT * FROM songs
          ''');

          await customStatement('DROP TABLE songs');
          await customStatement('ALTER TABLE songs_new RENAME TO songs');

          print('✅ filePath unique 约束添加完成');
        }

        if (from < 8) {
          // Schema version 7 -> 8: 添加下载任务表、用户设置表，扩展 Songs 表音质管理字段

          // 1. 为 Songs 表添加音质管理字段
          await m.addColumn(songs, songs.downloadedQualities);
          await m.addColumn(songs, songs.currentQuality);

          // 2. 创建下载任务表
          await m.createTable(downloadTasks);

          // 3. 创建用户设置表
          await m.createTable(userSettings);

          // 4. 初始化默认用户设置
          await into(userSettings).insert(
            UserSettingsCompanion.insert(
              defaultPlayQuality: const Value(30251), // Hi-Res
              defaultDownloadQuality: const Value(30251), // Hi-Res
              autoSelectQuality: const Value(false),
              wifiOnlyDownload: const Value(true),
              maxConcurrentDownloads: const Value(3),
              autoRetryFailed: const Value(true),
              autoCacheSizeGB: const Value(5),
            ),
          );

          print('✅ 下载管理和音质设置已初始化');
        }

        if (from < 9) {
          // Schema version 8 -> 9: 添加响度均衡字段
          try {
            await m.addColumn(songs, songs.loudnessMeasuredI);
          } catch (e) {
            print('⚠️ loudnessMeasuredI 字段已存在，跳过');
          }

          try {
            await m.addColumn(songs, songs.loudnessTargetI);
          } catch (e) {
            print('⚠️ loudnessTargetI 字段已存在，跳过');
          }

          try {
            await m.addColumn(songs, songs.loudnessMeasuredTp);
          } catch (e) {
            print('⚠️ loudnessMeasuredTp 字段已存在，跳过');
          }

          try {
            await m.addColumn(songs, songs.loudnessData);
          } catch (e) {
            print('⚠️ loudnessData 字段已存在，跳过');
          }

          print('✅ 响度均衡字段检查完成');
        }
      },
    );
  }

  // 获取所有歌曲
  Future<List<Song>> getAllSongs() async {
    return await select(songs).get();
  }

  // 模糊查询 - 支持歌曲名称、艺术家、专辑
  Future<List<Song>> searchSongs(String keyword) async {
    if (keyword.trim().isEmpty) {
      return await getAllSongs();
    }

    final query = select(songs)
      ..where(
        (song) =>
            song.title.like('%$keyword%') |
            song.artist.like('%$keyword%') |
            song.album.like('%$keyword%'),
      )
      ..orderBy([
        // 优先显示标题匹配的结果
        (song) => OrderingTerm(
              expression: CaseWhenExpression(
                cases: [
                  CaseWhen(song.title.like('%$keyword%'),
                      then: const Constant(0)),
                  CaseWhen(song.artist.like('%$keyword%'),
                      then: const Constant(1)),
                  CaseWhen(song.album.like('%$keyword%'),
                      then: const Constant(2)),
                ],
                orElse: const Constant(3),
              ),
            ),
        // 然后按标题排序
        (song) => OrderingTerm.asc(song.title),
      ]);

    return await query.get();
  }

  // 更精确的模糊查询 - 分别指定搜索字段
  Future<List<Song>> searchSongsAdvanced({
    String? title,
    String? artist,
    String? album,
  }) async {
    final query = select(songs);

    Expression<bool>? whereExpression;

    if (title != null && title.isNotEmpty) {
      whereExpression = songs.title.like('%$title%');
    }

    if (artist != null && artist.isNotEmpty) {
      final artistCondition = songs.artist.like('%$artist%');
      whereExpression = whereExpression == null
          ? artistCondition
          : whereExpression & artistCondition;
    }

    if (album != null && album.isNotEmpty) {
      final albumCondition = songs.album.like('%$album%');
      whereExpression = whereExpression == null
          ? albumCondition
          : whereExpression & albumCondition;
    }

    if (whereExpression != null) {
      query.where((song) => whereExpression!);
    }

    query.orderBy([(song) => OrderingTerm.asc(song.title)]);

    return await query.get();
  }

  // 按艺术家搜索
  Future<List<Song>> searchByArtist(String artist) async {
    if (artist.trim().isEmpty) return [];

    return await (select(songs)
          ..where((song) => song.artist.like('%$artist%'))
          ..orderBy([
            (song) => OrderingTerm.asc(song.album),
            (song) => OrderingTerm.asc(song.title),
          ]))
        .get();
  }

  // 按专辑搜索
  Future<List<Song>> searchByAlbum(String album) async {
    if (album.trim().isEmpty) return [];

    return await (select(songs)
          ..where((song) => song.album.like('%$album%'))
          ..orderBy([(song) => OrderingTerm.asc(song.title)]))
        .get();
  }

  // 获取所有艺术家（用于搜索提示）
  Future<List<String>> getAllArtists() async {
    final query = selectOnly(songs)
      ..addColumns([songs.artist])
      ..where(songs.artist.isNotNull())
      ..groupBy([songs.artist])
      ..orderBy([OrderingTerm.asc(songs.artist)]);

    final result = await query.get();
    return result
        .map((row) => row.read(songs.artist))
        .where((artist) => artist != null)
        .cast<String>()
        .toList();
  }

  // 获取所有专辑（用于搜索提示）
  Future<List<String>> getAllAlbums() async {
    final query = selectOnly(songs)
      ..addColumns([songs.album])
      ..where(songs.album.isNotNull())
      ..groupBy([songs.album])
      ..orderBy([OrderingTerm.asc(songs.album)]);

    final result = await query.get();
    return result
        .map((row) => row.read(songs.album))
        .where((album) => album != null)
        .cast<String>()
        .toList();
  }

  // 组合搜索 - 支持多个关键词
  Future<List<Song>> searchSongsMultipleKeywords(List<String> keywords) async {
    if (keywords.isEmpty) {
      return await getAllSongs();
    }

    Expression<bool>? whereExpression;

    for (final keyword in keywords) {
      if (keyword.trim().isEmpty) continue;

      final keywordCondition = songs.title.like('%$keyword%') |
          songs.artist.like('%$keyword%') |
          songs.album.like('%$keyword%');

      whereExpression = whereExpression == null
          ? keywordCondition
          : whereExpression & keywordCondition;
    }

    final query = select(songs);
    if (whereExpression != null) {
      query.where((song) => whereExpression!);
    }

    query.orderBy([(song) => OrderingTerm.asc(song.title)]);
    return await query.get();
  }

  // 基本搜索（不使用 lower() 函数）
  Future<List<Song>> basicSearch(String keyword) async {
    if (keyword.trim().isEmpty) {
      return await getAllSongs();
    }

    // 转为小写进行搜索（在 Dart 层面处理）
    final lowerKeyword = keyword.toLowerCase();

    final query = select(songs)
      ..where(
        (song) =>
            song.title.like('%$lowerKeyword%') |
            song.artist.like('%$lowerKeyword%') |
            song.album.like('%$lowerKeyword%'),
      )
      ..orderBy([
        // 标题匹配优先
        (song) => OrderingTerm(
              expression: CaseWhenExpression(
                cases: [
                  CaseWhen(
                    song.title.like('%$lowerKeyword%'),
                    then: const Constant(0),
                  ),
                  CaseWhen(
                    song.artist.like('%$lowerKeyword%'),
                    then: const Constant(1),
                  ),
                  CaseWhen(
                    song.album.like('%$lowerKeyword%'),
                    then: const Constant(2),
                  ),
                ],
                orElse: const Constant(3),
              ),
            ),
        (song) => OrderingTerm.asc(song.title),
      ]);

    return await query.get();
  }

  // 不区分大小写的搜索（手动转换）
  Future<List<Song>> caseInsensitiveSearch(String keyword) async {
    if (keyword.trim().isEmpty) {
      return await getAllSongs();
    }

    // 获取所有歌曲，然后在内存中过滤
    final allSongs = await getAllSongs();
    final lowerKeyword = keyword.toLowerCase();

    final filteredSongs = allSongs.where((song) {
      final title = song.title.toLowerCase();
      final artist = (song.artist ?? '').toLowerCase();
      final album = (song.album ?? '').toLowerCase();

      return title.contains(lowerKeyword) ||
          artist.contains(lowerKeyword) ||
          album.contains(lowerKeyword);
    }).toList();

    // 排序：标题匹配优先
    filteredSongs.sort((a, b) {
      final aTitle = a.title.toLowerCase();
      final bTitle = b.title.toLowerCase();
      final aArtist = (a.artist ?? '').toLowerCase();
      final bArtist = (b.artist ?? '').toLowerCase();

      // 完全匹配优先
      if (aTitle == lowerKeyword) return -1;
      if (bTitle == lowerKeyword) return 1;
      if (aArtist == lowerKeyword) return -1;
      if (bArtist == lowerKeyword) return 1;

      // 开头匹配次优先
      if (aTitle.startsWith(lowerKeyword) && !bTitle.startsWith(lowerKeyword))
        return -1;
      if (bTitle.startsWith(lowerKeyword) && !aTitle.startsWith(lowerKeyword))
        return 1;
      if (aArtist.startsWith(lowerKeyword) && !bArtist.startsWith(lowerKeyword))
        return -1;
      if (bArtist.startsWith(lowerKeyword) && !aArtist.startsWith(lowerKeyword))
        return 1;

      // 其他情况按标题排序
      return aTitle.compareTo(bTitle);
    });

    return filteredSongs;
  }

  Future<List<Song>> smartSearch(
    String? keyword, {
    String? orderField,
    String? orderDirection,
    bool? isFavorite,
    bool? isLastPlayed,
  }) async {
    final query = select(songs);
    
    // 只查询本地歌曲（库视图专用）
    // 如果是查询最近播放(isLastPlayed)或者查询收藏(isFavorite)，则不限制来源
    if (isLastPlayed != true && isFavorite != true) {
      query.where((song) => song.source.equals('local'));
    }
    
    if (keyword != null && keyword.trim().isNotEmpty) {
      final lowerKeyword = keyword.toLowerCase();

      query.where(
        (song) =>
            song.title.lower().like('%$lowerKeyword%') |
            song.artist.lower().like('%$lowerKeyword%') |
            song.album.lower().like('%$lowerKeyword%'),
      );

      // 优先级排序的条件
      if (isLastPlayed == null) {
        query.orderBy([
          (song) => OrderingTerm(
                expression: CaseWhenExpression(
                  cases: [
                    CaseWhen(
                      song.title.lower().equals(lowerKeyword),
                      then: const Constant(0),
                    ),
                    CaseWhen(
                      song.artist.lower().equals(lowerKeyword),
                      then: const Constant(1),
                    ),
                    CaseWhen(
                      song.album.lower().equals(lowerKeyword),
                      then: const Constant(2),
                    ),
                    CaseWhen(
                      song.title.lower().like('$lowerKeyword%'),
                      then: const Constant(3),
                    ),
                    CaseWhen(
                      song.artist.lower().like('$lowerKeyword%'),
                      then: const Constant(4),
                    ),
                    CaseWhen(
                      song.album.lower().like('$lowerKeyword%'),
                      then: const Constant(5),
                    ),
                  ],
                  orElse: const Constant(6),
                ),
              ),
        ]);
      }
    }
    if (isFavorite != null) {
      query.where((song) => song.isFavorite.equals(isFavorite));
    }
    if (isLastPlayed == true) {
      query.where((song) => song.playedCount.isBiggerThanValue(0));
      query.orderBy([(song) => OrderingTerm.desc(song.lastPlayedTime)]);
      query.limit(100);
      return await query.get();
    }

    // 无论有没有关键字，都执行排序逻辑
    query.orderBy([
      (song) {
        if (orderField == null || orderDirection == null) {
          return OrderingTerm.desc(song.id);
        }
        final Expression orderExpr;
        switch (orderField) {
          case 'id':
            orderExpr = song.duration;
            break;
          case 'title':
            orderExpr = song.title;
            break;
          case 'artist':
            orderExpr = song.artist;
            break;
          case 'album':
            orderExpr = song.album;
            break;
          case 'duration':
            orderExpr = song.duration;
            break;
          default:
            orderExpr = song.id;
        }
        return orderDirection.toLowerCase() == 'desc'
            ? OrderingTerm.desc(orderExpr)
            : OrderingTerm.asc(orderExpr);
      },
    ]);

    return await query.get();
  }

  // 插入歌曲
  Future<int> insertSong(SongsCompanion song) async {
    final prepared = await _prepareAlbumArt(song);
    return await into(songs).insert(prepared);
  }

  // 批量插入歌曲
  Future<void> insertSongs(List<SongsCompanion> songsList) async {
    final prepared = await Future.wait(
      songsList.map(_prepareAlbumArt),
    );
    await batch((batch) {
      batch.insertAll(songs, prepared);
    });
  }

  // 更新歌曲
  Future<bool> updateSong(Song song) async {
    return await update(songs).replace(song);
  }

  // 删除歌曲
  Future<int> deleteSong(int id) async {
    return await (delete(songs)..where((song) => song.id.equals(id))).go();
  }

  Future<SongsCompanion> _prepareAlbumArt(SongsCompanion song) async {
    if (!song.source.present || song.source.value != 'bilibili') {
      return song;
    }
    if (!song.albumArtPath.present ||
        (song.albumArtPath.value?.isEmpty ?? true)) {
      return song;
    }
    final localPath = await AlbumArtCacheService.instance
        .ensureLocalPath(song.albumArtPath.value);
    if (localPath == null ||
        localPath.isEmpty ||
        localPath == song.albumArtPath.value) {
      return song;
    }
    return song.copyWith(albumArtPath: Value(localPath));
  }

  // 检查歌曲是否已存在
  Future<Song?> getSongByPath(String filePath) async {
    final query = select(songs)
      ..where((song) => song.filePath.equals(filePath));
    final result = await query.getSingleOrNull();
    return result;
  }

  // 根据 ID 获取歌曲
  Future<Song?> getSongById(int id) async {
    final query = select(songs)
      ..where((song) => song.id.equals(id));
    final result = await query.getSingleOrNull();
    return result;
  }

  // 获取歌曲总数
  Future<int> getSongsCount() async {
    final count = countAll();
    final query = selectOnly(songs)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  // 按日期获取最近添加的歌曲
  Future<List<Song>> getRecentSongs([int limit = 20]) async {
    return await (select(songs)
          ..orderBy([(song) => OrderingTerm.desc(song.dateAdded)])
          ..limit(limit))
        .get();
  }

  // ============ Bilibili Videos DAO ============

  /// 插入 Bilibili 视频
  Future<int> insertBilibiliVideo(BilibiliVideosCompanion video) async {
    return await into(bilibiliVideos).insert(
      video,
      mode: InsertMode.insertOrReplace,
    );
  }

  /// 批量插入 Bilibili 视频
  Future<void> insertBilibiliVideos(List<BilibiliVideosCompanion> videosList) async {
    await batch((batch) {
      batch.insertAll(
        bilibiliVideos,
        videosList,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  /// 根据 BVID 获取视频
  Future<BilibiliVideo?> getBilibiliVideoByBvid(String bvid) async {
    final query = select(bilibiliVideos)
      ..where((v) => v.bvid.equals(bvid));
    return await query.getSingleOrNull();
  }

  /// 根据 ID 获取视频
  Future<BilibiliVideo?> getBilibiliVideoById(int id) async {
    final query = select(bilibiliVideos)
      ..where((v) => v.id.equals(id));
    return await query.getSingleOrNull();
  }

  /// 获取所有 Bilibili 视频
  Future<List<BilibiliVideo>> getAllBilibiliVideos() async {
    return await (select(bilibiliVideos)
          ..orderBy([(v) => OrderingTerm.desc(v.createdAt)]))
        .get();
  }

  /// 搜索 Bilibili 视频
  Future<List<BilibiliVideo>> searchBilibiliVideos(String keyword) async {
    if (keyword.trim().isEmpty) {
      return await getAllBilibiliVideos();
    }

    final query = select(bilibiliVideos)
      ..where((v) =>
          v.title.like('%$keyword%') |
          v.author.like('%$keyword%') |
          v.description.like('%$keyword%'))
      ..orderBy([(v) => OrderingTerm.desc(v.createdAt)]);

    return await query.get();
  }

  /// 更新 Bilibili 视频
  Future<bool> updateBilibiliVideo(BilibiliVideo video) async {
    return await update(bilibiliVideos).replace(
      video.copyWith(updatedAt: DateTime.now()),
    );
  }

  /// 删除 Bilibili 视频
  Future<int> deleteBilibiliVideo(int id) async {
    return await (delete(bilibiliVideos)..where((v) => v.id.equals(id))).go();
  }

  /// 删除指定 BVID 的视频
  Future<int> deleteBilibiliVideoByBvid(String bvid) async {
    return await (delete(bilibiliVideos)..where((v) => v.bvid.equals(bvid))).go();
  }

  // ============ Bilibili Favorites DAO ============

  /// 插入 Bilibili 收藏夹
  Future<int> insertBilibiliFavorite(BilibiliFavoritesCompanion favorite) async {
    return await into(bilibiliFavorites).insert(
      favorite,
      mode: InsertMode.insertOrReplace,
    );
  }

  /// 批量插入 Bilibili 收藏夹
  Future<void> insertBilibiliFavorites(List<BilibiliFavoritesCompanion> favoritesList) async {
    await batch((batch) {
      batch.insertAll(
        bilibiliFavorites,
        favoritesList,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  /// 根据远程 ID 获取收藏夹
  Future<BilibiliFavorite?> getBilibiliFavoriteByRemoteId(int remoteId) async {
    final query = select(bilibiliFavorites)
      ..where((f) => f.remoteId.equals(remoteId));
    return await query.getSingleOrNull();
  }

  /// 根据本地 ID 获取收藏夹
  Future<BilibiliFavorite?> getBilibiliFavoriteById(int id) async {
    final query = select(bilibiliFavorites)
      ..where((f) => f.id.equals(id));
    return await query.getSingleOrNull();
  }

  /// 获取所有 Bilibili 收藏夹
  Future<List<BilibiliFavorite>> getAllBilibiliFavorites() async {
    return await (select(bilibiliFavorites)
          ..orderBy([(f) => OrderingTerm.desc(f.syncedAt)]))
        .get();
  }

  /// 更新 Bilibili 收藏夹
  Future<bool> updateBilibiliFavorite(BilibiliFavorite favorite) async {
    return await update(bilibiliFavorites).replace(favorite);
  }

  /// 删除 Bilibili 收藏夹
  Future<int> deleteBilibiliFavorite(int id) async {
    return await (delete(bilibiliFavorites)..where((f) => f.id.equals(id))).go();
  }

  /// 更新收藏夹同步时间
  Future<void> updateFavoriteSyncTime(int remoteId, DateTime syncedAt) async {
    final favorite = await getBilibiliFavoriteByRemoteId(remoteId);
    if (favorite != null) {
      await (update(bilibiliFavorites)..where((f) => f.remoteId.equals(remoteId)))
          .write(BilibiliFavoritesCompanion(syncedAt: Value(syncedAt)));
    }
  }

  // ============ Bilibili Songs 扩展方法 ============

  /// 根据 BVID 和 CID 获取歌曲
  Future<Song?> getSongByBvidAndCid(String bvid, int cid) async {
    final query = select(songs)
      ..where((s) => s.bvid.equals(bvid) & s.cid.equals(cid));
    return await query.getSingleOrNull();
  }

  /// 获取指定 BVID 的所有歌曲(多P视频的所有分P)
  Future<List<Song>> getSongsByBvid(String bvid) async {
    return await (select(songs)
          ..where((s) => s.bvid.equals(bvid))
          ..orderBy([(s) => OrderingTerm.asc(s.pageNumber)]))
        .get();
  }

  /// 获取所有 Bilibili 来源的歌曲
  Future<List<Song>> getAllBilibiliSongs() async {
    return await (select(songs)
          ..where((s) => s.source.equals('bilibili'))
          ..orderBy([(s) => OrderingTerm.desc(s.dateAdded)]))
        .get();
  }

  /// 搜索 Bilibili 歌曲
  Future<List<Song>> searchBilibiliSongs(String keyword) async {
    if (keyword.trim().isEmpty) {
      return await getAllBilibiliSongs();
    }

    final query = select(songs)
      ..where((s) =>
          s.source.equals('bilibili') &
          (s.title.like('%$keyword%') |
              s.artist.like('%$keyword%') |
              s.album.like('%$keyword%')))
      ..orderBy([(s) => OrderingTerm.desc(s.dateAdded)]);

    return await query.get();
  }

  /// 删除指定 BVID 的所有歌曲
  Future<int> deleteSongsByBvid(String bvid) async {
    return await (delete(songs)..where((s) => s.bvid.equals(bvid))).go();
  }

  /// 获取本地歌曲数量
  Future<int> getLocalSongsCount() async {
    final count = countAll();
    final query = selectOnly(songs)
      ..addColumns([count])
      ..where(songs.source.equals('local'));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// 获取 Bilibili 歌曲数量
  Future<int> getBilibiliSongsCount() async {
    final count = countAll();
    final query = selectOnly(songs)
      ..addColumns([count])
      ..where(songs.source.equals('bilibili'));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  // ============ Bilibili Audio Cache DAO ============

  /// 获取本地缓存的音频文件
  Future<BilibiliAudioCacheData?> getCachedAudio({
    required String bvid,
    required int cid,
    required int quality,
  }) async {
    final query = select(bilibiliAudioCache)
      ..where((c) =>
          c.bvid.equals(bvid) &
          c.cid.equals(cid) &
          c.quality.equals(quality));

    final result = await query.getSingleOrNull();
    
    // 如果找到缓存，更新最后访问时间（LRU）
    if (result != null) {
      await updateCacheAccessTime(result.id);
    }
    
    return result;
  }

  /// 保存音频缓存记录
  Future<int> saveCachedAudio(BilibiliAudioCacheCompanion cache) async {
    return await into(bilibiliAudioCache).insert(
      cache,
      mode: InsertMode.insertOrReplace,
    );
  }

  /// 更新缓存访问时间（LRU）
  Future<void> updateCacheAccessTime(int cacheId) async {
    await (update(bilibiliAudioCache)..where((c) => c.id.equals(cacheId)))
        .write(BilibiliAudioCacheCompanion(
      lastAccessTime: Value(DateTime.now()),
    ));
  }

  /// 获取缓存总大小（字节）
  Future<int> getTotalCacheSize() async {
    final sumExp = bilibiliAudioCache.fileSize.sum();
    final query = selectOnly(bilibiliAudioCache)
      ..addColumns([sumExp]);
    
    final result = await query.getSingle();
    return result.read(sumExp)?.toInt() ?? 0;
  }

  /// 获取所有缓存文件，按最后访问时间排序（LRU）
  Future<List<BilibiliAudioCacheData>> getAllCaches({bool oldestFirst = true}) async {
    final query = select(bilibiliAudioCache);
    
    if (oldestFirst) {
      query.orderBy([(c) => OrderingTerm.asc(c.lastAccessTime)]);
    } else {
      query.orderBy([(c) => OrderingTerm.desc(c.lastAccessTime)]);
    }
    
    return await query.get();
  }

  /// 删除指定的缓存记录
  Future<int> deleteCachedAudio(int id) async {
    return await (delete(bilibiliAudioCache)..where((c) => c.id.equals(id))).go();
  }

  /// 删除指定歌曲的所有缓存
  Future<int> deleteCachedAudioByBvidCid({
    required String bvid,
    required int cid,
  }) async {
    return await (delete(bilibiliAudioCache)
          ..where((c) => c.bvid.equals(bvid) & c.cid.equals(cid)))
        .go();
  }

  // ========== 下载任务管理 ==========

  /// 获取指定的下载任务
  Future<DownloadTask?> getDownloadTask(String bvid, int cid, int quality) async {
    final query = select(downloadTasks)
      ..where((t) =>
          t.bvid.equals(bvid) & t.cid.equals(cid) & t.quality.equals(quality));
    return await query.getSingleOrNull();
  }

  /// 获取所有下载任务
  Future<List<DownloadTask>> getAllDownloadTasks() async {
    return await (select(downloadTasks)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 获取正在下载的任务
  Future<List<DownloadTask>> getDownloadingTasks() async {
    return await (select(downloadTasks)
          ..where((t) =>
              t.status.equals('downloading') | t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 获取已完成的任务
  Future<List<DownloadTask>> getCompletedDownloadTasks() async {
    return await (select(downloadTasks)
          ..where((t) => t.status.equals('completed'))
          ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
        .get();
  }

  /// 获取失败的任务
  Future<List<DownloadTask>> getFailedDownloadTasks() async {
    return await (select(downloadTasks)
          ..where((t) => t.status.equals('failed'))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// 获取下载统计信息
  Future<Map<String, int>> getDownloadStatistics() async {
    final all = await getAllDownloadTasks();
    return {
      'total': all.length,
      'downloading': all.where((t) => t.status == 'downloading' || t.status == 'pending').length,
      'completed': all.where((t) => t.status == 'completed').length,
      'failed': all.where((t) => t.status == 'failed').length,
    };
  }

  /// 删除下载任务
  Future<int> deleteDownloadTask(int id) async {
    return await (delete(downloadTasks)..where((t) => t.id.equals(id))).go();
  }

  // ========== 用户设置管理 ==========

  /// 获取用户设置（如果不存在则创建默认设置）
  Future<UserSetting> getUserSettings() async {
    final existing = await select(userSettings).getSingleOrNull();
    if (existing != null) {
      return existing;
    }

    // 创建默认设置
    final id = await into(userSettings).insert(
      UserSettingsCompanion.insert(
        defaultPlayQuality: const Value(30251), // Hi-Res
        defaultDownloadQuality: const Value(30251), // Hi-Res
        autoSelectQuality: const Value(false),
        wifiOnlyDownload: const Value(true),
        maxConcurrentDownloads: const Value(3),
        autoRetryFailed: const Value(true),
        autoCacheSizeGB: const Value(5),
      ),
    );

    return await (select(userSettings)..where((s) => s.id.equals(id)))
        .getSingle();
  }

  /// 更新用户设置
  Future<bool> updateUserSettings(UserSetting settings) async {
    return await update(userSettings).replace(
      settings.copyWith(updatedAt: DateTime.now()),
    );
  }

  /// 清空所有音频缓存
  Future<int> clearAllAudioCache() async {
    return await delete(bilibiliAudioCache).go();
  }

  /// 获取缓存文件数量
  Future<int> getCacheCount() async {
    final count = countAll();
    final query = selectOnly(bilibiliAudioCache)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}

Future<void> _deleteDirectoryContents(Directory directory) async {
  try {
    await for (var entity in directory.list(recursive: true)) {
      if (entity is File) {
        if (p.basename(entity.path) == 'libCachedImageData.db') {
          continue;
        }
        await entity.delete();
        debugPrint('已删除文件：${entity.path}');
      } else if (entity is Directory) {
        await _deleteDirectoryContents(entity);
        entity.deleteSync();
        debugPrint('已删除子目录：${entity.path}');
      }
    }
  } catch (e) {
    debugPrint('删除目录内容时出错: $e');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    if (PlatformUtils.isDesktop) {
      final oldDbFolder = await getApplicationSupportDirectory();
      if (await oldDbFolder.exists()) {
        await _deleteDirectoryContents(oldDbFolder);
        debugPrint('旧目录及其内容已删除：$oldDbFolder');
      } else {
        debugPrint('旧目录不存在：$oldDbFolder');
      }
    }
    final basePath = await CommonUtils.getAppBaseDirectory();
    debugPrint("APP根目录：${basePath}");
    final file = File(p.join(basePath, 'motto-music.db'));
    return NativeDatabase.createInBackground(file);
  });
}
