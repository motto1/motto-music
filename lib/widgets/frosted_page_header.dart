import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/theme_utils.dart';

class FrostedPageHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool showBackButton;

  const FrostedPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.bottom,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.blue.withOpacity(0.15)
                : Colors.blue.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.blue.withOpacity(0.08),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? ThemeUtils.backgroundColor(context).withOpacity(0.97)
                  : Colors.white.withOpacity(0.95),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: statusBarHeight),
                
                // AppBar 部分
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      if (showBackButton) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 20),
                          onPressed: onBack ?? () => Navigator.of(context).pop(),
                          tooltip: '返回',
                        ),
                      ] else ...[
                         const SizedBox(width: 20),
                      ],
                      Expanded(
                        child: Row(
                          children: [
                            if (!showBackButton) ...[
                                // 如果没有返回按钮，可能需要一个图标或者只是标题
                                // 这里根据 FavoritesView 的样式，如果有图标可以传进来，目前先简化
                            ],
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (actions != null) ...actions!,
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                
                if (bottom != null) bottom!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
