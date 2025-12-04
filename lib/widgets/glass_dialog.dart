import 'dart:ui';
import 'package:flutter/material.dart';

/// 玻璃效果弹窗组件
/// 
/// 特性:
/// - 🔍 弹窗外背景完全清晰（无黑色遮罩、无模糊）
/// - ✨ 弹窗内部内容模糊效果（BackdropFilter 模糊弹窗后面的内容）
/// - 💎 渐变半透明背景 + 半透明边框（玻璃质感）
/// - 🎨 大圆角（28dp）
/// - 🌑 柔和阴影
class GlassDialog extends StatelessWidget {
  /// 弹窗标题
  final String title;
  
  /// 弹窗内容
  final Widget content;
  
  /// 弹窗操作按钮列表
  final List<Widget>? actions;
  
  /// 弹窗宽度
  final double width;
  
  /// 最大高度比例（相对于屏幕高度）
  final double maxHeightRatio;
  
  /// 内容是否可滚动
  final bool scrollable;
  
  /// 圆角大小
  final double borderRadius;
  
  /// 模糊强度
  final double blurSigma;
  
  /// 弹窗边距（用于避免被播放器遮挡）
  final EdgeInsets insetPadding;

  const GlassDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.width = 400,
    this.maxHeightRatio = 0.8,
    this.scrollable = false,
    this.borderRadius = 28,
    this.blurSigma = 30,
    this.insetPadding = const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 120),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: insetPadding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            width: width,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * maxHeightRatio,
            ),
            decoration: _buildDecoration(isDark),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                _buildTitle(isDark),
                
                // 内容
                scrollable
                    ? Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: content,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: content,
                      ),
                
                // 按钮
                if (actions != null) _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建玻璃效果装饰
  BoxDecoration _buildDecoration(bool isDark) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)]
            : [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.7)],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark
            ? Colors.white.withOpacity(0.25)
            : Colors.white.withOpacity(0.8),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
          blurRadius: 20,
          spreadRadius: 0,
        ),
      ],
    );
  }

  /// 构建标题
  Widget _buildTitle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  /// 构建按钮区域
  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: actions!,
      ),
    );
  }
}

/// 显示玻璃效果弹窗的便捷方法
/// 
/// 用法示例:
/// ```dart
/// showGlassDialog(
///   context: context,
///   title: '选择主题',
///   content: Column(children: [...]),
///   actions: [
///     TextButton(onPressed: () => Navigator.pop(context), child: Text('确定')),
///   ],
/// );
/// ```
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget>? actions,
  double width = 400,
  double maxHeightRatio = 0.8,
  bool scrollable = false,
  double borderRadius = 28,
  double blurSigma = 30,
  EdgeInsets insetPadding = const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 120),
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.transparent,  // 关键：背景透明
    builder: (context) => GlassDialog(
      title: title,
      content: content,
      actions: actions,
      width: width,
      maxHeightRatio: maxHeightRatio,
      scrollable: scrollable,
      borderRadius: borderRadius,
      blurSigma: blurSigma,
      insetPadding: insetPadding,
    ),
  );
}
