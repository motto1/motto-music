import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:motto_music/services/cache/album_art_cache_service.dart';

/// 统一封面图片组件
///
/// 自动判断封面类型（网络URL / 本地文件 / 无封面）
/// 统一处理缓存、占位符、错误状态。
///
/// 额外能力：对 B 站图片 URL（bilibili.com / hdslb.com）
/// 自动使用 [AlbumArtCacheService] 落地到本地文件路径，以提升稳定性并减少反复转圈。
///
/// 设计原则：
/// - KISS: 简单的接口，自动判断类型
/// - DRY: 消除重复的封面渲染逻辑
class UnifiedCoverImage extends StatefulWidget {
  /// 文件存在性缓存（静态缓存，避免重复检查）
  /// Key: 文件路径, Value: 是否存在
  static final Map<String, bool> _fileExistsCache = {};

  /// 封面路径（可以是网络URL或本地文件路径）
  final String? coverPath;

  /// 图片宽度
  final double width;

  /// 图片高度
  final double height;

  /// 圆角半径
  final double borderRadius;

  /// 图片填充方式
  final BoxFit fit;

  /// 自定义占位符（可选）
  final Widget? placeholder;

  /// 自定义错误图标（可选）
  final Widget? errorWidget;

  /// 是否为深色模式（用于默认占位符颜色）
  final bool? isDark;

  /// 是否跳过本地文件的异步存在性检查，直接尝试加载文件
  ///
  /// - true: 直接使用 Image.file + errorBuilder，避免 FutureBuilder 带来的短暂加载占位（默认）
  /// - false: 使用异步 exists 检查，适合文件路径可能频繁变化的场景
  final bool skipAsyncFileCheck;

  /// 是否对 Bilibili 图片启用本地落地缓存（cover_cache）。
  ///
  /// - true: 网络图片在后台写入本地文件，后续优先使用 Image.file 渲染
  /// - false: 仅使用 CachedNetworkImage 的默认缓存
  final bool enableBilibiliLocalCache;

  const UnifiedCoverImage({
    super.key,
    this.coverPath,
    this.width = 56,
    this.height = 56,
    this.borderRadius = 6,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.isDark,
    this.skipAsyncFileCheck = true,
    this.enableBilibiliLocalCache = true,
  });

  /// 清除文件存在性缓存（用于文件系统变更后刷新）
  static void clearFileCache() {
    _fileExistsCache.clear();
  }

  /// 移除特定文件的缓存（用于单个文件更新）
  static void removeFileCache(String path) {
    _fileExistsCache.remove(path);
  }

  @override
  State<UnifiedCoverImage> createState() => _UnifiedCoverImageState();
}
class _BilibiliCoverLocalCache {
  static const int _maxInFlight = 4;

  static final Queue<String> _queue = Queue<String>();
  static final Set<String> _queued = <String>{};
  static final Set<String> _inFlight = <String>{};
  static final Map<String, String> _resolved = <String, String>{};
  static final Map<String, Completer<String?>> _completers =
      <String, Completer<String?>>{};

  static bool _drainScheduled = false;

  static String? getResolved(String url) => _resolved[url];

  static Future<String?> resolve(String url) {
    final cached = _resolved[url];
    if (cached != null && cached.isNotEmpty) {
      return Future.value(cached);
    }

    final existing = _completers[url];
    if (existing != null) {
      return existing.future;
    }

    final completer = Completer<String?>();
    _completers[url] = completer;

    if (_queued.add(url)) {
      _queue.add(url);
    }
    _scheduleDrain();

    return completer.future;
  }

  static void _scheduleDrain() {
    if (_drainScheduled) return;
    _drainScheduled = true;
    scheduleMicrotask(() {
      _drainScheduled = false;
      _drain();
    });
  }

  static void _drain() {
    while (_inFlight.length < _maxInFlight && _queue.isNotEmpty) {
      final url = _queue.removeFirst();
      _queued.remove(url);
      if (_inFlight.contains(url)) continue;
      _inFlight.add(url);
      unawaited(_process(url));
    }
  }

