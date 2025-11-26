import 'package:flutter/material.dart';

/// 页面切换动画 - Namida风格
/// 前进时从右往左滑(slideLeft),返回时从左往右滑(slideRight)
class NamidaPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final PageTransitionType type;

  NamidaPageRoute({
    required this.page,
    this.type = PageTransitionType.slideLeft,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _buildTransition(type, animation, secondaryAnimation, child);
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );

  static Widget _buildTransition(
    PageTransitionType type,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    switch (type) {
      case PageTransitionType.slideLeft:
        // 前进动画: 从右往左滑入
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );

      case PageTransitionType.slideRight:
        // 返回动画: 从左往右滑入
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );

      case PageTransitionType.slideUp:
        // 先慢后快的动画曲线
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeIn,
        );

        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, child) {
            final progress = curvedAnimation.value;
            // 圆角从 20 到 0
            final borderRadius = 20.0 * (1 - progress);
            // 边距从 16 到 0
            final margin = 16.0 * (1 - progress);

            return Padding(
              padding: EdgeInsets.only(
                left: margin,
                right: margin,
                top: margin,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(borderRadius),
                ),
                child: Transform.translate(
                  offset: Offset(0, MediaQuery.of(context).size.height * (1 - progress)),
                  child: child,
                ),
              ),
            );
          },
          child: child,
        );

      case PageTransitionType.fade:
        return FadeTransition(
          opacity: animation,
          child: child,
        );

      case PageTransitionType.scale:
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );

      case PageTransitionType.rotation:
        return RotationTransition(
          turns: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
    }
  }
}

enum PageTransitionType {
  slideLeft,   // 前进: 从右往左
  slideRight,  // 返回: 从左往右
  slideUp,
  fade,
  scale,
  rotation,
}

/// Hero动画包装器
class NamidaHero extends StatelessWidget {
  final String tag;
  final Widget child;

  const NamidaHero({
    super.key,
    required this.tag,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }
}
