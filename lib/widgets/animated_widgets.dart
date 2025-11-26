import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 装饰动画组件 - 平滑过渡背景、边框、阴影
class AnimatedDecoration extends ImplicitlyAnimatedWidget {
  final Widget? child;
  final Decoration? decoration;

  const AnimatedDecoration({
    super.key,
    required this.decoration,
    this.child,
    super.curve,
    required super.duration,
  });

  @override
  AnimatedWidgetBaseState<AnimatedDecoration> createState() => _AnimatedDecorationState();
}

class _AnimatedDecorationState extends AnimatedWidgetBaseState<AnimatedDecoration> {
  DecorationTween? _decoration;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _decoration = visitor(_decoration, widget.decoration, 
      (dynamic value) => DecorationTween(begin: value as Decoration)) as DecorationTween?;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _decoration?.evaluate(animation) ?? const BoxDecoration(),
      child: widget.child,
    );
  }
}

/// 尺寸动画组件
class AnimatedSizedBox extends ImplicitlyAnimatedWidget {
  final Widget? child;
  final double? width;
  final double? height;

  const AnimatedSizedBox({
    super.key,
    this.width,
    this.height,
    this.child,
    super.curve,
    required super.duration,
  });

  @override
  AnimatedWidgetBaseState<AnimatedSizedBox> createState() => _AnimatedSizedBoxState();
}

class _AnimatedSizedBoxState extends AnimatedWidgetBaseState<AnimatedSizedBox> {
  Tween<double?>? _width;
  Tween<double?>? _height;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _width = visitor(_width, widget.width, 
      (dynamic value) => Tween<double?>(begin: value as double?)) as Tween<double?>?;
    _height = visitor(_height, widget.height, 
      (dynamic value) => Tween<double?>(begin: value as double?)) as Tween<double?>?;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width?.evaluate(animation),
      height: _height?.evaluate(animation),
      child: widget.child,
    );
  }
}

/// 颜色动画组件
class AnimatedColoredBox extends ImplicitlyAnimatedWidget {
  final Widget? child;
  final Color? color;

  const AnimatedColoredBox({
    super.key,
    required this.color,
    this.child,
    super.curve,
    required super.duration,
  });

  @override
  AnimatedWidgetBaseState<AnimatedColoredBox> createState() => _AnimatedColoredBoxState();
}

class _AnimatedColoredBoxState extends AnimatedWidgetBaseState<AnimatedColoredBox> {
  ColorTween? _color;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _color = visitor(_color, widget.color, 
      (dynamic value) => ColorTween(begin: value as Color)) as ColorTween?;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _color?.evaluate(animation) ?? Colors.transparent,
      child: widget.child,
    );
  }
}
