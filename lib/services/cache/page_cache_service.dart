import 'cache_manager.dart';
import '../../models/bilibili/favorite.dart';
import '../../models/bilibili/video.dart';
import '../../models/bilibili/user.dart';

/// 页面缓存服务
/// 负责缓存收藏夹、视频列表、用户信息等页面数据
class PageCacheService {
  final _cache = UnifiedCacheManager.instance;

  // ==================== 收藏夹缓存 ====================

  /// 缓存收藏夹列表
  Future<void> cacheFavoritesList(int userId, List<BilibiliFavorite> favorites) async {
    await _cache.set(
      'favorites',
      'list_$userId',
      favorites,
      ttl: const Duration(hours: 6),
      serializer: (data) => (data as List<BilibiliFavorite>)
          .map((e) => e.toJson())
          .toList(),
    );
  }

  /// 获取缓存的收藏夹列表
  Future<List<BilibiliFavorite>?> getCachedFavoritesList(int userId) async {
    return await _cache.get<List<BilibiliFavorite>>(
      'favorites',
      'list_$userId',
      deserializer: (data) => (data as List)
          .map((e) => BilibiliFavorite.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 缓存收藏夹详情
  Future<void> cacheFavoriteDetail(
    int favoriteId,
    List<BilibiliFavoriteItem> items,
  ) async {
    await _cache.set(
      'favorites',
      'detail_$favoriteId',
      items,
      ttl: const Duration(hours: 3),
      serializer: (data) => (data as List<BilibiliFavoriteItem>)
          .map((e) => e.toJson())
          .toList(),
    );
  }

  /// 获取缓存的收藏夹详情
  Future<List<BilibiliFavoriteItem>?> getCachedFavoriteDetail(int favoriteId) async {
    return await _cache.get<List<BilibiliFavoriteItem>>(
      'favorites',
      'detail_$favoriteId',
      deserializer: (data) => (data as List)
          .map((e) => BilibiliFavoriteItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // ==================== Bilibili 视频缓存 ====================

  /// 缓存视频列表
  Future<void> cacheVideoList(String queryKey, List<BilibiliVideo> videos) async {
    await _cache.set(
      'videos',
      queryKey,
      videos,
      ttl: const Duration(hours: 12),
      serializer: (data) => (data as List<BilibiliVideo>)
          .map((e) => e.toJson())
          .toList(),
    );
  }

  /// 获取缓存的视频列表
  Future<List<BilibiliVideo>?> getCachedVideoList(String queryKey) async {
    return await _cache.get<List<BilibiliVideo>>(
      'videos',
      queryKey,
      deserializer: (data) => (data as List)
          .map((e) => BilibiliVideo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 缓存视频详情
  Future<void> cacheVideoDetail(String bvid, BilibiliVideo video) async {
    await _cache.set(
      'videos',
      'detail_$bvid',
      video,
      ttl: const Duration(days: 1),
      serializer: (data) => (data as BilibiliVideo).toJson(),
    );
  }

  /// 获取缓存的视频详情
  Future<BilibiliVideo?> getCachedVideoDetail(String bvid) async {
    return await _cache.get<BilibiliVideo>(
      'videos',
      'detail_$bvid',
      deserializer: (data) => BilibiliVideo.fromJson(data as Map<String, dynamic>),
    );
  }

  // ==================== 用户信息缓存 ====================

  /// 缓存用户信息
  Future<void> cacheUserInfo(BilibiliUploader userInfo) async {
    await _cache.set(
      'user',
      'info_${userInfo.mid}',
      userInfo,
      ttl: const Duration(days: 1),
      serializer: (data) => (data as BilibiliUploader).toJson(),
    );
  }

  /// 获取缓存的用户信息
  Future<BilibiliUploader?> getCachedUserInfo(int mid) async {
    return await _cache.get<BilibiliUploader>(
      'user',
      'info_$mid',
      deserializer: (data) => BilibiliUploader.fromJson(data as Map<String, dynamic>),
    );
  }

  // ==================== 搜索结果缓存 ====================

  /// 缓存搜索结果
  Future<void> cacheSearchResults(String query, List<BilibiliVideo> results) async {
    await _cache.set(
      'search',
      query,
      results,
      ttl: const Duration(hours: 6),
      serializer: (data) => (data as List<BilibiliVideo>)
          .map((e) => e.toJson())
          .toList(),
    );
  }

  /// 获取缓存的搜索结果
  Future<List<BilibiliVideo>?> getCachedSearchResults(String query) async {
    return await _cache.get<List<BilibiliVideo>>(
      'search',
      query,
      deserializer: (data) => (data as List)
          .map((e) => BilibiliVideo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // ==================== 清理方法 ====================

  /// 清空所有收藏夹缓存
  Future<void> clearFavoritesCache() async {
    await _cache.clearNamespace('favorites');
  }

  /// 清空所有视频缓存
  Future<void> clearVideosCache() async {
    await _cache.clearNamespace('videos');
  }

  /// 清空用户信息缓存
  Future<void> clearUserCache() async {
    await _cache.clearNamespace('user');
  }

  /// 清空搜索缓存
  Future<void> clearSearchCache() async {
    await _cache.clearNamespace('search');
  }

  /// 清空所有页面缓存
  Future<void> clearAllPageCache() async {
    await clearFavoritesCache();
    await clearVideosCache();
    await clearUserCache();
    await clearSearchCache();
  }
}
