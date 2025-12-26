import 'package:flutter/foundation.dart';
import 'package:motto_music/models/bilibili/video.dart';
import 'package:motto_music/models/bilibili/favorite.dart';
import 'api_client.dart';
import 'wbi_signer.dart';

/// Bilibili API 服务
/// 
/// 封装所有 Bilibili API 调用逻辑
class BilibiliApiService {
  final BilibiliApiClient _client;
  final WbiSigner _wbiSigner;
  
  // WBI keys 缓存
  String? _imgKey;
  String? _subKey;
  DateTime? _keysLastUpdate;
  
  BilibiliApiService(this._client) : _wbiSigner = WbiSigner();
  
  /// 获取当前登录用户信息
  /// 
  /// 示例:
  /// ```dart
  /// final user = await apiService.getCurrentUserInfo();
  /// print('用户: ${user.name} (UID: ${user.mid})');
  /// ```
  Future<BilibiliUploader> getCurrentUserInfo() async {
    debugPrint('🔍 请求当前登录用户信息');
    
    final data = await _client.get<Map<String, dynamic>>('/x/web-interface/nav');
    
    debugPrint('✅ 当前用户信息获取成功: ${data['uname']}');
    
    return BilibiliUploader(
      mid: data['mid'] as int,
      name: data['uname'] as String,
      face: data['face'] as String?,
    );
  }
  
