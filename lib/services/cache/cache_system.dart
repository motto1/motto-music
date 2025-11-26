import 'cache_manager.dart';
import 'metadata_cache_service.dart';

/// 缓存系统初始化入口
class CacheSystem {
  static bool _initialized = false;

  /// 初始化所有缓存服务
  static Future<void> init() async {
    if (_initialized) {
      print('⚠️ CacheSystem 已经初始化过');
      return;
    }

    print('🚀 开始初始化缓存系统...');

    // 1. 初始化 L1+L2 缓存管理器
    await UnifiedCacheManager.instance.init();

    // 2. 初始化元数据缓存服务
    await MetadataCacheService.instance.init();

    _initialized = true;
    print('✅ 缓存系统初始化完成');
  }

  /// 清空所有缓存
  static Future<void> clearAll() async {
    await UnifiedCacheManager.instance.clearAll();
    await MetadataCacheService.instance.clearAllCache();
    print('🗑️ 所有缓存已清空');
  }

  /// 获取缓存统计信息
  static Future<Map<String, dynamic>> getStats() async {
    final unifiedStats = UnifiedCacheManager.instance.getStats();
    final metadataStats = await MetadataCacheService.instance.getStats();

    return {
      'unified_cache': unifiedStats,
      'metadata_cache': metadataStats,
    };
  }
}
