import 'package:flutter/material.dart';
import 'package:motto_music/models/lyrics/lyric_models.dart';
import 'package:motto_music/services/lyrics/lyric_service.dart';

/// 歌词偏移量调整对话框
class LyricOffsetDialog extends StatefulWidget {
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
  State<LyricOffsetDialog> createState() => _LyricOffsetDialogState();
}

class _LyricOffsetDialogState extends State<LyricOffsetDialog> {
  late double _currentOffset;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentOffset = widget.lyrics.offset;
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedLyrics = widget.lyrics.copyWith(offset: _currentOffset);

      await lyricService.saveLyricsToFile(
        lyrics: updatedLyrics,
        uniqueKey: widget.uniqueKey,
      );

      if (widget.onOffsetChanged != null) {
        widget.onOffsetChanged!(updatedLyrics);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('偏移量已保存')),
        );
        Navigator.of(context).pop(updatedLyrics);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '保存失败: $e';
        _isSaving = false;
      });
    }
  }

  void _resetOffset() {
    setState(() {
      _currentOffset = 0.0;
    });
  }

  String _formatOffset(double offset) {
    final sign = offset >= 0 ? '+' : '';
    return '$sign${offset.toStringAsFixed(2)}秒';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('调整歌词偏移量'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 说明文字
            Text(
              '如果歌词与音乐不同步，可以调整偏移量',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // 当前偏移量显示
            Text(
              _formatOffset(_currentOffset),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentOffset > 0 ? '歌词提前显示' : _currentOffset < 0 ? '歌词延后显示' : '无偏移',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),

            const SizedBox(height: 32),

            // 滑块调整
            Row(
              children: [
                const Text('-5s'),
                Expanded(
                  child: Slider(
                    value: _currentOffset.clamp(-5.0, 5.0),
                    min: -5.0,
                    max: 5.0,
                    divisions: 100,
                    label: _formatOffset(_currentOffset),
                    onChanged: (value) {
                      setState(() {
                        _currentOffset = value;
                      });
                    },
                  ),
                ),
                const Text('+5s'),
              ],
            ),

            const SizedBox(height: 16),

            // 精细调整按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAdjustButton('-0.5s', -0.5),
                _buildAdjustButton('-0.1s', -0.1),
                _buildAdjustButton('+0.1s', 0.1),
                _buildAdjustButton('+0.5s', 0.5),
              ],
            ),

            const SizedBox(height: 16),

            // 重置按钮
            TextButton.icon(
              onPressed: _currentOffset != 0 ? _resetOffset : null,
              icon: const Icon(Icons.restore),
              label: const Text('重置为0'),
            ),

            // 错误提示
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildAdjustButton(String label, double delta) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _currentOffset = (_currentOffset + delta).clamp(-5.0, 5.0);
        });
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(60, 36),
      ),
      child: Text(label),
    );
  }
}
