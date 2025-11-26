import 'package:flutter/material.dart';
import 'package:motto_music/models/lyrics/lyric_models.dart';
import 'package:motto_music/services/lyrics/lyric_service.dart';
import 'package:motto_music/utils/lyric_parser.dart';

/// 编辑歌词对话框
class EditLyricsDialog extends StatefulWidget {
  final String uniqueKey;
  final ParsedLrc lyrics;
  final Function(ParsedLrc)? onLyricsSaved;

  const EditLyricsDialog({
    Key? key,
    required this.uniqueKey,
    required this.lyrics,
    this.onLyricsSaved,
  }) : super(key: key);

  @override
  State<EditLyricsDialog> createState() => _EditLyricsDialogState();
}

class _EditLyricsDialogState extends State<EditLyricsDialog> {
  late TextEditingController _originalController;
  late TextEditingController _translatedController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _originalController = TextEditingController(
      text: widget.lyrics.rawOriginalLyrics,
    );
    _translatedController = TextEditingController(
      text: widget.lyrics.rawTranslatedLyrics ?? '',
    );
  }

  @override
  void dispose() {
    _originalController.dispose();
    _translatedController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final original = _originalController.text;
      final translated = _translatedController.text.trim();

      // 解析原始歌词
      final parsedOriginal = LyricParser.parseLrc(original);

      ParsedLrc finalLyrics;

      if (translated.isEmpty) {
        // 没有翻译，直接使用原始歌词
        finalLyrics = parsedOriginal;
      } else {
        // 有翻译，解析并合并
        final parsedTranslated = LyricParser.parseLrc(translated);
        finalLyrics = LyricParser.mergeLrc(parsedOriginal, parsedTranslated);
      }

      // 保留原来的偏移量，标记为手动编辑
      finalLyrics = finalLyrics.copyWith(
        offset: widget.lyrics.offset,
        source: 'manual',
      );

      // 保存到缓存
      await lyricService.saveLyricsToFile(
        lyrics: finalLyrics,
        uniqueKey: widget.uniqueKey,
      );

      if (widget.onLyricsSaved != null) {
        widget.onLyricsSaved!(finalLyrics);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('歌词保存成功')),
        );
        Navigator.of(context).pop(finalLyrics);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '保存歌词失败: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑歌词'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 原始歌词输入框
            Expanded(
              child: TextField(
                controller: _originalController,
                decoration: const InputDecoration(
                  labelText: '原始歌词',
                  hintText: '请输入LRC格式的歌词',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                enabled: !_isSaving,
              ),
            ),

            const SizedBox(height: 16),

            // 翻译歌词输入框（如果原歌词有翻译）
            if (widget.lyrics.rawTranslatedLyrics != null)
              Expanded(
                child: TextField(
                  controller: _translatedController,
                  decoration: const InputDecoration(
                    labelText: '翻译歌词',
                    hintText: '请输入LRC格式的翻译歌词',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  enabled: !_isSaving && _originalController.text.isNotEmpty,
                ),
              ),

            // 使用说明
            const SizedBox(height: 8),
            Text(
              'LRC格式示例：[00:12.50]歌词内容',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),

            // 错误提示
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
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
          onPressed: _isSaving || _originalController.text.trim().isEmpty
              ? null
              : _handleSave,
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
}
