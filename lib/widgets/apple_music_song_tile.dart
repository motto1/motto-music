import 'package:flutter/material.dart';
import 'unified_cover_image.dart';

/// Apple Music 风格的歌曲列表项
class AppleMusicSongTile extends StatefulWidget {
  final String title;
  final String? artist;
  final String? coverUrl;
  final String? duration;
  final bool isPlaying;
  final bool isFavorite; // 是否已喜欢
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMoreTap;
  final VoidCallback? onFavoriteTap; // 点击喜欢按钮

  const AppleMusicSongTile({
    super.key,
    required this.title,
    this.artist,
    this.coverUrl,
    this.duration,
    this.isPlaying = false,
    this.isFavorite = false,
    this.onTap,
    this.onLongPress,
    this.onMoreTap,
    this.onFavoriteTap,
  });

  @override
  State<AppleMusicSongTile> createState() => _AppleMusicSongTileState();
}

class _AppleMusicSongTileState extends State<AppleMusicSongTile> {
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _isPressed
            ? (isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05))
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // 封面
            _buildCover(context, isDark),

            const SizedBox(width: 12),

            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: widget.isPlaying
                          ? const Color(0xFFFF3B30) // Apple 红色
                          : (isDark ? Colors.white : Colors.black),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.artist != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.artist!,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black.withOpacity(0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // 时长
            if (widget.duration != null) ...[
              const SizedBox(width: 12),
              Text(
                widget.duration!,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? Colors.white.withOpacity(0.4)
                      : Colors.black.withOpacity(0.4),
                ),
              ),
            ],

            // 喜欢按钮
            if (widget.isFavorite) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onFavoriteTap,
                child: Icon(
                  Icons.favorite,
                  color: Colors.red.shade400,
                  size: 20,
                ),
              ),
            ],

            // 更多按钮
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.more_horiz,
                color: isDark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.black.withOpacity(0.5),
                size: 24,
              ),
              onPressed: widget.onMoreTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context, bool isDark) {
    return Stack(
      children: [
        // 使用统一封面组件
        UnifiedCoverImage(
          coverPath: widget.coverUrl,
          width: 56,
          height: 56,
          borderRadius: 6,
          isDark: isDark,
        ),

        // 播放指示器
        if (widget.isPlaying)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.2), // Apple 红色半透明
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Color(0xFFFF3B30), // Apple 红色
                size: 24,
              ),
            ),
          ),
      ],
    );
  }
}

/// 格式化时长
String formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final secs = seconds % 60;
  return '$minutes:${secs.toString().padLeft(2, '0')}';
}
