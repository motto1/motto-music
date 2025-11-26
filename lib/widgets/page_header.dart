import 'dart:io';

import 'package:flutter/material.dart';
import 'package:motto_music/utils/platform_utils.dart';
import '../utils/theme_utils.dart';
import '../database/database.dart';
import 'dart:ui';

class PageHeader extends StatefulWidget {
  final Future<void> Function(String? keyword)? onSearch;
  final Future<void> Function()? onImportDirectory;
  final Future<void> Function()? onImportFiles;
  final List<Song>? songs;
  final List<Widget>? children;
  final String title;

  /// 是否显示搜索按钮
  final bool showSearch;

  /// 是否显示导入按钮
  final bool showImport;

  /// 是否显示返回按钮
  final bool showBackButton;

  /// 返回按钮点击回调
  final VoidCallback? onBack;

  const PageHeader({
    super.key,
    required this.title,
    this.onSearch,
    this.onImportDirectory,
    this.onImportFiles,
    this.songs,
    this.showSearch = true,
    this.showImport = true,
    this.showBackButton = false,
    this.onBack,
    this.children = const <Widget>[],
  });

  @override
  State<PageHeader> createState() => _PageHeaderState();
}

class _PageHeaderState extends State<PageHeader> {
  bool _showSearchField = false;
  final TextEditingController _searchController = TextEditingController();

  void _onSubmitted(String? value) {
    widget.onSearch?.call(value);
    setState(() {
      // _showSearchField = false;
    });
    // _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 560;
    final isMobile = width < 600;

    return Column(
      children: [
        Row(
          children: [
            // 返回按钮
            if (widget.showBackButton) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: '返回',
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: isMobile ? 24 : 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (widget.songs != null && !_showSearchField)
              Text(
                '共${widget.songs!.length}首',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            const Spacer(),

            /// 搜索框 + 搜索按钮
            if (widget.showSearch) ...[
              if (_showSearchField)
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '请输入搜索关键词',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onSubmitted: _onSubmitted,
                  ),
                ),
              IconButton(
                icon: Icon(
                  _showSearchField ? Icons.close_rounded : Icons.search_rounded,
                ),
                onPressed: () {
                  setState(() {
                    if (_showSearchField) {
                      _searchController.clear();
                      _onSubmitted(null);
                    }
                    _showSearchField = !_showSearchField;
                  });
                },
              ),
            ],

            /// 导入按钮（文件夹 + 文件）
            if (widget.showImport)
              Row(
                children: [
                  if (PlatformUtils.isDesktop) ...[
                    if (isWide)
                      TextButton.icon(
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('选择文件夹'),
                        onPressed: () async {
                          await widget.onImportDirectory?.call();
                        },
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.folder_open_rounded, size: 24),
                        color: ThemeUtils.primaryColor(context),
                        tooltip: '选择文件夹',
                        onPressed: () async {
                          await widget.onImportDirectory?.call();
                        },
                      ),
                    const SizedBox(width: 8)
                  ],
                  if (isWide)
                    TextButton.icon(
                      icon: const Icon(Icons.library_music_rounded),
                      label: const Text('选择音乐文件'),
                      onPressed: () async {
                        await widget.onImportFiles?.call();
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.library_music_rounded),
                      color: ThemeUtils.primaryColor(context),
                      tooltip: '选择音乐文件',
                      onPressed: () async {
                        await widget.onImportFiles?.call();
                      },
                    ),
                ],
              ),
          ],
        ),
        if (widget.children != null) ...widget.children!,
        SizedBox(height: 10),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
