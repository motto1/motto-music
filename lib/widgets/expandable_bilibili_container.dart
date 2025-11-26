import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/views/bilibili/favorites_page.dart';

/// 可展开的 Bilibili 容器内容组件
/// 
/// 根据 percentage 动态显示：
/// - 0.0 - 0.3: 卡片模式（主页上的入口卡片）
/// - 0.3 - 0.7: 过渡阶段
/// - 0.7 - 1.0: 全屏收藏夹页面
class ExpandableBilibiliContent extends StatefulWidget {
  /// 当前容器高度
  final double height;
  
  /// 展开百分比 (0.0 = 卡片, 1.0 = 全屏)
  final double percentage;
  
  /// 最小高度（卡片模式）
  final double minHeight;
  
  /// 最大高度（全屏模式）
  final double maxHeight;
  
  /// 请求关闭回调（返回键时收起容器）
  final VoidCallback? onRequestClose;
  
  /// 卡片渐变色
  final List<Color> cardGradientColors;

  const ExpandableBilibiliContent({
    super.key,
    required this.height,
    required this.percentage,
    required this.minHeight,
    required this.maxHeight,
    this.onRequestClose,
    this.cardGradientColors = const [Color(0xFF00BCD4), Color(0xFF4DD0E1)],
  });

  @override
  State<ExpandableBilibiliContent> createState() => _ExpandableBilibiliContentState();
}

class _ExpandableBilibiliContentState extends State<ExpandableBilibiliContent> {
  /// 全屏模式的透明度 (0.05-1.0 映射到 0.0-1.0)
  double get fullScreenOpacity => 
      ((widget.percentage - 0.05).clamp(0.0, 0.95) / 0.95).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // percentage < 0.05 时完全不可见（收起状态）
    if (widget.percentage < 0.05) {
      return const SizedBox.shrink();
    }
    
    return WillPopScope(
      onWillPop: () async {
        // 如果不是完全收起，拦截返回键并收起容器
        if (widget.percentage > 0.05 && widget.onRequestClose != null) {
          widget.onRequestClose!();
          return false;
        }
        return true;
      },
      child: Container(
        color: isDark
            ? ThemeUtils.backgroundColor(context).withOpacity(fullScreenOpacity)
            : const Color(0xFFF2F2F7).withOpacity(fullScreenOpacity),
        child: Opacity(
          opacity: fullScreenOpacity,
          child: _buildFullScreenMode(context),
        ),
      ),
    );
  }

  /// 构建全屏模式 UI（收藏夹页面）
  Widget _buildFullScreenMode(BuildContext context) {
    return const BilibiliFavoritesPage();
  }
}
