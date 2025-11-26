import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// 缓存条目
class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final Duration ttl;

  CacheEntry(this.data, this.createdAt, this.ttl);

  bool get isExpired => DateTime.now().difference(createdAt) > ttl;

  Map<String, dynamic> toJson(dynamic Function(T) serializer) => {
        'data': serializer(data),
        'createdAt': createdAt.toIso8601String(),
        'ttl': ttl.inSeconds,
      };

  static CacheEntry<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(dynamic) deserializer,
  ) {
    return CacheEntry<T>(
      deserializer(json['data']),
      DateTime.parse(json['createdAt'] as String),
      Duration(seconds: json['ttl'] as int),
    );
  }
}

/// 缓存配置
class CacheConfig {
  final Duration defaultTTL;
  final int maxMemoryCacheSize;
  final Duration cleanupInterval;

  const CacheConfig({
    this.defaultTTL = const Duration(hours: 1),
    this.maxMemoryCacheSize = 100,
    this.cleanupInterval = const Duration(minutes: 5),
  });
}

/// 统一缓存管理器 (L1内存 + L2 Hive)
class UnifiedCacheManager {
  static UnifiedCacheManager? _instance;
  static UnifiedCacheManager get instance => _instance ??= UnifiedCacheManager._();

  UnifiedCacheManager._();

  // L1: 内存缓存
  final Map<String, CacheEntry<dynamic>> _memoryCache = {};

  // L2: Hive 缓存
  Box<String>? _hiveCache;

  // 配置
  final config = const CacheConfig();

  // 初始化标志
  bool _initialized = false;

  /// 初始化缓存管理器
  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();
    _hiveCache = await Hive.openBox<String>('unified_cache');

    // 启动定期清理
    _startPeriodicCleanup();

    _initialized = true;
    print('✅ UnifiedCacheManager 初始化完成');
  }

  /// 定期清理过期缓存
  void _startPeriodicCleanup() {
    Future.delayed(config.cleanupInterval, () {
      _cleanupExpiredEntries();
      _startPeriodicCleanup(); // 递归调用
    });
  }

  /// 清理过期条目
  Future<void> _cleanupExpiredEntries() async {
    // L1: 清理内存缓存
    _memoryCache.removeWhere((key, entry) => entry.isExpired);

    // L2: 清理 Hive 缓存
    if (_hiveCache != null) {
      final keysToDelete = <String>[];
      for (var key in _hiveCache!.keys) {
        final data = _hiveCache!.get(key);
        if (data != null) {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final createdAt = DateTime.parse(json['createdAt'] as String);
            final ttl = Duration(seconds: json['ttl'] as int);
            if (DateTime.now().difference(createdAt) > ttl) {
              keysToDelete.add(key as String);
            }
          } catch (_) {
            keysToDelete.add(key as String);
          }
        }
      }
      await _hiveCache!.deleteAll(keysToDelete);
    }

    print('🧹 缓存清理完成: L1=${_memoryCache.length}, L2=${_hiveCache?.length ?? 0}');
  }

  /// 生成缓存键
  String _generateKey(String namespace, String key) => '$namespace:$key';

  /// L1 + L2 缓存读取
  Future<T?> get<T>(
    String namespace,
    String key, {
    T Function(dynamic)? deserializer,
  }) async {
    final fullKey = _generateKey(namespace, key);

    // L1: 检查内存缓存
    final memEntry = _memoryCache[fullKey] as CacheEntry<T>?;
    if (memEntry != null && !memEntry.isExpired) {
      print('🎯 L1缓存命中: $fullKey');
      return memEntry.data;
    }

    // L2: 检查 Hive 缓存
    final hiveData = _hiveCache?.get(fullKey);
    if (hiveData != null && deserializer != null) {
      try {
        final json = jsonDecode(hiveData) as Map<String, dynamic>;
        final entry = CacheEntry.fromJson(json, deserializer);

        if (!entry.isExpired) {
          // 回填 L1 缓存
          _memoryCache[fullKey] = entry;
          print('💾 L2缓存命中: $fullKey');
          return entry.data;
        } else {
          // 删除过期数据
          await _hiveCache?.delete(fullKey);
        }
      } catch (e) {
        print('⚠️ L2缓存解析失败: $fullKey - $e');
        await _hiveCache?.delete(fullKey);
      }
    }

    return null;
  }

  /// L1 + L2 缓存写入
  Future<void> set<T>(
    String namespace,
    String key,
    T data, {
    Duration? ttl,
    dynamic Function(T)? serializer,
  }) async {
    final fullKey = _generateKey(namespace, key);
    final entry = CacheEntry(data, DateTime.now(), ttl ?? config.defaultTTL);

    // L1: 写入内存
    _memoryCache[fullKey] = entry;

    // L1 大小限制
    if (_memoryCache.length > config.maxMemoryCacheSize) {
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }

    // L2: 写入 Hive
    if (serializer != null) {
      try {
        final json = entry.toJson(serializer);
        await _hiveCache?.put(fullKey, jsonEncode(json));
        print('✅ 缓存写入: $fullKey (TTL: ${ttl ?? config.defaultTTL})');
      } catch (e) {
        print('⚠️ L2缓存写入失败: $fullKey - $e');
      }
    }
  }

  /// 删除缓存
  Future<void> delete(String namespace, String key) async {
    final fullKey = _generateKey(namespace, key);
    _memoryCache.remove(fullKey);
    await _hiveCache?.delete(fullKey);
    print('🗑️ 缓存删除: $fullKey');
  }

  /// 清空指定命名空间
  Future<void> clearNamespace(String namespace) async {
    final prefix = '$namespace:';

    // L1: 清空内存缓存
    _memoryCache.removeWhere((key, _) => key.startsWith(prefix));

    // L2: 清空 Hive 缓存
    if (_hiveCache != null) {
      final keysToDelete = _hiveCache!.keys
          .where((key) => (key as String).startsWith(prefix))
          .cast<String>()
          .toList();
      await _hiveCache!.deleteAll(keysToDelete);
    }

    print('🗑️ 命名空间清空: $namespace');
  }

  /// 清空所有缓存
  Future<void> clearAll() async {
    _memoryCache.clear();
    await _hiveCache?.clear();
    print('🗑️ 全部缓存已清空');
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getStats() {
    return {
      'l1_size': _memoryCache.length,
      'l2_size': _hiveCache?.length ?? 0,
      'max_l1_size': config.maxMemoryCacheSize,
      'default_ttl': config.defaultTTL.toString(),
    };
  }
}
