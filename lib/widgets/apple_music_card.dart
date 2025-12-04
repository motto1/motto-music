import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'animated_widgets.dart';
import 'dart:ui';

/// Apple Music 风格的卡片组件（液态玻璃效果）
class AppleMusicCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? coverUrl;
  final int? itemCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAuthorTap; // 新增：作者点击回调
  final Color? accentColor;
  final EdgeInsetsGeometry? margin;
  final Widget? trailing;

  const AppleMusicCard({
    super.key,
    required this.title,
    this.subtitle,
    this.coverUrl,
    this.itemCount,
    this.onTap,
    this.onLongPress,
    this.onAuthorTap,
    this.accentColor,
    this.margin,
    this.trailing,
  });

  @override
  State<AppleMusicCard> createState() => _AppleMusicCardState();
}

class _AppleMusicCardState extends State<AppleMusicCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          margin: widget.margin ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            // 优化发光效果，避免滚动时视觉变深
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? (widget.accentColor ?? Colors.blue).withOpacity(0.12)
                    : (widget.accentColor ?? Colors.blue).withOpacity(0.2),
                blurRadius: isDark ? 16 : 18,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
              if (!isDark) // 浅色模式柔和的扩散阴影
                BoxShadow(
                  color: (widget.accentColor ?? Colors.blue).withOpacity(0.06),
                  blurRadius: 20,
                  spreadRadius: -4, // 收缩扩散范围，避免叠加
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), // 减小模糊强度
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 102, // 固定最小高度：70(封面) + 16(上下padding)
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1) // 增加不透明度
                      : Colors.white.withOpacity(0.85), // 增加不透明度
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.15)
                        : Colors.white.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    // 封面（使用淡阴影景深）
                    _buildCover(context),
                    const SizedBox(width: 16),

                    // 信息
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: widget.onAuthorTap,
                                child: Text(
                                  widget.subtitle!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.black.withOpacity(0.5),
                                    decoration: widget.onAuthorTap != null
                                        ? TextDecoration.underline
                                        : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (widget.itemCount != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${widget.itemCount} 首歌曲',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.4)
                                      : Colors.black.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // 箭头
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: widget.trailing ??
                          Icon(
                            Icons.chevron_right,
                            color: isDark
                                ? Colors.white.withOpacity(0.3)
                                : Colors.black.withOpacity(0.3),
                            size: 24,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 使用淡阴影景深效果
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: widget.accentColor ?? (isDark
            ? const Color(0xFF3A3A3C)
            : const Color(0xFFFFFFFF)),
        borderRadius: BorderRadius.circular(8),
        // 淡景深阴影
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: widget.coverUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: widget.coverUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: isDark
                      ? const Color(0xFF3A3A3C)
                      : const Color(0xFFFFFFFF),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Icon(
                  Icons.folder_outlined,
                  size: 32,
                  color: isDark
                      ? Colors.white.withOpacity(0.3)
                      : Colors.black.withOpacity(0.3),
                ),
              ),
            )
          : Icon(
              Icons.folder_outlined,
              size: 32,
              color: isDark
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.3),
            ),
    );
  }
}