  static Future<void> _process(String url) async {
    try {
      String? resolved;
      try {
        final local = await AlbumArtCacheService.instance.ensureLocalPath(url);
        if (local != null && local.isNotEmpty && local != url) {
          resolved = local;
        }
      } catch (_) {
        resolved = null;
      }

      if (resolved != null) {
        _resolved[url] = resolved;
      }

      final completer = _completers.remove(url);
      completer?.complete(resolved);
    } finally {
      _inFlight.remove(url);
      _scheduleDrain();
    }
  }
}
class _UnifiedCoverImageState extends State<UnifiedCoverImage> {
  String? _resolvedPath;
  int _resolveGeneration = 0;

  @override
  void initState() {
    super.initState();
    _resolvedPath = widget.coverPath;
    _maybeResolveBilibiliToLocal();
  }

  @override
  void didUpdateWidget(covariant UnifiedCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverPath != widget.coverPath) {
      _resolvedPath = widget.coverPath;
      _maybeResolveBilibiliToLocal();
    }
  }

  bool _isNetwork(String? path) {
    if (path == null) return false;
    return path.startsWith('http://') || path.startsWith('https://');
  }

  bool get _isNetworkImage => _isNetwork(_resolvedPath);

  bool get _isLocalFile => _resolvedPath != null && !_isNetworkImage;

  void _maybeResolveBilibiliToLocal() {
    if (!widget.enableBilibiliLocalCache) return;

    final url = widget.coverPath;
    if (url == null || url.isEmpty) return;
    if (!_isNetwork(url)) return;
    if (!AlbumArtCacheService.isBilibiliImageUrl(url)) return;

    final already = _BilibiliCoverLocalCache.getResolved(url);
    if (already != null && already.isNotEmpty && already != url) {
      if (_resolvedPath != already && mounted) {
        setState(() => _resolvedPath = already);
      }
      return;
    }

    final generation = ++_resolveGeneration;
    unawaited(
      _BilibiliCoverLocalCache.resolve(url).then((localPath) {
        if (!mounted || generation != _resolveGeneration) return;
        if (localPath == null || localPath.isEmpty) return;
        if (_resolvedPath == localPath) return;
        setState(() => _resolvedPath = localPath);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        widget.isDark ?? Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF3A3A3C) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: _buildImage(context, isDarkMode),
      ),
    );
  }

  Widget _buildImage(BuildContext context, bool isDarkMode) {
    final path = _resolvedPath;

    if (path == null || path.isEmpty) {
      return _buildDefaultIcon(isDarkMode);
    }

    if (_isNetworkImage) {
      return CachedNetworkImage(
        imageUrl: path,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (context, url) =>
            widget.placeholder ?? _buildPlaceholder(isDarkMode),
        errorWidget: (context, url, error) =>
            widget.errorWidget ?? _buildDefaultIcon(isDarkMode),
      );
    }

    if (_isLocalFile) {
      if (widget.skipAsyncFileCheck) {
        return Image.file(
          File(path),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            return widget.errorWidget ?? _buildDefaultIcon(isDarkMode);
          },
        );
      }

      return FutureBuilder<bool>(
        future: _checkFileExists(path),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return widget.placeholder ?? _buildPlaceholder(isDarkMode);
          }

          if (snapshot.data == true) {
            return Image.file(
              File(path),
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              errorBuilder: (context, error, stackTrace) {
                return widget.errorWidget ?? _buildDefaultIcon(isDarkMode);
              },
            );
          }

          return widget.errorWidget ?? _buildDefaultIcon(isDarkMode);
        },
      );
    }

    return _buildDefaultIcon(isDarkMode);
  }

  Future<bool> _checkFileExists(String path) async {
    if (UnifiedCoverImage._fileExistsCache.containsKey(path)) {
      return UnifiedCoverImage._fileExistsCache[path]!;
    }

    try {
      final file = File(path);
      final exists = await file.exists();
      UnifiedCoverImage._fileExistsCache[path] = exists;
      return exists;
    } catch (_) {
      UnifiedCoverImage._fileExistsCache[path] = false;
      return false;
    }
  }

  Widget _buildPlaceholder(bool isDarkMode) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: isDarkMode ? const Color(0xFF3A3A3C) : const Color(0xFFFFFFFF),
      child: Center(
        child: SizedBox(
          width: widget.width * 0.3,
          height: widget.width * 0.3,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultIcon(bool isDarkMode) {
    return Center(
      child: Icon(
        Icons.music_note,
        size: widget.width * 0.4,
        color: isDarkMode
            ? Colors.white.withOpacity(0.3)
            : Colors.black.withOpacity(0.3),
      ),
    );
  }
}
