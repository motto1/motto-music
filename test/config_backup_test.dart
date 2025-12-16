import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motto_music/config/modules/bilibili_library_module.dart';
import 'package:motto_music/database/database.dart';
import 'package:motto_music/utils/bilibili_song_utils.dart';

void main() {
  test('BilibiliLibraryModule 导出/导入快照可还原收藏夹与喜欢', () async {
    final db1 = MusicDatabase.forTesting(NativeDatabase.memory());
    final db2 = MusicDatabase.forTesting(NativeDatabase.memory());

    try {
      final favId = await db1.insertBilibiliFavorite(
        BilibiliFavoritesCompanion.insert(
          remoteId: 100,
          title: '测试收藏夹',
          mediaCount: const Value(1),
          syncedAt: DateTime(2025, 1, 1),
          createdAt: Value(DateTime(2024, 1, 1)),
          isAddedToLibrary: const Value(true),
          isLocal: const Value(false),
        ),
      );

      final videoId = await db1.insertBilibiliVideo(
        BilibiliVideosCompanion.insert(
          bvid: 'BV_TEST',
          aid: 1,
          cid: 11,
          title: '测试视频',
          duration: 120,
          author: 'UP',
          authorMid: 123,
          publishDate: DateTime(2024, 1, 1),
          isMultiPage: const Value(false),
          pageCount: const Value(1),
        ),
      );

      final filePath = buildBilibiliFilePath(bvid: 'BV_TEST', cid: 11);

      await db1.insertSong(
        SongsCompanion.insert(
          title: '测试歌曲',
          filePath: filePath,
          source: const Value('bilibili'),
          bvid: const Value('BV_TEST'),
          cid: const Value(11),
          bilibiliVideoId: Value(videoId),
          bilibiliFavoriteId: Value(favId),
          isFavorite: const Value(true),
        ),
      );

      final module1 = BilibiliLibraryModule(db1);
      final exported = await module1.exportData();

      final module2 = BilibiliLibraryModule(db2);
      await module2.importData(exported, merge: true);

      final favs2 = await db2.select(db2.bilibiliFavorites).get();
      expect(favs2.length, 1);
      expect(favs2.single.remoteId, 100);
      expect(favs2.single.isAddedToLibrary, true);

      final songs2 = await (db2.select(db2.songs)
            ..where((t) => t.source.equals('bilibili')))
          .get();
      expect(songs2.length, 1);
      expect(songs2.single.filePath, filePath);
      expect(songs2.single.isFavorite, true);
      expect(songs2.single.bilibiliFavoriteId, isNotNull);
    } finally {
      await db1.close();
      await db2.close();
    }
  });
}
