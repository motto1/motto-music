import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:motto_music/database/database.dart';

/// 可动画的封面组件
/// 
/// 根据 percentage 在迷你模式和全屏模式之间平滑过渡
/// 
/// 动画属性：
/// - 位置：从左上角 → 屏幕中央（或左上角，取决于showLyrics）
/// - 大小：60x60 → 动态计算（或60x60，取决于showLyrics）
/// - 圆角：12 → 20（或12，取决于showLyrics）
/// - 阴影：无 → 深度阴影（或无，取决于showLyrics）
/// - 缩放：播放时 1.0，暂停时 0.95
class AnimatedCoverArt extends StatelessWidget {
  /// 当前歌曲
  final Song? currentSong;
  
  /// 展开百分比 (0.0 = 迷你, 1.0 = 全屏)
  final double percentage;
  
  /// 内容区宽度（Expanded 内的可用宽度）
  final double contentWidth;
  
  /// 内容区高度（Expanded 内的可用高度）
  final double contentHeight;
  
  /// 迷你模式高度（用于计算位置）
  final double miniHeight;
  
  /// 是否正在播放
  final bool isPlaying;
  
  /// 是否显示歌词（true时封面变小）
  final bool showLyrics;
  
  /// 点击回调
  final VoidCallback? onTap;

  const AnimatedCoverArt({
    super.key,
    required this.currentSong,
    required this.percentage,
    required this.contentWidth,
    required this.contentHeight,
    required this.miniHeight,
    this.isPlaying = true,
    this.showLyrics = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 计算动画属性
    final animProps = _calculateAnimationProperties();
    
    // 动画时长：完全展开时使用200ms以支持封面/歌词切换，其他时候跟随手势
    final animationDuration = percentage >= 0.95 
        ? const Duration(milliseconds: 200) 
        : Duration.zero;
    
    return AnimatedPositioned(
      duration: animationDuration,
      curve: Curves.linear,
      left: animProps.left,
      top: animProps.top,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: isPlaying ? 1.0 : 0.95, // 暂停时缩小到0.95
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: animationDuration,
            curve: Curves.linear,
            width: animProps.size,
            height: animProps.size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(animProps.borderRadius),
              boxShadow: animProps.showShadow
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6 * percentage),
                        blurRadius: 50 * percentage,
                        spreadRadius: 5 * percentage,
                        offset: Offset(0, 15 * percentage),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3 * percentage),
                        blurRadius: 80 * percentage,
                        spreadRadius: 10 * percentage,
                        offset: Offset(0, 25 * percentage),
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildCoverImage(context),
          ),
        ),
      ),
    );
  }

  /// 计算动画属性（使用响应式计算）
  _AnimationProperties _calculateAnimationProperties() {
    // ============ 小封面参数（固定） ============
    const miniSize = 60.0;
    const miniLeft = 12.0; // 迷你模式的 left
    const miniTop = 8.0;   // 迷你模式的 top
    
    // ============ 大封面尺寸计算（响应式） ============
    // 歌名+艺术家区域高度（封面模式下显示）
    final songInfoHeight = contentHeight * 0.12; // 约12%的高度
    // 上下padding（响应式）
    final verticalPadding = contentHeight * 0.08; // 约8%的高度
    
    final maxCoverHeight = contentHeight - songInfoHeight - verticalPadding;
    final maxCoverWidth = contentWidth * 0.85;
    final largeCoverSize = min(maxCoverHeight, maxCoverWidth).clamp(200.0, 360.0);
    
    // ============ 根据 showLyrics 决定目标尺寸 ============
    final targetSize = showLyrics ? 60.0 : largeCoverSize;
    
    // 根据 percentage 插值尺寸
    final size = miniSize + (targetSize - miniSize) * percentage;
    
    // ============ 圆角动画 ============
    final targetBorderRadius = showLyrics ? 12.0 : 20.0;
    final borderRadius = 12.0 + (targetBorderRadius - 12.0) * percentage;
    
    // ============ 位置计算（响应式） ============
    double targetLeft;
    double targetTop;
    
    if (showLyrics) {
      // 显示歌词时：封面在左上角（歌名旁边）
      targetLeft = 20.0;
      targetTop = 10.0;
    } else {
      // 显示封面时：封面居中（响应式计算）
      targetLeft = (contentWidth - largeCoverSize) / 2;
      // 可用的垂直空间（减去歌名区域）
      final availableTopSpace = contentHeight - songInfoHeight;
      // 封面垂直居中，稍微偏上一点（上方占40%，下方占60%）
      targetTop = (availableTopSpace - largeCoverSize) * 0.4;
    }
    
    // 插值计算
    final left = miniLeft + (targetLeft - miniLeft) * percentage;
    final top = miniTop + (targetTop - miniTop) * percentage;
    
    // 是否显示阴影（展开超过50%且不显示歌词）
    final showShadow = percentage > 0.5 && !showLyrics;
    
    return _AnimationProperties(
      size: size,
      borderRadius: borderRadius,
      left: left,
      top: top,
      showShadow: showShadow,
    );
  }

  /// 构建封面图片
  Widget _buildCoverImage(BuildContext context) {
    final albumArtPath = currentSong?.albumArtPath;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderBg = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final placeholderIcon = isDark ? Colors.white38 : Colors.black26;

    if (albumArtPath == null || albumArtPath.isEmpty) {
      return Container(
        color: placeholderBg,
        child: Icon(
          Icons.music_note,
          size: 80,
          color: placeholderIcon,
        ),
      );
    }

    // 判断是网络 URL 还是本地文件
    if (albumArtPath.startsWith('http://') || albumArtPath.startsWith('https://')) {
      return Image.network(
        albumArtPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: placeholderBg,
            child: Icon(
              Icons.music_note,
              size: 80,
              color: placeholderIcon,
            ),
          );
        },
      );
    } else {
      // 本地文件
      if (File(albumArtPath).existsSync()) {
        return Image.file(
          File(albumArtPath),
          fit: BoxFit.cover,
        );
      } else {
        return Container(
          color: placeholderBg,
          child: Icon(
            Icons.music_note,
            size: 80,
            color: placeholderIcon,
          ),
        );
      }
    }
  }
}

/// 动画属性数据类
class _AnimationProperties {
  final double size;
  final double borderRadius;
  final double left;
  final double top;
  final bool showShadow;

  _AnimationProperties({
    required this.size,
    required this.borderRadius,
    required this.left,
    required this.top,
    required this.showShadow,
  });
}
