import 'package:flutter/material.dart';

/// 无缝循环滚动文本组件（跑马灯效果）
/// 当文本过长时，会头尾衔接持续向左滚动
class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double scrollSpeed; // 每秒滚动的像素数
  final double spacing; // 文本重复之间的间距（像素）
  final double? maxWidth; // 最大宽度限制

  const ScrollingText({
    Key? key,
    required this.text,
    this.style,
    this.scrollSpeed = 30.0,
    this.spacing = 40.0,
    this.maxWidth,
  }) : super(key: key);

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _needsScrolling = false;
  double _textWidth = 0;
  double _containerWidth = 0;
  double _textHeight = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _needsScrolling = false;
      _controller.stop();
      _controller.reset();
      // 等待下一帧重新测量
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 使用maxWidth限制或容器宽度，取较小值
        _containerWidth = widget.maxWidth != null 
            ? widget.maxWidth!.clamp(0.0, constraints.maxWidth)
            : constraints.maxWidth;

        // 测量文本宽度和高度
        final TextPainter textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        _textWidth = textPainter.width;
        _textHeight = textPainter.height;
        final shouldScroll = _textWidth > _containerWidth;

        // 如果滚动状态发生变化，更新动画
        if (shouldScroll != _needsScrolling) {
          _needsScrolling = shouldScroll;
          
          if (_needsScrolling) {
            // 计算一个完整循环的距离：文本宽度 + 间距
            final cycleDistance = _textWidth + widget.spacing;
            
            // 计算动画时长
            final duration = Duration(
              milliseconds: ((cycleDistance / widget.scrollSpeed) * 1000).toInt(),
            );

            _controller.duration = duration;
            _animation = Tween<double>(
              begin: 0,
              end: -cycleDistance,
            ).animate(CurvedAnimation(
              parent: _controller,
              curve: Curves.linear,
            ));

            // 延迟1秒后开始滚动
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted && _needsScrolling) {
                _controller.repeat(); // 无限重复
              }
            });
          } else {
            _controller.stop();
            _controller.reset();
          }
        }

        if (!_needsScrolling) {
          // 文本不需要滚动，直接显示
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        // 需要滚动：使用Stack避免Row溢出警告
        return SizedBox(
          width: _containerWidth,
          height: _textHeight,
          child: ClipRect(
            clipBehavior: Clip.hardEdge,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  children: [
                    // 第一份文本
                    Positioned(
                      left: _animation.value,
                      top: 0,
                      child: Text(
                        widget.text,
                        style: widget.style,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                    // 第二份文本（用于无缝衔接）
                    Positioned(
                      left: _animation.value + _textWidth + widget.spacing,
                      top: 0,
                      child: Text(
                        widget.text,
                        style: widget.style,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
