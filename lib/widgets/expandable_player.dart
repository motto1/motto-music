import 'package:flutter/material.dart';

/// Apple Music 风格的可展开播放器容器
/// 
/// 基于 Namida UI 的动画架构，实现从迷你播放条到全屏播放器的流畅过渡
/// 
/// 核心特性：
/// - 支持拖拽手势交互
/// - 连续的高度动画（minHeight → maxHeight）
/// - 通过 percentage 参数控制 UI 层级显示
/// - Apple Music 风格的动画曲线和时长
class ExpandablePlayer extends StatefulWidget {
  /// 最小高度（迷你播放器模式）
  final double minHeight;
  
  /// 最大高度（全屏播放器模式）
  final double maxHeight;
  
  /// UI 构建器，接收当前高度和展开百分比
  /// 
  /// [height]: 当前容器高度
  /// [percentage]: 展开百分比 (0.0 = 迷你模式, 1.0 = 全屏模式)
  final Widget Function(double height, double percentage) builder;
  
  /// 背景颜色
  final Color bgColor;
  
  /// 高度变化回调
  final void Function(double percentage)? onHeightChange;
  
  /// 动画时长（默认 600ms，Apple Music 风格）
  final Duration duration;
  
  /// 动画曲线（默认 easeOutExpo，流畅自然）
  final Curve curve;

  const ExpandablePlayer({
    super.key,
    required this.minHeight,
    required this.maxHeight,
    required this.builder,
    required this.bgColor,
    this.onHeightChange,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutExpo,
  });

  @override
  State<ExpandablePlayer> createState() => ExpandablePlayerState();
}

class ExpandablePlayerState extends State<ExpandablePlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  double _dragHeight = 0;
  
  // 水平侧滑状态
  double _horizontalDragStart = 0;
  double _initialPercentage = 0;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: Duration.zero,
      lowerBound: 0,
      upperBound: 1,
      value: widget.minHeight / widget.maxHeight,
    );

    _dragHeight = widget.minHeight;

    // 监听高度变化，通知外部
    if (widget.onHeightChange != null) {
      controller.addListener(() {
        widget.onHeightChange!(percentage);
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// 当前控制器对应的实际高度
  double get controllerHeight => controller.value * widget.maxHeight;
  
  /// 展开百分比 (0.0 = 迷你, 1.0 = 全屏)
  double get percentage =>
      (controllerHeight - widget.minHeight) / (widget.maxHeight - widget.minHeight);

  /// 更新高度（内部方法）
  TickerFuture _updateHeight(double height, {Duration? duration}) {
    _dragHeight = height.clamp(widget.minHeight, widget.maxHeight);
    return controller.animateTo(
      _dragHeight / widget.maxHeight,
      duration: duration,
      curve: widget.curve,
    );
  }

  /// 动画到指定状态（公开方法，供外部调用）
  /// 
  /// [toExpanded]: true = 展开到全屏, false = 收起到迷你模式
  /// [dur]: 自定义动画时长，默认使用 widget.duration
  void animateToState(bool toExpanded, {Duration? dur}) {
    _updateHeight(
      toExpanded ? widget.maxHeight : widget.minHeight,
      duration: dur ?? widget.duration,
    );
  }

  /// 处理垂直拖拽更新
  void onVerticalDragUpdate(double dy) {
    _dragHeight -= dy; // 向上拖动减小 dy，需要增加高度，所以用减法
    _updateHeight(_dragHeight, duration: Duration.zero);
  }

  /// 处理垂直拖拽结束（智能吸附）
  void onVerticalDragEnd(double velocity) {
    bool shouldSnapToMax;
    
    // 快速滑动判定（根据速度）
    if (velocity > 200) {
      // 快速向下滑动 → 收起
      shouldSnapToMax = false;
    } else if (velocity < -200) {
      // 快速向上滑动 → 展开
      shouldSnapToMax = true;
    } else {
      // 慢速拖动 → 根据位置判定（超过 40% 则展开）
      shouldSnapToMax = percentage > 0.4;
    }
    
    animateToState(shouldSnapToMax);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            // 迷你模式下点击展开
            onTap: _dragHeight == widget.minHeight 
                ? () => animateToState(true) 
                : null,
            // 垂直拖拽手势
            onVerticalDragUpdate: (details) => onVerticalDragUpdate(details.delta.dy),
            onVerticalDragEnd: (details) =>
                onVerticalDragEnd(details.velocity.pixelsPerSecond.dy),
            // 🔧 已移除水平侧滑手势
            child: Material(
              clipBehavior: Clip.hardEdge,
              type: MaterialType.transparency,
              child: SizedBox(
                height: controllerHeight,
                child: ColoredBox(
                  color: widget.bgColor,
                  child: widget.builder(controllerHeight, percentage),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
