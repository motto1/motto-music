import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../config_module.dart';
import '../../database/database.dart';
import '../../services/bilibili/cookie_manager.dart';

class BilibiliLibraryModule extends ConfigModule {
  BilibiliLibraryModule(this._db);

  final MusicDatabase _db;

  @override
  String get id => 'bilibili_library_snapshot';

  @override
  String get name => 'Bilibili 音乐库快照';

  @override
  String get description => '收藏夹、本地库中的 B 站歌曲与喜欢标记';

  @override
  int get version => 1;

  @override
  Future<Map<String, dynamic>> exportData(
      {bool includeSensitive = false}) async {
    final favorites = await _db.select(_db.bilibiliFavorites).get();
    final videos = await _db.select(_db.bilibiliVideos).get();
    final songs = await (_db.select(_db.songs)
          ..where((t) => t.source.equals('bilibili')))
        .get();

    final remoteByLocalFavId = <int, int>{};
    for (final fav in favorites) {
      remoteByLocalFavId[fav.id] = fav.remoteId;
    }

    // localFavoriteId -> bvid（用于本地收藏夹没有远程封面时的降级：使用任意一首歌的封面）
    final localFavoriteIdToBvid = <int, String>{};

    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.bilibili.com',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 BiliApp/6.66.0',
          'Referer': 'https://www.bilibili.com',
          'Origin': 'https://www.bilibili.com',
        },
      ),
    );
    final cookie = await CookieManager().getCookieString();
    if (cookie.isNotEmpty) {
      dio.options.headers['Cookie'] = cookie;
    }

    String? normalizeRemoteUrl(String? url) {
      final value = url?.trim();
      if (value == null || value.isEmpty) return null;
      return value.startsWith('//') ? 'https:$value' : value;
    }

    // 构建 bvid -> coverUrl 映射，用于恢复本地路径对应的远程 URL。
    // 当本地库缺失视频表数据时，允许在备份导出阶段联网补全。
    final bvidToCoverUrl = <String, String?>{};
    for (final video in videos) {
      final coverUrl = normalizeRemoteUrl(video.coverUrl);
      if (coverUrl != null) {
        bvidToCoverUrl[video.bvid] = coverUrl;
      }
    }

    final favoriteRemoteIdToCoverUrl = <int, String?>{};
    Future<String?> resolveFavoriteCoverUrlByRemoteId(int remoteId) async {
      if (remoteId <= 0) return null;
      if (favoriteRemoteIdToCoverUrl.containsKey(remoteId)) {
        return favoriteRemoteIdToCoverUrl[remoteId];
      }

      try {
        final response = await dio.get<Map<String, dynamic>>(
          '/x/v3/fav/resource/list',
          queryParameters: {
            'media_id': remoteId.toString(),
            'pn': '1',
            'ps': '1',
          },
        );
        final body = response.data;
        final code = body?['code'] as int?;
        final data = body?['data'];
        final info = code == 0 && data is Map ? data['info'] : null;
        final cover =
            info is Map ? normalizeRemoteUrl(info['cover']?.toString()) : null;
        favoriteRemoteIdToCoverUrl[remoteId] = cover;
        return cover;
      } catch (_) {
        favoriteRemoteIdToCoverUrl[remoteId] = null;
        return null;
      }
    }

    Future<String?> resolveCoverUrlByBvid(String bvid) async {
      final normalized = bvid.trim();
      if (normalized.isEmpty) return null;

      if (bvidToCoverUrl.containsKey(normalized)) {
        return bvidToCoverUrl[normalized];
      }

      try {
        final response = await dio.get<Map<String, dynamic>>(
          '/x/web-interface/view',
          queryParameters: {'bvid': normalized},
        );
        final body = response.data;
        final code = body?['code'] as int?;
        final data = body?['data'];
        final cover = code == 0 && data is Map
            ? normalizeRemoteUrl(data['pic']?.toString())
            : null;
        bvidToCoverUrl[normalized] = cover;
        return cover;
      } catch (_) {
        bvidToCoverUrl[normalized] = null;
        return null;
      }
    }

    final songJson = <Map<String, dynamic>>[];
    for (final s in songs) {
      final json = s.toJson();
      final favLocalId = s.bilibiliFavoriteId;
      if (favLocalId != null && remoteByLocalFavId.containsKey(favLocalId)) {
        json['favoriteRemoteId'] = remoteByLocalFavId[favLocalId];
      }

      final bvid = s.bvid;
      if (favLocalId != null &&
          !localFavoriteIdToBvid.containsKey(favLocalId) &&
          bvid != null &&
          bvid.trim().isNotEmpty) {
        localFavoriteIdToBvid[favLocalId] = bvid;
      }

      // 处理封面路径：备份中优先写入远程 URL，确保跨设备可移植；
      // 本地路径仅作为备用保存在 _localAlbumArtPath。
      final albumArtPath = s.albumArtPath;
      final hasAlbumArt = albumArtPath != null && albumArtPath.isNotEmpty;
      final isRemoteAlbumArt = albumArtPath != null &&
          albumArtPath.isNotEmpty &&
          _isRemoteUrl(albumArtPath);
      final isLocalAlbumArt = hasAlbumArt && !isRemoteAlbumArt;

      if (isRemoteAlbumArt) {
        json['albumArtPath'] = normalizeRemoteUrl(albumArtPath) ?? albumArtPath;
      }

      if (isLocalAlbumArt) {
        json['_localAlbumArtPath'] = albumArtPath;
      }

      if (!isRemoteAlbumArt && bvid != null && bvid.trim().isNotEmpty) {
        final coverUrl = await resolveCoverUrlByBvid(bvid);
        if (coverUrl != null && coverUrl.isNotEmpty) {
          json['albumArtPath'] = coverUrl;
        } else if (isLocalAlbumArt) {
          // 无法解析远程 URL 时，避免把不可移植的本地路径写入备份字段。
          json['albumArtPath'] = null;
        }
      } else if (isLocalAlbumArt) {
        // 无 bvid 时无法补全远程 URL，避免写入本地路径。
        json['albumArtPath'] = null;
      }

      songJson.add(json);
    }

    final favoriteJson = <Map<String, dynamic>>[];
    for (final fav in favorites) {
      final json = fav.toJson();
      final coverUrl = fav.coverUrl;
      final normalizedCoverUrl = normalizeRemoteUrl(coverUrl);

      if (normalizedCoverUrl != null && _isRemoteUrl(normalizedCoverUrl)) {
        json['coverUrl'] = normalizedCoverUrl;
      } else {
        if (coverUrl != null && coverUrl.isNotEmpty) {
          json['_localCoverUrl'] = coverUrl;
        }
        if (fav.isLocal == true) {
          final bvid = localFavoriteIdToBvid[fav.id];
          json['coverUrl'] = bvid != null
              ? await resolveCoverUrlByBvid(bvid)
              : await resolveFavoriteCoverUrlByRemoteId(fav.remoteId);
        } else {
          json['coverUrl'] =
              await resolveFavoriteCoverUrlByRemoteId(fav.remoteId);
        }
      }

      favoriteJson.add(json);
    }

    return {
      'favorites': favoriteJson,
      'videos': videos.map((v) => v.toJson()).toList(),
      'songs': songJson,
    };
  }

  /// 判断路径是否为远程 URL
  bool _isRemoteUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  @override
  Future<void> importData(Map<String, dynamic> data,
      {required bool merge}) async {
    final favoritesList = data['favorites'];
    final videosList = data['videos'];
    final songsList = data['songs'];

    final remoteToLocalFavoriteId = <int, int>{};
    final bvidToLocalVideoId = <String, int>{};
    // bvid -> coverUrl 映射，用于导入时恢复歌曲封面
    final bvidToCoverUrl = <String, String>{};

    int? _readInt(dynamic raw) {
      if (raw == null) return null;
      return raw is int ? raw : int.tryParse(raw.toString());
    }

    bool? _readBool(dynamic raw) {
      if (raw == null) return null;
      if (raw is bool) return raw;
      final s = raw.toString().toLowerCase();
      return s == 'true' || s == '1';
    }

    String? _readString(dynamic raw) {
      if (raw == null) return null;
      return raw.toString();
    }

    DateTime? _readDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw);
      if (raw is int) {
        return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
      }
      return null;
    }

    if (favoritesList is List) {
      for (final item in favoritesList) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item as Map);

        final remoteId = _readInt(map['remoteId']);
        if (remoteId == null) continue;

        final existing = await (_db.select(_db.bilibiliFavorites)
              ..where((t) => t.remoteId.equals(remoteId)))
            .getSingleOrNull();

        final title = _readString(map['title']) ?? existing?.title ?? '';
        final description = map.containsKey('description')
            ? _readString(map['description'])
            : existing?.description;
        final coverUrl = map.containsKey('coverUrl')
            ? _readString(map['coverUrl'])
            : existing?.coverUrl;
        final mediaCount =
            _readInt(map['mediaCount']) ?? existing?.mediaCount ?? 0;
        final syncedAt =
            _readDate(map['syncedAt']) ?? existing?.syncedAt ?? DateTime.now();
        final createdAt =
            merge ? existing?.createdAt : _readDate(map['createdAt']);
        final isAddedToLibrary = _readBool(map['isAddedToLibrary']) ??
            existing?.isAddedToLibrary ??
            false;
        final isLocal = _readBool(map['isLocal']) ?? existing?.isLocal ?? false;

        if (existing != null) {
          await (_db.update(_db.bilibiliFavorites)
                ..where((t) => t.id.equals(existing.id)))
              .write(BilibiliFavoritesCompanion(
            remoteId: Value(remoteId),
            title: Value(title),
            description: Value(description),
            coverUrl: Value(coverUrl),
            mediaCount: Value(mediaCount),
            syncedAt: Value(syncedAt),
            createdAt: Value(createdAt ?? existing.createdAt),
            isAddedToLibrary: Value(isAddedToLibrary),
            isLocal: Value(isLocal),
          ));
          remoteToLocalFavoriteId[remoteId] = existing.id;
        } else {
          final insertedId = await _db.into(_db.bilibiliFavorites).insert(
                BilibiliFavoritesCompanion.insert(
                  remoteId: remoteId,
                  title: title,
                  description: Value(description),
                  coverUrl: Value(coverUrl),
                  mediaCount: Value(mediaCount),
                  syncedAt: syncedAt,
                  createdAt: Value(createdAt ?? DateTime.now()),
                  isAddedToLibrary: Value(isAddedToLibrary),
                  isLocal: Value(isLocal),
                ),
              );
          remoteToLocalFavoriteId[remoteId] = insertedId;
        }
      }
    }

    if (videosList is List) {
      for (final item in videosList) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item as Map);
        final bvid = _readString(map['bvid']);
        if (bvid == null || bvid.isEmpty) continue;

        final existing = await (_db.select(_db.bilibiliVideos)
              ..where((t) => t.bvid.equals(bvid)))
            .getSingleOrNull();

        int? reqInt(String key) => _readInt(map[key]);
        String? reqStr(String key) => _readString(map[key]);
        DateTime? reqDate(String key) => _readDate(map[key]);

        final aid = reqInt('aid') ?? existing?.aid;
        final cid = reqInt('cid') ?? existing?.cid;
        final title = reqStr('title') ?? existing?.title;
        final duration = reqInt('duration') ?? existing?.duration;
        final author = reqStr('author') ?? existing?.author;
        final authorMid = reqInt('authorMid') ?? existing?.authorMid;
        final publishDate = reqDate('publishDate') ?? existing?.publishDate;
        if (aid == null ||
            cid == null ||
            title == null ||
            duration == null ||
            author == null ||
            authorMid == null ||
            publishDate == null) {
          continue;
        }

        final coverUrl = map.containsKey('coverUrl')
            ? _readString(map['coverUrl'])
            : existing?.coverUrl;
        final description = map.containsKey('description')
            ? _readString(map['description'])
            : existing?.description;
        final isMultiPage =
            _readBool(map['isMultiPage']) ?? existing?.isMultiPage ?? false;
        final pageCount = reqInt('pageCount') ?? existing?.pageCount ?? 1;
        final createdAt =
            merge ? existing?.createdAt : _readDate(map['createdAt']);
        final updatedAt =
            merge ? existing?.updatedAt : _readDate(map['updatedAt']);

        if (existing != null) {
          await (_db.update(_db.bilibiliVideos)
                ..where((t) => t.id.equals(existing.id)))
              .write(BilibiliVideosCompanion(
            bvid: Value(bvid),
            aid: Value(aid),
            cid: Value(cid),
            title: Value(title),
            coverUrl: Value(coverUrl),
            duration: Value(duration),
            author: Value(author),
            authorMid: Value(authorMid),
            publishDate: Value(publishDate),
            description: Value(description),
            isMultiPage: Value(isMultiPage),
            pageCount: Value(pageCount),
            createdAt: Value(createdAt ?? existing.createdAt),
            updatedAt: Value(updatedAt ?? existing.updatedAt),
          ));
          bvidToLocalVideoId[bvid] = existing.id;
          // 记录 coverUrl 用于后续歌曲封面恢复
          if (coverUrl != null &&
              coverUrl.isNotEmpty &&
              _isRemoteUrl(coverUrl)) {
            bvidToCoverUrl[bvid] = coverUrl;
          }
        } else {
          final insertedId = await _db.into(_db.bilibiliVideos).insert(
                BilibiliVideosCompanion.insert(
                  bvid: bvid,
                  aid: aid,
                  cid: cid,
                  title: title,
                  coverUrl: Value(coverUrl),
                  duration: duration,
                  author: author,
                  authorMid: authorMid,
                  publishDate: publishDate,
                  description: Value(description),
                  isMultiPage: Value(isMultiPage),
                  pageCount: Value(pageCount),
                  createdAt: Value(createdAt ?? DateTime.now()),
                  updatedAt: Value(updatedAt ?? DateTime.now()),
                ),
              );
          bvidToLocalVideoId[bvid] = insertedId;
          // 记录 coverUrl 用于后续歌曲封面恢复
          if (coverUrl != null &&
              coverUrl.isNotEmpty &&
              _isRemoteUrl(coverUrl)) {
            bvidToCoverUrl[bvid] = coverUrl;
          }
        }
      }
    }

    if (songsList is List) {
      for (final item in songsList) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item as Map);

        final source = _readString(map['source']) ?? 'bilibili';
        if (source != 'bilibili') continue;

        final filePath = _readString(map['filePath']);
        final title = _readString(map['title']);
        if (filePath == null || filePath.isEmpty || title == null) {
          continue;
        }

        final existing = await (_db.select(_db.songs)
              ..where((t) => t.filePath.equals(filePath)))
            .getSingleOrNull();

        final favoriteRemoteId = _readInt(map['favoriteRemoteId']);
        final localFavId = favoriteRemoteId != null
            ? remoteToLocalFavoriteId[favoriteRemoteId]
            : null;

        final bvid = _readString(map['bvid']);
        final localVideoId = bvid != null ? bvidToLocalVideoId[bvid] : null;

        final isFavorite =
            _readBool(map['isFavorite']) ?? existing?.isFavorite ?? false;
        final artist = map.containsKey('artist')
            ? _readString(map['artist'])
            : existing?.artist;
        final album = map.containsKey('album')
            ? _readString(map['album'])
            : existing?.album;
        final lyrics = map.containsKey('lyrics')
            ? _readString(map['lyrics'])
            : existing?.lyrics;
        final bitrate = map.containsKey('bitrate')
            ? _readInt(map['bitrate'])
            : existing?.bitrate;
        final sampleRate = map.containsKey('sampleRate')
            ? _readInt(map['sampleRate'])
            : existing?.sampleRate;
        final duration = map.containsKey('duration')
            ? _readInt(map['duration'])
            : existing?.duration;

        // 处理封面路径：优先使用远程 URL，确保跨设备可用
        String? albumArtPath;
        if (map.containsKey('albumArtPath')) {
          final rawPath = _readString(map['albumArtPath']);
          if (rawPath != null && rawPath.isNotEmpty) {
            if (_isRemoteUrl(rawPath)) {
              // 远程 URL 直接使用
              albumArtPath = rawPath;
            } else {
              // 本地路径：尝试从关联视频获取 coverUrl 作为回退
              if (bvid != null && bvidToCoverUrl.containsKey(bvid)) {
                albumArtPath = bvidToCoverUrl[bvid];
              } else {
                // 无法获取远程 URL，置空让播放时重新获取
                albumArtPath = null;
              }
            }
          }
        } else {
          albumArtPath = existing?.albumArtPath;
        }

        final dateAdded = map.containsKey('dateAdded')
            ? _readDate(map['dateAdded'])
            : existing?.dateAdded;
        final lastPlayedTime = map.containsKey('lastPlayedTime')
            ? _readDate(map['lastPlayedTime'])
            : existing?.lastPlayedTime;
        final playedCount = map.containsKey('playedCount')
            ? _readInt(map['playedCount'])
            : existing?.playedCount;
        final cid =
            map.containsKey('cid') ? _readInt(map['cid']) : existing?.cid;
        final pageNumber = map.containsKey('pageNumber')
            ? _readInt(map['pageNumber'])
            : existing?.pageNumber;
        final downloadedQualities = map.containsKey('downloadedQualities')
            ? _readString(map['downloadedQualities'])
            : existing?.downloadedQualities;
        final currentQuality = map.containsKey('currentQuality')
            ? _readInt(map['currentQuality'])
            : existing?.currentQuality;
        final loudnessMeasuredI = map.containsKey('loudnessMeasuredI')
            ? (map['loudnessMeasuredI'] as num?)?.toDouble()
            : existing?.loudnessMeasuredI;
        final loudnessTargetI = map.containsKey('loudnessTargetI')
            ? (map['loudnessTargetI'] as num?)?.toDouble()
            : existing?.loudnessTargetI;
        final loudnessMeasuredTp = map.containsKey('loudnessMeasuredTp')
            ? (map['loudnessMeasuredTp'] as num?)?.toDouble()
            : existing?.loudnessMeasuredTp;
        final loudnessData = map.containsKey('loudnessData')
            ? _readString(map['loudnessData'])
            : existing?.loudnessData;

        if (existing != null) {
          await (_db.update(_db.songs)..where((t) => t.id.equals(existing.id)))
              .write(SongsCompanion(
            title: Value(title),
            artist: Value(artist),
            album: Value(album),
            lyrics: Value(lyrics),
            bitrate: Value(bitrate),
            sampleRate: Value(sampleRate),
            duration: Value(duration),
            albumArtPath: Value(albumArtPath),
            dateAdded: Value(dateAdded ?? existing.dateAdded),
            isFavorite: Value(isFavorite),
            lastPlayedTime: Value(lastPlayedTime ?? existing.lastPlayedTime),
            playedCount: Value(playedCount ?? existing.playedCount),
            source: Value(source),
            bvid: Value(bvid),
            cid: Value(cid),
            pageNumber: Value(pageNumber),
            bilibiliVideoId: Value(localVideoId),
            bilibiliFavoriteId: Value(localFavId),
            downloadedQualities: Value(downloadedQualities),
            currentQuality: Value(currentQuality),
            loudnessMeasuredI: Value(loudnessMeasuredI),
            loudnessTargetI: Value(loudnessTargetI),
            loudnessMeasuredTp: Value(loudnessMeasuredTp),
            loudnessData: Value(loudnessData),
          ));
        } else {
          await _db.into(_db.songs).insert(SongsCompanion.insert(
                title: title,
                filePath: filePath,
                artist: Value(artist),
                album: Value(album),
                lyrics: Value(lyrics),
                bitrate: Value(bitrate),
                sampleRate: Value(sampleRate),
                duration: Value(duration),
                albumArtPath: Value(albumArtPath),
                dateAdded: Value(dateAdded ?? DateTime.now()),
                isFavorite: Value(isFavorite),
                lastPlayedTime: Value(lastPlayedTime ?? DateTime.now()),
                playedCount: Value(playedCount ?? 0),
                source: Value(source),
                bvid: Value(bvid),
                cid: Value(cid),
                pageNumber: Value(pageNumber),
                bilibiliVideoId: Value(localVideoId),
                bilibiliFavoriteId: Value(localFavId),
                downloadedQualities: Value(downloadedQualities),
                currentQuality: Value(currentQuality),
                loudnessMeasuredI: Value(loudnessMeasuredI),
                loudnessTargetI: Value(loudnessTargetI),
                loudnessMeasuredTp: Value(loudnessMeasuredTp),
                loudnessData: Value(loudnessData),
              ));
        }
      }
    }
  }
}
