import 'package:flutter_test/flutter_test.dart';
import 'package:motto_music/database/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:matcher/matcher.dart' as matcher;
import 'package:motto_music/utils/bilibili_song_utils.dart';

void main() {
  late MusicDatabase db;

  setUp(() {
    db = MusicDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('歌曲来源判断测试', () {
    test('创建本地歌曲', () async {
      final songId = await db.insertSong(
        SongsCompanion.insert(
          title: '本地歌曲',
          filePath: '/path/to/local.mp3',
          source: const Value('local'),
        ),
      );

      final song = await db.select(db.songs)
          .getSingleOrNull();

      expect(song, matcher.isNotNull);
      expect(song!.source, equals('local'));
      expect(song.filePath, equals('/path/to/local.mp3'));
      expect(song.bvid, matcher.isNull);
      expect(song.cid, matcher.isNull);
    });

    test('创建 Bilibili 歌曲', () async {
      await db.insertSong(
        SongsCompanion.insert(
          title: 'Bilibili 歌曲',
          // 使用虚拟 filePath 满足唯一约束
          filePath: buildBilibiliFilePath(
            bvid: 'BV1xx411c7mD',
            cid: 123456,
            pageNumber: 1,
          ),
          source: const Value('bilibili'),
          bvid: const Value('BV1xx411c7mD'),
          cid: const Value(123456),
          pageNumber: const Value(1),
        ),
      );

      final song = await db.select(db.songs)
          .getSingleOrNull();

      expect(song, matcher.isNotNull);
      expect(song!.source, equals('bilibili'));
      expect(song.bvid, equals('BV1xx411c7mD'));
      expect(song.cid, equals(123456));
      expect(song.pageNumber, equals(1));
    });

    test('创建多P视频的歌曲', () async {
      // 插入视频元数据
      final videoId = await db.insertBilibiliVideo(
        BilibiliVideosCompanion.insert(
          bvid: 'BV_multi_page',
          aid: 999,
          cid: 111,
          title: '多P视频',
          duration: 600,
          author: 'UP主',
          authorMid: 123,
          publishDate: DateTime(2024, 1, 1),
          isMultiPage: const Value(true),
          pageCount: const Value(3),
        ),
      );

      // 插入3个分P
      await db.insertSongs([
        SongsCompanion.insert(
          title: '多P视频 - P1',
          filePath: buildBilibiliFilePath(
            bvid: 'BV_multi_page',
            cid: 111,
            pageNumber: 1,
          ),
          source: const Value('bilibili'),
          bvid: const Value('BV_multi_page'),
          cid: const Value(111),
          pageNumber: const Value(1),
          bilibiliVideoId: Value(videoId),
        ),
        SongsCompanion.insert(
          title: '多P视频 - P2',
          filePath: buildBilibiliFilePath(
            bvid: 'BV_multi_page',
            cid: 222,
            pageNumber: 2,
          ),
          source: const Value('bilibili'),
          bvid: const Value('BV_multi_page'),
          cid: const Value(222),
          pageNumber: const Value(2),
          bilibiliVideoId: Value(videoId),
        ),
        SongsCompanion.insert(
          title: '多P视频 - P3',
          filePath: buildBilibiliFilePath(
            bvid: 'BV_multi_page',
            cid: 333,
            pageNumber: 3,
          ),
          source: const Value('bilibili'),
          bvid: const Value('BV_multi_page'),
          cid: const Value(333),
          pageNumber: const Value(3),
          bilibiliVideoId: Value(videoId),
        ),
      ]);

      final songs = await db.getSongsByBvid('BV_multi_page');
      expect(songs.length, equals(3));
      
      // 验证分P顺序
      expect(songs[0].pageNumber, equals(1));
      expect(songs[1].pageNumber, equals(2));
      expect(songs[2].pageNumber, equals(3));
      
      // 验证 CID 不同
      expect(songs[0].cid, equals(111));
      expect(songs[1].cid, equals(222));
      expect(songs[2].cid, equals(333));
    });
  });

  group('歌曲统计测试', () {
    test('统计本地和 Bilibili 歌曲数量', () async {
      // 插入3首本地歌曲
      await db.insertSongs([
        SongsCompanion.insert(
          title: '本地歌曲1',
          filePath: '/path/1.mp3',
        ),
        SongsCompanion.insert(
          title: '本地歌曲2',
          filePath: '/path/2.mp3',
        ),
        SongsCompanion.insert(
          title: '本地歌曲3',
          filePath: '/path/3.mp3',
        ),
      ]);

      // 插入2首 Bilibili 歌曲
      await db.insertSongs([
        SongsCompanion.insert(
          title: 'Bilibili 歌曲1',
          filePath: buildBilibiliFilePath(
            bvid: 'BV1',
            cid: 1,
          ),
          source: const Value('bilibili'),
          bvid: const Value('BV1'),
          cid: const Value(1),
        ),
        SongsCompanion.insert(
          title: 'Bilibili 歌曲2',
          filePath: buildBilibiliFilePath(
            bvid: 'BV2',
            cid: 2,
          ),
          source: const Value('bilibili'),
          bvid: const Value('BV2'),
          cid: const Value(2),
        ),
      ]);

      final localCount = await db.getLocalSongsCount();
      final bilibiliCount = await db.getBilibiliSongsCount();
      final totalCount = await db.getSongsCount();

      expect(localCount, equals(3));
      expect(bilibiliCount, equals(2));
      expect(totalCount, equals(5));
    });
  });

  group('混合播放列表测试', () {
    test('查询所有歌曲（包含本地和Bilibili）', () async {
      // 插入混合歌曲
      await db.insertSongs([
        SongsCompanion.insert(
          title: '本地歌曲A',
          filePath: '/path/a.mp3',
        ),
        SongsCompanion.insert(
          title: 'Bilibili歌曲B',
          filePath: buildBilibiliFilePath(
            bvid: 'BV_B',
            cid: 100,
          ),
          source: const Value('bilibili'),
          bvid: const Value('BV_B'),
          cid: const Value(100),
        ),
        SongsCompanion.insert(
          title: '本地歌曲C',
          filePath: '/path/c.mp3',
        ),
        SongsCompanion.insert(
          title: 'Bilibili歌曲D',
          filePath: buildBilibiliFilePath(
            bvid: 'BV_D',
            cid: 200,
          ),
          source: const Value('bilibili'),
          bvid: const Value('BV_D'),
          cid: const Value(200),
        ),
      ]);

      final allSongs = await db.getAllSongs();
      expect(allSongs.length, equals(4));
      
      // 验证包含两种来源
      final localSongs = allSongs.where((s) => s.source == 'local').toList();
      final bilibiliSongs = allSongs.where((s) => s.source == 'bilibili').toList();
      
      expect(localSongs.length, equals(2));
      expect(bilibiliSongs.length, equals(2));
    });

    test('仅查询 Bilibili 歌曲', () async {
      await db.insertSongs([
        SongsCompanion.insert(
          title: '本地歌曲',
          filePath: '/path.mp3',
        ),
        SongsCompanion.insert(
          title: 'Bilibili歌曲1',
          filePath: buildBilibiliFilePath(
            bvid: 'BV1',
            cid: 1,
          ),
          source: const Value('bilibili'),
          bvid: const Value('BV1'),
          cid: const Value(1),
        ),
        SongsCompanion.insert(
          title: 'Bilibili歌曲2',
          filePath: buildBilibiliFilePath(
            bvid: 'BV2',
            cid: 2,
          ),
          source: const Value('bilibili'),
          bvid: const Value('BV2'),
          cid: const Value(2),
        ),
      ]);

      final bilibiliSongs = await db.getAllBilibiliSongs();
      expect(bilibiliSongs.length, equals(2));
      
      // 确保都是 Bilibili 来源
      for (final song in bilibiliSongs) {
        expect(song.source, equals('bilibili'));
        expect(song.bvid, matcher.isNotNull);
        expect(song.cid, matcher.isNotNull);
      }
    });
  });
}