  /// 获取用户的收藏夹列表
  /// 
  /// [userMid] 用户 UID
  Future<List<BilibiliFavorite>> getFavoritePlaylists(int userMid) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/x/v3/fav/folder/created/list-all',
      params: {'up_mid': userMid.toString()},
    );
    
    print('🔍 收藏夹列表 API 响应:');
    print('  - 响应键: ${data.keys.toList()}');
    
    final list = data['list'] as List?;
    if (list == null || list.isEmpty) {
      print('⚠️ 收藏夹列表为空');
      return [];
    }
    
    print('  - 收藏夹数量: ${list.length}');
    if (list.isNotEmpty) {
      final firstItem = list.first as Map<String, dynamic>;
      print('  - 第一个收藏夹的键: ${firstItem.keys.toList()}');
      print('  - 第一个收藏夹数据: $firstItem');
    }
    
    return list
        .map((item) => BilibiliFavorite.fromJson(item as Map<String, dynamic>))
        .toList();
  }
  
  /// 获取视频详细信息
  /// 
  /// [bvid] 视频 BV 号
  Future<BilibiliVideo> getVideoDetails(String bvid) async {
    print('🔍 请求视频详情 API: bvid=$bvid');
    print('📡 API URL: /x/web-interface/view?bvid=$bvid');
    
    final data = await _client.get<Map<String, dynamic>>(
      '/x/web-interface/view',
      params: {'bvid': bvid},
    );
    
    print('✅ 视频详情 API 响应成功');
    print('  - 视频标题: ${data['title']}');
    print('  - 视频 aid: ${data['aid']}');

    // 详情接口通常把统计字段放在 stat 子对象里，这里做一次扁平化映射，
    // 以保持 BilibiliVideo 的 view/favorite/coin/like 等字段可用。
    final normalized = Map<String, dynamic>.from(data);
    final stat = data['stat'];
    if (stat is Map) {
      normalized['view'] ??= stat['view'];
      normalized['danmaku'] ??= stat['danmaku'];
      normalized['reply'] ??= stat['reply'];
      normalized['favorite'] ??= stat['favorite'];
      normalized['coin'] ??= stat['coin'];
      normalized['share'] ??= stat['share'];
      normalized['like'] ??= stat['like'];
    }

    return BilibiliVideo.fromJson(normalized);
  }
  
  /// 获取收藏夹内容（分页）- 返回完整信息包括封面
  /// 
  /// [favoriteId] 收藏夹 ID
  /// [page] 页码（从1开始）
  Future<BilibiliFavoriteContents> getFavoriteContentsWithInfo(
    int favoriteId,
    int page,
  ) async {
    print('🔍 请求收藏夹内容 API: favoriteId=$favoriteId, page=$page');
    final data = await _client.get<Map<String, dynamic>>(
      '/x/v3/fav/resource/list',
      params: {
        'media_id': favoriteId.toString(),
        'pn': page.toString(),
        'ps': '20', // 每页20个
      },
    );
    
    print('📦 收藏夹内容 API 响应:');
    print('  - 响应键: ${data.keys.toList()}');
    if (data.containsKey('info')) {
      final info = data['info'] as Map<String, dynamic>?;
      if (info != null) {
        print('  - info 键: ${info.keys.toList()}');
        print('  - info.id: ${info['id']}');
        print('  - info.title: ${info['title']}');
        print('  - info.cover: ${info['cover']}');
      }
    }
    
    final result = BilibiliFavoriteContents.fromJson(data);
    print('  - 解析后封面: ${result.info.cover}');
    return result;
  }
  
  /// 获取收藏夹内容（分页）- 仅返回视频列表（向后兼容）
  /// 
  /// [favoriteId] 收藏夹 ID
  /// [page] 页码（从1开始）
  Future<List<BilibiliFavoriteItem>> getFavoriteContents(
    int favoriteId,
    int page,
  ) async {
    final contents = await getFavoriteContentsWithInfo(favoriteId, page);
    return contents.medias ?? [];
  }
  
  /// 获取视频的分P列表
  /// 
  /// [bvid] 视频 BV 号
  Future<List<BilibiliVideoPage>> getVideoPages(String bvid) async {
    print('🔍 请求视频分P列表 API: bvid=$bvid');
    
    final data = await _client.get<List<dynamic>>(
      '/x/player/pagelist',
      params: {'bvid': bvid},
    );
    
    print('✅ 视频分P列表 API 响应成功: ${data.length} 个分P');
    
    return data
        .map((item) => BilibiliVideoPage.fromJson(item as Map<String, dynamic>))
        .toList();
  }
  
  /// 按类型搜索视频（bilibili-api: search_by_type）
  ///
  /// [keyword] 搜索关键词（必填）
  /// [searchType] 搜索类型，默认 video
  /// [orderType] 排序方式（例如 pubdate/click/scores）
  /// [timeRange] 时长范围（B站 duration 参数）
  /// [videoZoneType] 分区 ID（对应 search_by_type 的 video_zone_type）
  /// [page] 页码
  /// [pageSize] 每页数量
  Future<List<BilibiliVideo>> searchVideosByType({
    required String keyword,
    String searchType = 'video',
    String? orderType,
    int? timeRange,
    int? videoZoneType,
    int page = 1,
    int pageSize = 20,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) {
      debugPrint('⚠️ 搜索关键词为空');
      return [];
    }

    // 确保 WBI keys 有效
    await _ensureWbiKeys();

    final rawParams = <String, dynamic>{
      'keyword': trimmedKeyword,
      'search_type': searchType,
      'page': page,
      'page_size': pageSize.toString(),
    };
    if (orderType != null && orderType.isNotEmpty) {
      rawParams['order'] = orderType;
    }
    if (timeRange != null) {
      rawParams['duration'] = timeRange.toString();
    }
    if (videoZoneType != null) {
      rawParams['tids'] = videoZoneType.toString();
    }

    final params = _wbiSigner.encodeWbiToMap(
      rawParams,
      _imgKey!,
      _subKey!,
    );

    debugPrint('🔍 搜索视频: keyword=$trimmedKeyword, page=$page');

    final data = await _client.get<Map<String, dynamic>>(
      '/x/web-interface/wbi/search/type',
      params: params,
    );

    final result = data['result'] as List?;
    if (result == null || result.isEmpty) {
      debugPrint('⚠️ 搜索结果为空');
      return [];
    }

    debugPrint('✅ 搜索到 ${result.length} 个视频');

    // 注意: 搜索结果的字段可能与视频详情不同，需要适配
    final videos = <BilibiliVideo>[];
    for (var i = 0; i < result.length; i++) {
      try {
        final video = _parseSearchResult(result[i] as Map<String, dynamic>, i);
        videos.add(video);
      } catch (e) {
        debugPrint('❌ 解析第 $i 个搜索结果失败: $e');
        debugPrint('   原始数据: ${result[i]}');
      }
    }

    return videos;
  }

  /// 搜索视频（需要 WBI 签名）
  ///
  /// [keyword] 搜索关键词
  /// [page] 页码
  Future<List<BilibiliVideo>> searchVideos(String keyword, int page) async {
    return searchVideosByType(
      keyword: keyword,
      page: page,
    );
  }

  /// 解析搜索结果为 BilibiliVideo
  BilibiliVideo _parseSearchResult(Map<String, dynamic> json, int index) {
    debugPrint('📋 解析搜索结果 [$index]:');
    debugPrint('   - aid: ${json['aid']}');
    debugPrint('   - bvid: ${json['bvid']}');
    debugPrint('   - title: ${json['title']}');
    debugPrint('   - pic: ${json['pic']}');
    debugPrint('   - author: ${json['author']}');

    // 清理HTML标签（B站搜索会在关键词周围加<em class="keyword">标签）
    String cleanTitle = _removeHtmlTags(json['title'] as String? ?? '');
    String cleanAuthor = _removeHtmlTags(json['author'] as String? ?? '');

    // 验证必要字段
    final bvid = json['bvid'] as String? ?? '';
    if (bvid.isEmpty) {
      debugPrint('⚠️ 警告: bvid为空，使用aid生成');
    }

    // 处理封面URL（可能需要补全协议）
    final picUrl = _normalizePicUrl(json['pic'] as String? ?? '');

    debugPrint('   - 清理后title: $cleanTitle');
    debugPrint('   - 清理后author: $cleanAuthor');
    debugPrint('   - 处理后pic: $picUrl');

    return BilibiliVideo(
      aid: json['aid'] as int? ?? 0,
      bvid: bvid,
      title: cleanTitle,
      pic: picUrl,
      duration: _parseDuration(json['duration']), // 可能是字符串格式 "MM:SS"
      desc: _removeHtmlTags(json['description'] as String? ?? ''),
      owner: BilibiliUploader(
        mid: json['mid'] as int? ?? 0,
        name: cleanAuthor,
        face: _normalizePicUrl(
          (json['upic'] ?? json['up_face'] ?? json['face'])?.toString() ?? '',
        ),
      ),
      cid: 0, // 搜索结果不包含 cid
      pubdate: json['pubdate'] as int? ?? 0,
    );
  }

  /// 移除HTML标签
  String _removeHtmlTags(String text) {
    if (text.isEmpty) return text;

    // 移除所有HTML标签，包括<em class="keyword">这样的高亮标签
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')  // 移除所有HTML标签
        .replaceAll('&nbsp;', ' ')            // 替换HTML空格
        .replaceAll('&lt;', '<')              // 替换HTML转义
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .trim();
  }
  
  /// 解析时长字符串 "MM:SS" 或直接返回秒数
  int _parseDuration(dynamic duration) {
    if (duration is int) return duration;
    if (duration is String) {
      final parts = duration.split(':');
      if (parts.length == 2) {
        final minutes = int.tryParse(parts[0]) ?? 0;
        final seconds = int.tryParse(parts[1]) ?? 0;
        return minutes * 60 + seconds;
      }
    }
    return 0;
  }

  int _parseSafeInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _normalizePicUrl(String picUrl) {
    if (picUrl.isNotEmpty && picUrl.startsWith('//')) {
      return 'https:$picUrl';
    }
    return picUrl;
  }

  
  /// 确保 WBI keys 有效（如果过期则刷新）
  Future<void> _ensureWbiKeys() async {
    // 检查是否需要刷新（keys 为空或超过 24 小时）
    if (_imgKey == null ||
        _subKey == null ||
        _keysLastUpdate == null ||
        DateTime.now().difference(_keysLastUpdate!) > const Duration(hours: 24)) {
      await _refreshWbiKeys();
    }
  }
  
  /// 刷新 WBI keys
  Future<void> _refreshWbiKeys() async {
    final data = await _client.get<Map<String, dynamic>>('/x/web-interface/nav');
    
    final wbiImg = data['wbi_img'] as Map<String, dynamic>?;
    if (wbiImg == null) {
      throw Exception('未能获取 WBI keys');
    }
    
    // 从 URL 中提取 key
    // img_url 格式: https://i0.hdslb.com/bfs/wbi/xxx.png
    _imgKey = _extractWbiKey(wbiImg['img_url'] as String);
    _subKey = _extractWbiKey(wbiImg['sub_url'] as String);
    _keysLastUpdate = DateTime.now();
  }
  
  /// 从 URL 中提取 WBI key
  /// 
  /// 示例: https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png
  /// 返回: 7cd084941338484aae1ad9425b84077c
  String _extractWbiKey(String url) {
    final uri = Uri.parse(url);
    final filename = uri.pathSegments.last;
    return filename.substring(0, filename.lastIndexOf('.'));
  }

  /// 解析 b23.tv 短链，返回真实URL
  /// 
  /// [shortUrl] b23.tv 短链接，例如: https://b23.tv/xxxxx
  /// 
  /// 返回解析后的真实URL
  Future<String> resolveB23Url(String shortUrl) async {
    try {
      // b23.tv 短链会重定向到真实URL
      // 我们需要使用HTTP客户端跟踪重定向
      final response = await _client.getRedirectUrl(shortUrl);
      return response;
    } catch (e) {
      throw Exception('解析 b23.tv 短链失败: $e');
    }
  }

  /// 添加视频到收藏夹
  /// 
  /// [mediaId] 视频的 AV 号
  /// [favoriteId] 收藏夹 ID
  Future<void> addToFavorite({
    required int mediaId,
    required int favoriteId,
  }) async {
    await _client.postWithCsrf(
      '/x/v3/fav/resource/deal',
      data: {
        'rid': mediaId.toString(),
        'type': '2',
        'add_media_ids': favoriteId.toString(),
      },
    );
  }

  /// 从收藏夹移除视频
  ///
  /// [mediaId] 视频的 AV 号
  /// [favoriteId] 收藏夹 ID
  Future<void> removeFromFavorite({
    required int mediaId,
    required int favoriteId,
  }) async {
    await _client.postWithCsrf(
      '/x/v3/fav/resource/deal',
      data: {
        'rid': mediaId.toString(),
        'type': '2',
        'del_media_ids': favoriteId.toString(),
      },
    );
  }

  /// 创建新收藏夹
  /// 
  /// [title] 收藏夹标题
  /// [intro] 收藏夹简介（可选）
  /// [privacy] 是否私密（0=公开，1=私密）
  /// 
  /// 返回新创建的收藏夹ID
  Future<int> createFavorite({
    required String title,
    String? intro,
    int privacy = 0,
  }) async {
    final data = await _client.postWithCsrf<Map<String, dynamic>>(
      '/x/v3/fav/folder/add',
      data: {
        'title': title,
        'intro': intro ?? '',
        'privacy': privacy,
      },
    );
    return data['id'] as int;
  }

  /// 获取UP主的合集列表
  ///
  /// [mid] UP主ID
  Future<List<dynamic>> getUploaderSeasons(int mid) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/x/polymer/web-space/seasons_series_list',
      params: {
        'mid': mid.toString(),
        'page_num': '1',
        'page_size': '20',
      },
    );

    final itemsLists = data['items_lists'] ?? data['items_list'];

    List<dynamic> normalizeSeasons(dynamic direct) {
      if (direct is List) {
        final out = <dynamic>[];
        for (final item in direct) {
          if (item is Map<String, dynamic>) {
            final seasons = item['seasons'] ?? item['season_list'];
            if (seasons is List) {
              out.addAll(seasons);
              continue;
            }
          }
          out.add(item);
        }
        return out;
      }

      if (direct is Map<String, dynamic>) {
        final seasons = direct['seasons'] ?? direct['season_list'];
        if (seasons is List) return seasons;
        return [direct];
      }

      return const [];
    }

    List<dynamic> collectFromMap(Map<String, dynamic> map) {
      final direct = map['seasons_list'] ?? map['seasons'] ?? map['list'];
      return normalizeSeasons(direct);
    }

    final result = <dynamic>[];

    if (itemsLists is Map<String, dynamic>) {
      result.addAll(collectFromMap(itemsLists));
    } else if (itemsLists is List) {
      for (final entry in itemsLists) {
        if (entry is Map<String, dynamic>) {
          result.addAll(collectFromMap(entry));
        }
      }
    }

    // 兜底：部分返回可能直接挂在顶层字段。
    final topLevel = data['seasons_list'] ?? data['seasons'];
    if (result.isEmpty && topLevel is List) {
      result.addAll(topLevel);
    }

    if (result.isEmpty) {
      debugPrint(
        '[BilibiliApiService] getUploaderSeasons 空结果: mid=$mid, keys=${data.keys.toList()}',
      );
    }

    return result;
  }

  /// 获取合集内容（分页）
  /// 
  /// [seasonId] 合集ID
  /// [mid] UP主ID
  /// [page] 页码（从1开始）
  Future<Map<String, dynamic>> getCollectionContents({
    required int seasonId,
    required int mid,
    int page = 1,
  }) async {
    debugPrint('🔍 请求合集内容 API: seasonId=$seasonId, mid=$mid, page=$page');
    
    final data = await _client.get<Map<String, dynamic>>(
      '/x/polymer/web-space/seasons_archives_list',
      params: {
        'mid': mid.toString(),
        'season_id': seasonId.toString(),
        'sort_reverse': 'false',
        'page_num': page.toString(),
        'page_size': '20',
      },
    );
    
    debugPrint('✅ 合集内容 API 响应成功');
    return data;
  }

  /// 获取用户基本信息
  /// 
  /// [mid] 用户ID
  Future<BilibiliUploader> getUserInfo(int mid) async {
    debugPrint('🔍 请求用户信息: mid=$mid');
    
    // 确保 WBI keys 有效
    await _ensureWbiKeys();

    // 使用 WBI 签名
    final params = _wbiSigner.encodeWbiToMap(
      {'mid': mid.toString()},
      _imgKey!,
      _subKey!,
    );

    debugPrint('📡 WBI 签名后的参数: $params');
    
    final data = await _client.get<Map<String, dynamic>>(
      '/x/space/wbi/acc/info',
      params: params,
    );
    
    debugPrint('✅ 用户信息获取成功: ${data['name']}');
    
    return BilibiliUploader(
      mid: data['mid'] as int,
      name: data['name'] as String,
      face: data['face'] as String?,
    );
  }

  /// 获取UP主视频列表（分页）
  ///
  /// [mid] UP主ID
  /// [page] 页码（从1开始）
  /// [pageSize] 每页数量（默认30）
  Future<List<BilibiliVideo>> getUploaderVideos({
    required int mid,
    int page = 1,
    int pageSize = 30,
  }) async {
    debugPrint('🔍 请求UP主视频列表: mid=$mid, page=$page');

    // 确保 WBI keys 有效
    await _ensureWbiKeys();

    // 使用 WBI 签名
    final params = _wbiSigner.encodeWbiToMap(
      {
        'mid': mid.toString(),
        'ps': pageSize.toString(),
        'pn': page.toString(),
        'order': 'pubdate',
      },
      _imgKey!,
      _subKey!,
    );

    debugPrint('📡 WBI 签名后的参数: $params');

    final data = await _client.get<Map<String, dynamic>>(
      '/x/space/wbi/arc/search',
      params: params,
    );

    final list = data['list'] as Map<String, dynamic>?;
    if (list == null) {
      debugPrint('⚠️ UP主视频列表为空');
      return [];
    }

    final vlist = list['vlist'] as List<dynamic>?;
    if (vlist == null || vlist.isEmpty) {
      debugPrint('⚠️ vlist为空');
      return [];
    }

    debugPrint('✅ 获取到 ${vlist.length} 个视频');

    return vlist.map((item) {
      final json = item as Map<String, dynamic>;
      return BilibiliVideo(
        aid: json['aid'] as int,
        bvid: json['bvid'] as String,
        title: json['title'] as String,
        pic: json['pic'] as String,
        duration: json['length'] is String
            ? _parseDuration(json['length'])
            : (json['length'] as int? ?? 0),
        desc: json['description'] as String?,
        owner: BilibiliUploader(
          mid: json['mid'] as int? ?? mid,
          name: json['author'] as String? ?? '',
          face: null,
        ),
        cid: 0,
        pubdate: json['created'] as int? ?? 0,
      );
    }).toList();
  }


  /// 获取分区排行榜（ranking/v2）
  ///
  /// 基于 bilibili-api-collect/docs/video_ranking/ranking.md
  /// 注意：该接口仅支持主分区（rid 为主分区 tid）。
  Future<List<BilibiliVideo>> getZoneRankingV2({
    required int rid,
    String type = 'all',
    int page = 1,
    int pageSize = 30,
  }) async {
    await _ensureWbiKeys();

    final rawParams = <String, dynamic>{
      'rid': rid.toString(),
      'type': type,
    };

    final params = _wbiSigner.encodeWbiToMap(
      rawParams,
      _imgKey!,
      _subKey!,
    );

    debugPrint('[BilibiliApiService] ranking/v2: rid=$rid type=$type page=$page pageSize=$pageSize');

    final data = await _client.get<Map<String, dynamic>>(
      '/x/web-interface/ranking/v2',
      params: params,
    );

    final list = data['list'] as List<dynamic>?;
    if (list == null || list.isEmpty) {
      debugPrint('[BilibiliApiService] ranking/v2 empty: rid=$rid');
      return [];
    }

    final start = (page - 1) * pageSize;
    if (start >= list.length) return [];

    final endExclusive = (start + pageSize) > list.length ? list.length : (start + pageSize);
    final pageItems = list.sublist(start, endExclusive);

    return pageItems.map((item) {
      final json = item as Map<String, dynamic>;
      final owner = json['owner'] as Map<String, dynamic>?;
      final stat = json['stat'] as Map<String, dynamic>?;

      return BilibiliVideo(
        aid: _parseSafeInt(json['aid']),
        bvid: json['bvid'] as String? ?? '',
        title: json['title'] as String? ?? '',
        pic: _normalizePicUrl(json['pic'] as String? ?? ''),
        duration: _parseSafeInt(json['duration']),
        desc: json['desc'] as String?,
        owner: BilibiliUploader(
          mid: _parseSafeInt(owner?['mid']),
          name: owner?['name'] as String? ?? '',
          face: owner?['face'] as String?,
        ),
        cid: 0,
        pubdate: _parseSafeInt(json['pubdate']),
        view: _parseSafeInt(stat?['view']),
        danmaku: _parseSafeInt(stat?['danmaku']),
        reply: _parseSafeInt(stat?['reply']),
        favorite: _parseSafeInt(stat?['favorite']),
        coin: _parseSafeInt(stat?['coin']),
        share: _parseSafeInt(stat?['share']),
        like: _parseSafeInt(stat?['like']),
      );
    }).toList();
  }


  /// 获取分区视频列表（newlist_rank）
  ///
  /// 基于 bilibili-api-collect/docs/video_ranking/dynamic.md
  /// [cateId] 分区 ID（v1 tid）
  /// [order] 排序方式：click/scores/stow/coin/dm
  /// [page] 页码（从1开始）
  /// [pageSize] 每页数量
  /// [rangeDays] 时间范围（默认 7 天）
  Future<List<BilibiliVideo>> getZoneRankList({
    required int cateId,
    String order = 'click',
    int page = 1,
    int pageSize = 30,
    int rangeDays = 7,
  }) async {
    final now = DateTime.now();
    final timeTo = _formatYmd(now);
    final timeFrom = _formatYmd(now.subtract(Duration(days: rangeDays)));
    final params = <String, dynamic>{
      'main_ver': 'v3',
      'search_type': 'video',
      'view_type': 'hot_rank',
      'copy_right': -1,
      'new_web_tag': 1,
      'order': order.isEmpty ? 'click' : order,
      'cate_id': cateId,
      'page': page,
      'pagesize': pageSize,
      'time_from': timeFrom,
      'time_to': timeTo,
    };

    final data = await _client.get<Map<String, dynamic>>(
      '/x/web-interface/newlist_rank',
      params: params,
    );

    debugPrint('[BilibiliApiService] getZoneRankList: cateId=$cateId order=${params['order']} page=$page pageSize=$pageSize timeFrom=$timeFrom timeTo=$timeTo');
    debugPrint('[BilibiliApiService] newlist_rank keys: ${data.keys.toList()}');
    debugPrint('[BilibiliApiService] newlist_rank meta: msg=${data['msg']} numResults=${data['numResults']} numPages=${data['numPages']} page=${data['page']} pagesize=${data['pagesize']}');
    final rawResult = data['result'];
    debugPrint('[BilibiliApiService] newlist_rank rawResult: type=${rawResult.runtimeType} len=${rawResult is List ? rawResult.length : 'n/a'}');

    final result = (data['result'] as List<dynamic>?) ??
        (data['list'] as List<dynamic>?) ??
        (data['rank'] as List<dynamic>?);
    if (result == null || result.isEmpty) {
      return [];
    }

    debugPrint('[BilibiliApiService] newlist_rank result count=${result.length}');
    return result.map((item) {
      final json = item as Map<String, dynamic>;
      final ownerName = json['author'] as String? ?? '';
      final ownerMid = _parseSafeInt(json['mid']);
      final coinValue = json.containsKey('coin') ? json['coin'] : json['coins'];

      return BilibiliVideo(
        aid: _parseSafeInt(json['id']),
        bvid: json['bvid'] as String? ?? '',
        title: json['title'] as String? ?? '',
        pic: _normalizePicUrl(json['pic'] as String? ?? ''),
        duration: _parseSafeInt(json['duration']),
        desc: json['description'] as String?,
        owner: BilibiliUploader(
          mid: ownerMid,
          name: ownerName,
          face: null,
        ),
        cid: 0,
        pubdate: _parseSafeInt(json['senddate']),
        view: _parseSafeInt(json['play']),
        danmaku: _parseSafeInt(json['video_review']),
        reply: _parseSafeInt(json['review']),
        favorite: _parseSafeInt(json['favorites']),
        coin: _parseSafeInt(coinValue),
      );
    }).toList();
  }

  String _formatYmd(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }
}
