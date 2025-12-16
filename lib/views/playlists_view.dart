import 'package:flutter/material.dart';
import 'package:motto_music/widgets/page_header.dart';
import 'dart:async';
import '../database/database.dart';
import '../services/music_import_service.dart';
import '../services/player_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/show_aware_page.dart';
import '../widgets/music_list_header.dart';
import '../widgets/music_list_view.dart';

class PlaylistsView extends StatefulWidget {
  const PlaylistsView({super.key});

  @override
  State<PlaylistsView> createState() => PlaylistsViewState();
}

class PlaylistsViewState extends State<PlaylistsView> with ShowAwarePage {
  bool _isScrolling = false;
  Timer? _scrollTimer;
  final ScrollController _scrollController = ScrollController();
  late MusicDatabase database = MusicDatabase.database;
  late MusicImportService importService;

  @override
  void onPageShow() {
    // 页面显示时不需要手动加载，Consumer会自动更新
  }

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (!_isScrolling &&
          _scrollController.position.pixels !=
              _scrollController.position.minScrollExtent) {
        setState(() {
          _isScrolling = true;
        });
      }

      // 重置之前的定时器
      _scrollTimer?.cancel();

      // 设置新的定时器
      _scrollTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _isScrolling = false;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        return ValueListenableBuilder<List<Song>>(
          valueListenable: playerProvider.playlistNotifier,
          builder: (context, songs, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                  16.0, 16.0, 16.0, 0), // 左上右16，底部0
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: '',
                    songs: songs,
                    showImport: false,
                    showSearch: false,
                  ),
                  const SizedBox(height: 24),
                  MusicListHeader(
                    songs: songs,
                    allowReorder: false, // 播放列表页面不允许重排列
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: MusicListView(
                      songs: songs,
                      scrollController: _scrollController,
                      playerProvider: playerProvider,
                      showCheckbox: false, // 播放列表页面不显示复选框
                      checkedIds: const [],
                      onSongDeleted: () {
                        // 删除后会自动触发 notifyListeners，ValueListenableBuilder 会自动更新
                      },
                      onSongUpdated: (_, __) {
                        // 更新后会自动触发 notifyListeners，ValueListenableBuilder 会自动更新
                      },
                      onSongPlay: (song, playlist, index) {
                        playerProvider.playSong(
                          song,
                          playlist: playlist,
                          index: index,
                        );
                      },
                      onCheckboxChanged: (songId, isChecked) {
                        // 不使用复选框
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class LibraryHeader extends StatefulWidget {
  final List<Song> songs;

  const LibraryHeader({super.key, required this.songs});

  @override
  State<LibraryHeader> createState() => _LibraryHeaderState();
}

class _LibraryHeaderState extends State<LibraryHeader> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '播放列表',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 16),
        Text('共${widget.songs.length}首音乐在播放列表'),
        const Spacer(),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
