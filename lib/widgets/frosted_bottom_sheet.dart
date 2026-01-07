import 'dart:ui';

import 'package:flutter/material.dart';

/// 毛玻璃底部弹窗组件
///
/// 统一的iOS风格毛玻璃底部弹窗，支持拖动和自适应高度。
/// 使用方式：调用 [FrostedBottomSheet.show] 静态方法。
class FrostedBottomSheet extends StatelessWidget {
  /// 头部信息区域（通常是封面+标题行）
  final Widget? header;

  /// 菜单项列表
  final List<Widget> tiles;

  /// 滚动控制器（由DraggableScrollableSheet提供）
  final ScrollController scrollController;

  const FrostedBottomSheet({
    super.key,
    this.header,
    required this.tiles,
    required this.scrollController,
  });

  /// 显示毛玻璃底部弹窗
  ///
  /// [context] 上下文
  /// [header] 头部信息区域（可选，通常是封面+标题）
  /// [tiles] 菜单项列表
  /// [initialChildSize] 初始高度比例（默认0.35）
  /// [minChildSize] 最小高度比例（默认0.2）
  /// [maxChildSize] 最大高度比例（默认0.7）
  static Future<T?> show<T>({
    required BuildContext context,
    Widget? header,
    required List<Widget> tiles,
    double initialChildSize = 0.35,
    double minChildSize = 0.2,
    double maxChildSize = 0.7,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          builder: (context, scrollController) => FrostedBottomSheet(
            header: header,
            tiles: tiles,
            scrollController: scrollController,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动把手区域（不在ListView内，可直接拖动调整弹窗高度）
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  // 手势会被DraggableScrollableSheet捕获处理
                },
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              // 可滚动内容区域
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // 头部信息
                    if (header != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: header,
                      ),
                    const Divider(height: 1),
                    // 菜单项
                    ...tiles,
                    // 底部安全区域
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 构建标准的头部信息行（封面+标题+副标题）
///
/// 这是一个辅助方法，用于快速构建常见的头部样式。
Widget buildFrostedSheetHeader({
  required BuildContext context,
  required Widget cover,
  required String title,
  String? subtitle,
  int titleMaxLines = 2,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textColor = isDark ? Colors.white : Colors.black;

  return Row(
    children: [
      cover,
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: titleMaxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: textColor.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
