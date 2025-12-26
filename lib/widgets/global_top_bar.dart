import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/widgets/compact_page_header.dart';

class GlobalTopBarStyle {
  final String source;
  final String title;
  final bool showBackButton;
  final bool centerTitle;
  final Color? backIconColor;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? bottom;
  final double opacity;
  final double titleOpacity;
  final double titleTranslateY;
  final double translateY;
  final bool showDivider;

  const GlobalTopBarStyle({
    required this.source,
    required this.title,
    required this.showBackButton,
    required this.centerTitle,
    required this.opacity,
    this.titleOpacity = 1.0,
    this.titleTranslateY = 0.0,
    required this.translateY,
    this.backIconColor,
    this.onBack,
    this.trailing,
    this.bottom,
    this.showDivider = true,
  });

  GlobalTopBarStyle copyWith({
    String? source,
    String? title,
    bool? showBackButton,
    bool? centerTitle,
    Color? backIconColor,
    VoidCallback? onBack,
    Widget? trailing,
    Widget? bottom,
    double? opacity,
    double? titleOpacity,
    double? titleTranslateY,
    double? translateY,
    bool? showDivider,
  }) {
    return GlobalTopBarStyle(
      source: source ?? this.source,
      title: title ?? this.title,
      showBackButton: showBackButton ?? this.showBackButton,
      centerTitle: centerTitle ?? this.centerTitle,
      backIconColor: backIconColor ?? this.backIconColor,
      onBack: onBack ?? this.onBack,
      trailing: trailing ?? this.trailing,
      bottom: bottom ?? this.bottom,
      opacity: opacity ?? this.opacity,
      titleOpacity: titleOpacity ?? this.titleOpacity,
      titleTranslateY: titleTranslateY ?? this.titleTranslateY,
      translateY: translateY ?? this.translateY,
      showDivider: showDivider ?? this.showDivider,
    );
  }

  static GlobalTopBarStyle hidden() {
    return const GlobalTopBarStyle(
      source: 'hidden',
      title: '',
      showBackButton: false,
      centerTitle: true,
      opacity: 0.0,
      titleOpacity: 0.0,
      titleTranslateY: 0.0,
      translateY: 0.0,
      showDivider: false,
    );
  }
}

class GlobalTopBarController extends ChangeNotifier {
  static final GlobalTopBarController instance = GlobalTopBarController._();

  GlobalTopBarController._();

  GlobalTopBarStyle _style = GlobalTopBarStyle.hidden();
  final List<GlobalTopBarStyle> _stack = [];
  bool _notifyScheduled = false;

  GlobalTopBarStyle get style => _style;

  void _notifyListenersSafely() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  void set(GlobalTopBarStyle style) {
    _style = style;
    _notifyListenersSafely();
  }

  void hide() {
    _stack.clear();
    set(GlobalTopBarStyle.hidden());
  }

  void push(GlobalTopBarStyle style) {
    _stack.add(_style);
    _style = style;
    _notifyListenersSafely();
  }

  void pop() {
    if (_stack.isEmpty) return;
    _style = _stack.removeLast();
    _notifyListenersSafely();
  }

  void updateHomeProgress(double progress) {
    if (_style.source != 'home') return;
    final barProgress = Curves.easeOutCubic.transform(
      ((progress - 0.08) / 0.72).clamp(0.0, 1.0),
    );
    final titleOpacity = Curves.easeOutCubic.transform(
      ((progress - 0.18) / 0.52).clamp(0.0, 1.0),
    );
    final titleTranslateY = (1.0 - titleOpacity) * 6.0;
    final showDivider = progress > 0.28;
    _style = _style.copyWith(
      opacity: barProgress,
      titleOpacity: titleOpacity,
      titleTranslateY: titleTranslateY,
      showDivider: showDivider,
    );
    _notifyListenersSafely();
  }
}

class GlobalTopBar extends StatelessWidget {
  final GlobalTopBarController controller;
  final double barHeight;

  const GlobalTopBar({
    super.key,
    required this.controller,
    this.barHeight = 52.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final style = controller.style;
        if (style.opacity <= 0.0 && style.showDivider == false) {
          return const SizedBox.shrink();
        }

        final topPadding = MediaQuery.of(context).padding.top;
        final backgroundColor = ThemeUtils.backgroundColor(context);

        return Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            ignoring: style.opacity < 0.05,
            child: Opacity(
              opacity: style.opacity,
              child: Material(
                color: backgroundColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: topPadding),
                    SizedBox(
                      height: barHeight,
                      child: CompactPageHeader(
                        title: style.title,
                        textColor: ThemeUtils.textColor(context),
                        showBackButton: style.showBackButton,
                        centerTitle: style.centerTitle,
                        backIconColor: style.backIconColor,
                        onBack: style.onBack,
                        trailing: style.trailing,
                        titleOpacity: style.titleOpacity,
                        titleTranslateY: style.titleTranslateY,
                      ),
                    ),
                    if (style.bottom != null) style.bottom!,
                    if (style.showDivider)
                      const Divider(
                        height: 1,
                        color: Color(0xFFD3D3D3),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
