import 'dart:ui';
import 'package:flutter/material.dart';

/// 模糊容器 - 毛玻璃效果
class BlurContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color? color;
  final BorderRadius? borderRadius;

  const BlurContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.color,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.1),
            borderRadius: borderRadius ?? BorderRadius.circular(12),
          ),
          child: child,
        ),
      ),
    );
  }
}
