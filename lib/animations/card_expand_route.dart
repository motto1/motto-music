import 'package:flutter/material.dart';
import 'dart:ui';
import 'page_transitions.dart';

/// 卡片放大转场动画路由
/// 模仿iOS点开App的效果：从一个圆角矩形卡片放大到全屏
class CardExpandRoute extends PageRouteBuilder {
  final Widget page;
  final Rect cardRect; // 卡片在屏幕上的位置和大小
  final double cardBorderRadius; // 卡片的圆角半径
  final Color? backgroundColor; // 背景颜色

  CardExpandRoute({
    required this.page,
    required this.cardRect,
    this.cardBorderRadius = 16.0,
    this.backgroundColor,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 380),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // iOS 精确曲线 - Apple Music 风格
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: const Cubic(0.2, 0.0, 0.0, 1.0), // iOS 标准打开曲线
              reverseCurve: const Cubic(0.32, 0.0, 0.67, 0.0), // iOS 标准关闭曲线
            );

            return _CardExpandTransition(
              animation: curvedAnimation,
              cardRect: cardRect,
              cardBorderRadius: cardBorderRadius,
              backgroundColor: backgroundColor,
              child: child,
            );
          },
        );
}

/// 卡片放大转场动画组件
class _CardExpandTransition extends StatelessWidget {
  final Animation<double> animation;
  final Rect cardRect;
  final double cardBorderRadius;
  final Color? backgroundColor;
  final Widget child;

  const _CardExpandTransition({
    required this.animation,
    required this.cardRect,
    required this.cardBorderRadius,
    this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenRect = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // 性能优化：提前计算所有值
        final currentRect = Rect.lerp(cardRect, screenRect, animation.value)!;
        final shadowOpacity = 0.1 * (1 - animation.value);
        final shadowBlur = 20.0 * (1 - animation.value);
        final showShadow = shadowOpacity > 0.005;
        final showBackground = backgroundColor != null && animation.value > 0.02;
        
        // 仅在中间阶段使用轻量模糊
        final blurProgress = animation.value < 0.5 
            ? animation.value * 2.0 
            : (1.0 - animation.value) * 2.0;
        final useBlur = blurProgress > 0.2 && blurProgress < 0.8;
        final blurSigma = useBlur ? 6.0 : 0.0;

        return Stack(
          children: [
            // 背景遮罩层
            if (showBackground)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: backgroundColor!.withOpacity(animation.value * 0.25),
                  ),
                ),
              ),
            
            // 内容层
            Positioned(
              left: currentRect.left,
              top: currentRect.top,
              width: currentRect.width,
              height: currentRect.height,
              child: Container(
                decoration: showShadow
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(cardBorderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(shadowOpacity),
                            blurRadius: shadowBlur,
                            spreadRadius: -2,
                            offset: Offset(0, shadowBlur * 0.15),
                          ),
                        ],
                      )
                    : BoxDecoration(
                        borderRadius: BorderRadius.circular(cardBorderRadius),
                      ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(cardBorderRadius),
                  child: useBlur
                      ? BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                          child: child,
                        )
                      : child,
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}

/// 获取Widget在屏幕上的全局位置和大小
class CardExpandHelper {
  /// 获取Widget的全局Rect
  static Rect? getWidgetGlobalRect(GlobalKey key) {
    final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  }

  /// 导航到页面并使用卡片放大动画
  static void navigateWithCardExpand({
    required BuildContext context,
    required Widget page,
    required GlobalKey cardKey,
    double cardBorderRadius = 16.0,
    Color? backgroundColor,
  }) {
    final cardRect = getWidgetGlobalRect(cardKey);
    
    if (cardRect == null) {
      // 如果无法获取卡片位置，使用标准滑动导航
      Navigator.of(context).push(
        NamidaPageRoute(
          page: page,
          type: PageTransitionType.slideLeft,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      CardExpandRoute(
        page: page,
        cardRect: cardRect,
        cardBorderRadius: cardBorderRadius,
        backgroundColor: backgroundColor,
      ),
    );
  }
}
