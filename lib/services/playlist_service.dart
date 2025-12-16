import '../database/database.dart';
import 'package:drift/drift.dart';

class PlaylistService {
  final MusicDatabase _db;

  PlaylistService(this._db);

  Future<Playlist> createPlaylist({
    required String name,
    String? description,
    String? coverUrl,
    bool isSystem = false,
    String type = 'custom',
  }) async {
    final id = await _db.into(_db.playlists).insert(
      PlaylistsCompanion.insert(
        name: name,
        description: Value(description),
        coverUrl: Value(coverUrl),
        isSystem: Value(isSystem),
        type: Value(type),
      ),
    );
    return await getPlaylist(id);
  }

  Future<Playlist> getPlaylist(int id) async {
    return await (_db.select(_db.playlists)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<List<Playlist>> getAllPlaylists({bool includeSystem = true}) async {
    final query = _db.select(_db.playlists);
    if (!includeSystem) {
      query.where((t) => t.isSystem.equals(false));
    }
    return await query.get();
  }

  Future<Playlist?> getSystemPlaylist(String name) async {
    return await (_db.select(_db.playlists)
          ..where((t) => t.name.equals(name) & t.isSystem.equals(true)))
        .getSingleOrNull();
  }

  Future<void> updatePlaylist(Playlist playlist) async {
    await (_db.update(_db.playlists)..where((t) => t.id.equals(playlist.id)))
        .write(playlist.toCompanion(false));
  }

  Future<void> deletePlaylist(int id) async {
    await (_db.delete(_db.playlists)..where((t) => t.id.equals(id))).go();
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    final maxPosition = await (_db.selectOnly(_db.playlistSongs)
          ..addColumns([_db.playlistSongs.position.max()])
          ..where(_db.playlistSongs.playlistId.equals(playlistId)))
        .getSingleOrNull();
    
    final position = (maxPosition?.read(_db.playlistSongs.position.max()) ?? -1) + 1;

    await _db.into(_db.playlistSongs).insert(
      PlaylistSongsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
        position: position,
      ),
    );

    await _updateSongCount(playlistId);
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    await (_db.delete(_db.playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId)))
        .go();
    await _updateSongCount(playlistId);
  }

  Future<List<Song>> getPlaylistSongs(int playlistId) async {
    final query = _db.select(_db.playlistSongs).join([
      innerJoin(_db.songs, _db.songs.id.equalsExp(_db.playlistSongs.songId)),
    ])
      ..where(_db.playlistSongs.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(_db.playlistSongs.position)]);

    final results = await query.get();
    return results.map((row) => row.readTable(_db.songs)).toList();
  }

  Future<void> _updateSongCount(int playlistId) async {
    final count = await (_db.selectOnly(_db.playlistSongs)
          ..addColumns([_db.playlistSongs.id.count()])
          ..where(_db.playlistSongs.playlistId.equals(playlistId)))
        .getSingle()
        .then((row) => row.read(_db.playlistSongs.id.count()) ?? 0);

    await (_db.update(_db.playlists)..where((t) => t.id.equals(playlistId)))
        .write(PlaylistsCompanion(songCount: Value(count)));
  }

  Future<void> initSystemPlaylists() async {
    final favorites = await getSystemPlaylist('我喜欢的音乐');
    if (favorites == null) {
      await createPlaylist(
        name: '我喜欢的音乐',
        description: '收藏的歌曲',
        isSystem: true,
        type: 'system',
      );
    }

    final recent = await getSystemPlaylist('最近播放');
    if (recent == null) {
      await createPlaylist(
        name: '最近播放',
        description: '最近播放的歌曲',
        isSystem: true,
        type: 'system',
      );
    }
  }
}
