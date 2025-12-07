import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:motto_music/models/lyrics/lyric_models.dart';
import 'package:motto_music/services/lyrics/lyric_service.dart';

/// 歌词偏移量调整底部面板
/// 模仿多选下载歌曲的矩形圆角容器样式
class LyricOffsetPanel extends StatefulWidget {
  final String uniqueKey;
  final ParsedLrc lyrics;
  final Function(ParsedLrc)? onOffsetChanged;
  final Function(double)? onOffsetPreview; // 实时预览回调

  const LyricOffsetPanel({
    Key? key,
    required this.uniqueKey,
    required this.lyrics,
    this.onOffsetChanged,
    this.onOffsetPreview,
  }) : super(key: key);

  @override
  State<LyricOffsetPanel> createState() => _LyricOffsetPanelState();
}

class _LyricOffsetPanelState extends State<LyricOffsetPanel> {
  late double _currentOffset;
  late double _originalOffset;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentOffset = widget.lyrics.offset;
    _originalOffset = widget.lyrics.offset;
  }

  void _onSliderChanged(double value) {
    setState(() {
      _currentOffset = value;
    });
    // 实时预览
    widget.onOffsetPreview?.call(_currentOffset);
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final updatedLyrics = widget.lyrics.copyWith(offset: _currentOffset);

      await lyricService.saveLyricsToFile(
        lyrics: updatedLyrics,
        uniqueKey: widget.uniqueKey,
      );

      widget.onOffsetChanged?.call(updatedLyrics);

      if (mounted) {
        Navigator.of(context).pop(updatedLyrics);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _handleCancel() {
    // 恢复原始偏移量
    widget.onOffsetPreview?.call(_originalOffset);
    Navigator.of(context).pop();
  }

  void _resetOffset() {
    setState(() {
      _currentOffset = 0.0;
    });
    widget.onOffsetPreview?.call(0.0);
  }

  String _formatOffset(double offset) {
    final sign = offset >= 0 ? '+' : '';
    return '$sign${offset.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.45)
                    : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.18)
                      : Colors.black.withOpacity(0.06),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 标题行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '调整歌词偏移',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      // 当前偏移量显示
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatOffset(_currentOffset),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // 提示文字
                  Text(
                    _currentOffset > 0
                        ? '歌词提前显示'
                        : _currentOffset < 0
                            ? '歌词延后显示'
                            : '无偏移',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 滑动条区域
                  Row(
                    children: [
                      Text(
                        '-10s',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: theme.colorScheme.primary,
                            inactiveTrackColor:
                                theme.colorScheme.primary.withOpacity(0.2),
                            thumbColor: theme.colorScheme.primary,
                            overlayColor:
                                theme.colorScheme.primary.withOpacity(0.1),
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                          ),
                          child: Slider(
                            value: _currentOffset.clamp(-10.0, 10.0),
                            min: -10.0,
                            max: 10.0,
                            divisions: 200, // 0.1秒精度
                            onChanged: _onSliderChanged,
                          ),
                        ),
                      ),
                      Text(
                        '+10s',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 操作按钮行
                  Row(
                    children: [
                      // 重置按钮
                      Expanded(
                        child: TextButton(
                          onPressed: _currentOffset != 0 ? _resetOffset : null,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                          ),
                          child: const Text('重置'),
                        ),
                      ),
                      // 取消按钮
                      Expanded(
                        child: TextButton(
                          onPressed: _isSaving ? null : _handleCancel,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                          ),
                          child: const Text('取消'),
                        ),
                      ),
                      // 保存按钮
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSaving ? null : _handleSave,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 显示歌词偏移调整面板
/// 返回更新后的歌词（如果保存了）或 null（如果取消了）
Future<ParsedLrc?> showLyricOffsetPanel({
  required BuildContext context,
  required String uniqueKey,
  required ParsedLrc lyrics,
  Function(ParsedLrc)? onOffsetChanged,
  Function(double)? onOffsetPreview,
}) {
  return showModalBottomSheet<ParsedLrc>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    isScrollControlled: false,
    useRootNavigator: true,
    builder: (context) => LyricOffsetPanel(
      uniqueKey: uniqueKey,
      lyrics: lyrics,
      onOffsetChanged: onOffsetChanged,
      onOffsetPreview: onOffsetPreview,
    ),
  );
}

// 保留旧的 LyricOffsetDialog 类以保持向后兼容
// 但内部实现改为调用新的面板
@Deprecated('Use showLyricOffsetPanel instead')
class LyricOffsetDialog extends StatelessWidget {
  final String uniqueKey;
  final ParsedLrc lyrics;
  final Function(ParsedLrc)? onOffsetChanged;

  const LyricOffsetDialog({
    Key? key,
    required this.uniqueKey,
    required this.lyrics,
    this.onOffsetChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 关闭当前对话框并显示新的面板
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pop();
      showLyricOffsetPanel(
        context: context,
        uniqueKey: uniqueKey,
        lyrics: lyrics,
        onOffsetChanged: onOffsetChanged,
      );
    });

    return const SizedBox.shrink();
  }
}
