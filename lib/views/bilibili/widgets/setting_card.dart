import 'package:flutter/material.dart';
import 'dart:ui';

/// 自定义设置卡片组件(液态玻璃效果)
class SettingCard extends StatelessWidget {
  final Widget child;

  const SettingCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.blue.withValues(alpha: 0.12)
                : Colors.blue.withValues(alpha: 0.15),
            blurRadius: isDark ? 12 : 14,
            spreadRadius: -2,
            offset: const Offset(0, 3),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.06),
              blurRadius: 16,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
