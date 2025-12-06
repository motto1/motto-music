import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 统一封面图片组件
///
/// 自动判断封面类型（网络URL / 本地文件 / 无封面）
/// 统一处理缓存、占位符、错误状态
///
/// 设计原则：
/// - KISS: 简单的接口，自动判断类型
/// - DRY: 消除重复的封面渲染逻辑
/// - 性能: 异步检查文件，避免阻塞UI
///
/// 使用示例：
/// ```dart
/// // 网络图片
/// UnifiedCoverImage(coverPath: 'https://example.com/cover.jpg')
///
/// // 本地文件
/// UnifiedCoverImage(coverPath: '/storage/music/cover.jpg')
///
/// // 无封面（显示默认图标）
/// UnifiedCoverImage(coverPath: null)
/// ```
class UnifiedCoverImage extends StatelessWidget {
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
    this.skipAsyncFileCheck = true, // 默认跳过异步检查，避免重建时闪烁
  });

  /// 判断是否为网络图片
  bool get _isNetworkImage {
    if (coverPath == null) return false;
    return coverPath!.startsWith('http://') || coverPath!.startsWith('https://');
  }

  /// 判断是否为本地文件
  bool get _isLocalFile {
    return coverPath != null && !_isNetworkImage;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = isDark ?? Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF3A3A3C)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: _buildImage(context, isDarkMode),
      ),
    );
  }

  Widget _buildImage(BuildContext context, bool isDarkMode) {
    // 无封面：显示默认图标
    if (coverPath == null || coverPath!.isEmpty) {
      return _buildDefaultIcon(isDarkMode);
    }

    // 网络图片：使用 CachedNetworkImage
    if (_isNetworkImage) {
      return CachedNetworkImage(
        imageUrl: coverPath!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => placeholder ?? _buildPlaceholder(isDarkMode),
        errorWidget: (context, url, error) => errorWidget ?? _buildDefaultIcon(isDarkMode),
      );
    }

    // 本地文件：异步检查文件存在性
    if (_isLocalFile) {
      if (skipAsyncFileCheck) {
        // 直接尝试加载本地文件，由 errorBuilder 处理不存在或解码失败的情况
        return Image.file(
          File(coverPath!),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ?? _buildDefaultIcon(isDarkMode);
          },
        );
      }

      return FutureBuilder<bool>(
        future: _checkFileExists(coverPath!),
        builder: (context, snapshot) {
          // 加载中：显示占位符
          if (snapshot.connectionState == ConnectionState.waiting) {
            return placeholder ?? _buildPlaceholder(isDarkMode);
          }

          // 文件存在：显示图片
          if (snapshot.data == true) {
            return Image.file(
              File(coverPath!),
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                return errorWidget ?? _buildDefaultIcon(isDarkMode);
              },
            );
          }

          // 文件不存在：显示默认图标
          return errorWidget ?? _buildDefaultIcon(isDarkMode);
        },
      );
    }

    // 未知类型：显示默认图标
    return _buildDefaultIcon(isDarkMode);
  }

  /// 异步检查文件是否存在（避免阻塞UI）
  ///
  /// 使用静态缓存避免重复检查同一文件
  /// 缓存策略：
  /// - 命中缓存：直接返回结果（避免重复IO）
  /// - 未命中：执行文件检查并缓存结果
  /// - 错误处理：捕获异常并缓存为false
  Future<bool> _checkFileExists(String path) async {
    // 检查缓存
    if (_fileExistsCache.containsKey(path)) {
      return _fileExistsCache[path]!;
    }

    // 执行文件检查
    try {
      final file = File(path);
      final exists = await file.exists();
      _fileExistsCache[path] = exists;
      return exists;
    } catch (e) {
      _fileExistsCache[path] = false;
      return false;
    }
  }

  /// 清除文件存在性缓存（用于文件系统变更后刷新）
  static void clearFileCache() {
    _fileExistsCache.clear();
  }

  /// 移除特定文件的缓存（用于单个文件更新）
  static void removeFileCache(String path) {
    _fileExistsCache.remove(path);
  }

  /// 构建占位符
  Widget _buildPlaceholder(bool isDarkMode) {
    return Container(
      width: width,
      height: height,
      color: isDarkMode
          ? const Color(0xFF3A3A3C)
          : const Color(0xFFFFFFFF),
      child: Center(
        child: SizedBox(
          width: width * 0.3,
          height: width * 0.3,
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

  /// 构建默认图标
  Widget _buildDefaultIcon(bool isDarkMode) {
    return Center(
      child: Icon(
        Icons.music_note,
        size: width * 0.4,
        color: isDarkMode
            ? Colors.white.withOpacity(0.3)
            : Colors.black.withOpacity(0.3),
      ),
    );
  }
}
