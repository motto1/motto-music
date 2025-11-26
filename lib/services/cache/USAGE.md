/// ============================================
/// 缓存系统使用示例
/// ============================================

/// 1. 收藏夹页面集成页面缓存
///
/// 在 lib/views/bilibili/favorites_page.dart 中：

import 'package:motto_music/services/cache/page_cache_service.dart';

class _FavoritesPageState extends State<FavoritesPage> {
  final _pageCache = PageCacheService();

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = await _apiService.getCurrentUserInfo().then((u) => u.mid);

      // ⭐ 优先从缓存读取
      var favorites = await _pageCache.getCachedFavoritesList(userId);

      if (favorites != null) {
        // 缓存命中，立即显示
        setState(() {
          _favorites = favorites;
          _isLoading = false;
        });

        // 后台刷新数据
        _refreshFavoritesInBackground(userId);
      } else {
        // 缓存未命中，直接加载
        favorites = await _apiService.getUserFavorites(userId);

        // 写入缓存
        await _pageCache.cacheFavoritesList(userId, favorites);

        setState(() {
          _favorites = favorites;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshFavoritesInBackground(int userId) async {
    try {
      final freshData = await _apiService.getUserFavorites(userId);
      await _pageCache.cacheFavoritesList(userId, freshData);
      setState(() => _favorites = freshData);
    } catch (_) {}
  }
}

/// ============================================
/// 2. 音乐导入集成元数据缓存
///
/// 在 lib/services/music_import_service.dart 中：

import 'package:motto_music/services/cache/metadata_cache_service.dart';

class MusicImportService {
  final _metadataCache = MetadataCacheService.instance;

  Future<void> importMusicFiles(List<File> files) async {
    // ⭐ 批量读取元数据（自动使用缓存）
    final metadataMap = await _metadataCache.batchReadMetadata(files);

    for (final file in files) {
      final metadata = metadataMap[file.path];
      if (metadata == null) continue;

      // 使用元数据插入数据库
      await _insertSongToDatabase(file, metadata);
    }
  }
}

/// ============================================
/// 3. 清理缓存示例（在设置页面）
///
/// 在 lib/views/settings_page.dart 中：

import 'package:motto_music/services/cache/cache_system.dart';
import 'package:motto_music/services/cache/page_cache_service.dart';

void _clearAllCache() async {
  await CacheSystem.clearAll();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('所有缓存已清空')),
  );
}

void _clearFavoritesCache() async {
  final pageCache = PageCacheService();
  await pageCache.clearFavoritesCache();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('收藏夹缓存已清空')),
  );
}

/// ============================================
/// 4. 查看缓存统计
///
/// 在 lib/views/settings_page.dart 中：

Future<void> _showCacheStats() async {
  final stats = await CacheSystem.getStats();
  final unifiedCache = stats['unified_cache'];
  final metadataCache = stats['metadata_cache'];

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('缓存统计'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('L1 内存缓存: ${unifiedCache['l1_size']} 项'),
          Text('L2 Hive缓存: ${unifiedCache['l2_size']} 项'),
          SizedBox(height: 16),
          Text('元数据缓存: ${metadataCache['count']} 个文件'),
          Text('占用空间: ${metadataCache['size_mb']} MB'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('关闭'),
        ),
      ],
    ),
  );
}

/// ============================================
/// 5. 缓存策略说明
///
/// L1 (内存缓存):
/// - 存储热数据，如当前播放队列
/// - TTL: 5-30 分钟
/// - 大小限制: 100 项
/// - 优点: 极快访问速度
///
/// L2 (Hive 持久化):
/// - 存储收藏夹、视频列表、用户信息
/// - TTL: 3-12 小时
/// - 大小: 无硬性限制（自动过期清理）
/// - 优点: 支持离线访问
///
/// L3 (Drift SQLite):
/// - 存储歌曲元数据、播放历史
/// - 永久存储（用户主动删除）
/// - 优点: 强类型、关系查询
///
/// L4 (文件系统):
/// - 存储音频文件、歌词、封面
/// - LRU 清理策略（5GB 限制）
/// - 优点: 离线播放、减少流量

/// ============================================
/// 6. 最佳实践
///
/// ✅ DO:
/// - 在页面加载时优先检查缓存
/// - 使用后台刷新模式（先显示缓存，再刷新）
/// - 为不同数据类型设置合理的 TTL
/// - 定期清理过期缓存
///
/// ❌ DON'T:
/// - 不要缓存敏感用户数据
/// - 不要缓存体积过大的数据到 L1/L2
/// - 不要设置过长的 TTL 导致数据过时
/// - 不要在关键路径上同步清理缓存
