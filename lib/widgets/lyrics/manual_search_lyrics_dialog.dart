import 'package:flutter/material.dart';
import 'package:motto_music/models/lyrics/lyric_models.dart';
import 'package:motto_music/services/lyrics/lyric_service.dart';
import 'package:motto_music/utils/lyric_parser.dart';

/// 手动搜索歌词对话框
class ManualSearchLyricsDialog extends StatefulWidget {
  final String uniqueKey;
  final String initialQuery;
  final Function(ParsedLrc)? onLyricSelected;

  const ManualSearchLyricsDialog({
    Key? key,
    required this.uniqueKey,
    required this.initialQuery,
    this.onLyricSelected,
  }) : super(key: key);

  @override
  State<ManualSearchLyricsDialog> createState() => _ManualSearchLyricsDialogState();
}

class _ManualSearchLyricsDialogState extends State<ManualSearchLyricsDialog> {
  late TextEditingController _searchController;
  List<LyricSearchResult>? _searchResults;
  bool _isSearching = false;
  bool _isFetching = false;
  String? _errorMessage;

  static const Map<String, String> _sourceMap = {
    'netease': '网易云',
  };

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await lyricService.manualSearchLyrics(keyword: query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '搜索失败: $e';
        _isSearching = false;
      });
    }
  }

  Future<void> _selectLyric(LyricSearchResult item) async {
    setState(() {
      _isFetching = true;
      _errorMessage = null;
    });

    try {
      final lyrics = await lyricService.fetchLyrics(
        item: item,
        uniqueKey: widget.uniqueKey,
      );

      if (widget.onLyricSelected != null) {
        widget.onLyricSelected!(lyrics);
      }

      if (mounted) {
        Navigator.of(context).pop(lyrics);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '获取歌词失败: $e';
        _isFetching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('手动搜索歌词'),
      content: SizedBox(
        width: 500,
        height: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 搜索框
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '输入歌曲名',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _performSearch(),
              onChanged: (_) => setState(() {}),
              enabled: !_isFetching,
            ),
            const SizedBox(height: 16),

            // 结果列表
            Expanded(
              child: _buildResultList(),
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
          onPressed: _isFetching ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isFetching || _searchController.text.trim().isEmpty
              ? null
              : _performSearch,
          child: _isSearching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('搜索'),
        ),
      ],
    );
  }

  Widget _buildResultList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults == null) {
      return const Center(
        child: Text('请修改搜索关键词并点击搜索'),
      );
    }

    if (_searchResults!.isEmpty) {
      return const Center(
        child: Text('没有找到匹配的歌词'),
      );
    }

    return ListView.builder(
      itemCount: _searchResults!.length,
      itemBuilder: (context, index) {
        final item = _searchResults![index];
        return _SearchResultItem(
          item: item,
          onTap: () => _selectLyric(item),
          enabled: !_isFetching,
        );
      },
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final LyricSearchResult item;
  final VoidCallback onTap;
  final bool enabled;

  const _SearchResultItem({
    required this.item,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.title),
      subtitle: Text(
        '${item.artist} - ${LyricParser.formatDuration(Duration(seconds: item.duration.toInt()))} - ${{
          'netease': '网易云',
        }[item.source] ?? item.source}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: enabled ? onTap : null,
      enabled: enabled,
    );
  }
}
