import 'package:flutter/material.dart';
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

  /// 背景（Material + 分割线）透明度。
  ///
  /// - null: 使用 [opacity]（保持现有行为）。
  /// - 0~1: 仅背景淡入淡出，内容可保持不透明。
  final double? backgroundOpacity;

  /// 内容（返回/标题/按钮/bottom）透明度。
  ///
  /// - null: 使用 [opacity]（保持现有行为）。
  /// - 0~1: 可实现“背景透明但按钮可见”的效果。
  final double? contentOpacity;

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
    this.backgroundOpacity,
    this.contentOpacity,
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
    double? backgroundOpacity,
    double? contentOpacity,
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
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      contentOpacity: contentOpacity ?? this.contentOpacity,
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
      backgroundOpacity: 0.0,
      contentOpacity: 0.0,
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

  // 当前主页面（tab）允许写入顶栏的 source。
  // 用于防止 IndexedStack 中后台页面的滚动/回调抢写顶栏，造成“随机消失/错乱”。
  String? _activeBaseSource;

  bool _notifyScheduled = false;

  GlobalTopBarStyle get style => _style;

  void setActiveBaseSource(String? source) {
    _activeBaseSource = source;
  }

  void _notifyListenersSafely() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  void set(GlobalTopBarStyle style) {
    // 顶栏栈占用（push 进入详情页）时：禁止其它来源抢写。
    if (_stack.isNotEmpty && style.source != _style.source) return;

    // 主页面（tab）场景：仅允许当前激活页面写入。
    if (_stack.isEmpty &&
        _activeBaseSource != null &&
        style.source != _activeBaseSource) {
      return;
    }

    _style = style;
    _notifyListenersSafely();
  }

  void hide() {
    // 顶栏被某个页面 push() 占用时，不允许外部直接清空栈并隐藏，否则 pop() 无法恢复。
    if (_stack.isNotEmpty) return;
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
        final contentOpacity = (style.contentOpacity ?? style.opacity)
            .clamp(0.0, 1.0);
        final backgroundOpacity = (style.backgroundOpacity ?? style.opacity)
            .clamp(0.0, 1.0);

        if (contentOpacity <= 0.0 && style.showDivider == false) {
          return const SizedBox.shrink();
        }

        final topPadding = MediaQuery.of(context).padding.top;
        final backgroundColor = ThemeUtils.backgroundColor(context)
            .withValues(alpha: backgroundOpacity);
        final dividerColor = const Color(0xFFD3D3D3)
            .withValues(alpha: backgroundOpacity);

        return Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            ignoring: contentOpacity < 0.05,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true,
                    child: Material(color: backgroundColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: contentOpacity,
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
                        ],
                      ),
                    ),
                    if (style.showDivider)
                      Divider(
                        height: 1,
                        color: dividerColor,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
