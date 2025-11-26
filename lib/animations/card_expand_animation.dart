import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'dart:ui';

/// iOS标准动画曲线 - 精确匹配 iOS 系统动画
class iOSCurves {
  // iOS 标准弹簧动画参数 - 更流畅的弹簧效果
  static const SpringDescription spring = SpringDescription(
    mass: 0.8,
    stiffness: 380.0,
    damping: 32.0,
  );
  
  // iOS App 打开的精确曲线 - Apple Music 风格
  static const Curve appOpen = Cubic(0.2, 0.0, 0.0, 1.0);
  
  // iOS 标准 easeInOut
  static const Curve easeInOut = Cubic(0.42, 0.0, 0.58, 1.0);
  
  // iOS 快速淡出 - 更自然的淡出
  static const Curve fadeOut = Cubic(0.36, 0.0, 0.66, -0.56);
  
  // 模糊过渡曲线
  static const Curve blurTransition = Cubic(0.25, 0.46, 0.45, 0.94);
}

/// 卡片放大动画管理器
class CardExpandAnimationManager {
  static void playAndNavigate({
    required BuildContext context,
    required GlobalKey cardKey,
    required VoidCallback onNavigate,
    required Color targetPageBackgroundColor,
    required List<Color> cardGradientColors,
    double cardBorderRadius = 20.0,
    Duration? duration,
  }) {
    final cardRect = _getWidgetGlobalRect(cardKey);
    
    if (cardRect == null) {
      onNavigate();
      return;
    }

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _CardExpandAnimationWidget(
        cardRect: cardRect,
        cardBorderRadius: cardBorderRadius,
        targetBackgroundColor: targetPageBackgroundColor,
        cardGradientColors: cardGradientColors,
        duration: duration ?? const Duration(milliseconds: 450),
        onNavigate: onNavigate,
        onComplete: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }

  static Rect? _getWidgetGlobalRect(GlobalKey key) {
    final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final position = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(position.dx, position.dy, renderBox.size.width, renderBox.size.height);
  }
}

class _CardExpandAnimationWidget extends StatefulWidget {
  final Rect cardRect;
  final double cardBorderRadius;
  final Color targetBackgroundColor;
  final List<Color> cardGradientColors;
  final Duration duration;
  final VoidCallback onNavigate;
  final VoidCallback onComplete;

  const _CardExpandAnimationWidget({
    required this.cardRect,
    required this.cardBorderRadius,
    required this.targetBackgroundColor,
    required this.cardGradientColors,
    required this.duration,
    required this.onNavigate,
    required this.onComplete,
  });

  @override
  State<_CardExpandAnimationWidget> createState() => _CardExpandAnimationWidgetState();
}

class _CardExpandAnimationWidgetState extends State<_CardExpandAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration);

    // 使用 iOS 标准弹簧曲线 - 丝滑的放大效果
    _scaleAnimation = _controller.drive(
      CurveTween(curve: iOSCurves.appOpen),
    );

    // 颜色淡出 - 与缩放同步
    _fadeAnimation = _controller.drive(
      CurveTween(curve: iOSCurves.fadeOut),
    );

    // 模糊过渡 - 音乐库切换时的模糊效果
    _blurAnimation = _controller.drive(
      CurveTween(curve: iOSCurves.blurTransition),
    );

    // 在动画 20% 时切换页面，确保流畅过渡
    Future.delayed(
      Duration(milliseconds: (widget.duration.inMilliseconds * 0.2).round()),
      widget.onNavigate,
    );

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CardExpandOverlay(
      scaleAnimation: _scaleAnimation,
      fadeAnimation: _fadeAnimation,
      blurAnimation: _blurAnimation,
      cardRect: widget.cardRect,
      cardBorderRadius: widget.cardBorderRadius,
      targetBackgroundColor: widget.targetBackgroundColor,
      cardGradientColors: widget.cardGradientColors,
    );
  }
}

class _CardExpandOverlay extends StatelessWidget {
  final Animation<double> scaleAnimation;
  final Animation<double> fadeAnimation;
  final Animation<double> blurAnimation;
  final Rect cardRect;
  final double cardBorderRadius;
  final Color targetBackgroundColor;
  final List<Color> cardGradientColors;

  const _CardExpandOverlay({
    required this.scaleAnimation,
    required this.fadeAnimation,
    required this.blurAnimation,
    required this.cardRect,
    required this.cardBorderRadius,
    required this.targetBackgroundColor,
    required this.cardGradientColors,
  });

  Widget _buildCardContent(double fadeProgress, bool showGradient) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Color.lerp(Colors.transparent, targetBackgroundColor, fadeProgress)!,
        ),
        if (showGradient)
          Opacity(
            opacity: (1.0 - fadeProgress).clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: cardGradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenRect = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);

    return AnimatedBuilder(
      animation: scaleAnimation,
      builder: (context, child) {
        final currentRect = Rect.lerp(cardRect, screenRect, scaleAnimation.value)!;
        final fadeProgress = fadeAnimation.value;
        final blurProgress = blurAnimation.value;
        
        // 性能优化：提前计算所有值
        final shadowOpacity = 0.12 * (1 - scaleAnimation.value);
        final shadowBlur = 25.0 * (1 - scaleAnimation.value);
        final showShadow = shadowOpacity > 0.005;
        final showGradient = fadeProgress < 0.95;
        
        // 仅在中间阶段使用轻量模糊
        final useBlur = blurProgress > 0.2 && blurProgress < 0.8;
        final blurSigma = useBlur ? 8.0 : 0.0;

        return Stack(
          children: [
            // 背景遮罩层
            if (scaleAnimation.value > 0.02)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withOpacity(0.03 * scaleAnimation.value),
                  ),
                ),
              ),
            
            // 卡片层
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
                            spreadRadius: -3.0 * (1 - scaleAnimation.value),
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
                          child: _buildCardContent(fadeProgress, showGradient),
                        )
                      : _buildCardContent(fadeProgress, showGradient),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
