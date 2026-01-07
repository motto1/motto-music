import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../database/database.dart';
import '../services/player_provider.dart';
import '../widgets/show_aware_page.dart';
import '../utils/theme_utils.dart';
import '../widgets/music_import_dialog.dart';
import '../widgets/apple_music_song_tile.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/unified_cover_image.dart';
import '../widgets/motto_search_field.dart';
import '../main.dart';

/// 本地音乐库页面
class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => LibraryViewState();
}

class LibraryViewState extends State<LibraryView> with ShowAwarePage {
  static const Color _accentColor = Color(0xFFE84C4C);

  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late final FocusNode _searchFocusNode;

  List<Song> _songs = [];
  List<Song>? _filteredSongs;
  String _searchQuery = '';
  bool _isLoading = false;
  double _collapseProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _searchFocusNode = FocusNode();
    _scrollController.addListener(_onScroll);
    _loadSongs();
  }

  @override
  void onPageShow() {
    _loadSongs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    const collapseThreshold = 40.0;
    final offset = _scrollController.offset.clamp(0.0, collapseThreshold);
    final progress = offset / collapseThreshold;
    if ((progress - _collapseProgress).abs() > 0.01) {
      setState(() => _collapseProgress = progress);
    }
  }

  /// 加载歌曲
  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final songs = await MusicDatabase.database.smartSearch(
        null,
        orderField: 'title',
        orderDirection: 'ASC',
      );
      
      if (mounted) {
        setState(() {
          _songs = songs;
          _filteredSongs = songs;
          _isLoading = false;
        });
        _filterSongs(_searchQuery);
      }
    } catch (e) {
      debugPrint('加载歌曲失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 搜索歌曲
  void _filterSongs(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSongs = _songs;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredSongs = _songs.where((song) {
          return song.title.toLowerCase().contains(lowerQuery) ||
              (song.artist?.toLowerCase().contains(lowerQuery) ?? false) ||
              (song.album?.toLowerCase().contains(lowerQuery) ?? false);
        }).toList();
      }
    });
  }

  /// 清除搜索
  void _clearSearch() {
    _searchController.clear();
    _filterSongs('');
  }

  /// 显示导入选项
  Future<void> _showImportOptions() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildImportBottomSheet(),
    );
  }

  /// 导入文件夹
  Future<void> _importDirectory() async {
    MusicImporter.importFromDirectory(
      context,
      onCompleted: () {
        _loadSongs();
      },
    );
  }

  /// 导入文件
  Future<void> _importFiles() async {
    MusicImporter.importFiles(
      context,
      onCompleted: () {
        _loadSongs();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final bottomSpacerHeight = keyboardVisible ? 16.0 : 120.0;
    const topBarHeight = 52.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // 优先检查全局播放器是否全屏
          final playerKey = GlobalPlayerManager.playerKey;
          final playerState = playerKey?.currentState;
          final percentage = playerState?.percentage ?? -1;

          debugPrint('[LibraryView PopScope] 播放器展开百分比: ${(percentage * 100).toStringAsFixed(1)}%');

          if (playerState != null && percentage >= 0.9) {
            // 播放器全屏，优先缩小播放器
            debugPrint('[LibraryView PopScope] ✓ 拦截返回，缩小播放器');
            playerState.animateToState(false);
            return;
          }

          // 播放器非全屏，正常返回上一页
          debugPrint('[LibraryView PopScope] → 返回上一页');
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? ThemeUtils.backgroundColor(context)
            : const Color(0xFFFFFFFF),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadSongs,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: topPadding + topBarHeight + 1),
                  ),
                  SliverToBoxAdapter(
                    child: _buildLargeTitle(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildSearchField(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildActionButtons(),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 12),
                  ),
                  ..._buildContentSlivers(),
                  SliverToBoxAdapter(
                    child: SizedBox(height: bottomSpacerHeight),
                  ),
                ],
              ),
            ),
            _buildTopBar(topPadding, topBarHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(double topPadding, double topBarHeight) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eased = Curves.easeOutCubic.transform(_collapseProgress);
    final bgOpacity = (eased * 0.95).clamp(0.0, 0.95);
    final titleOpacity = eased.clamp(0.0, 1.0);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20 * eased, sigmaY: 20 * eased),
          child: Container(
            height: topPadding + topBarHeight,
            decoration: BoxDecoration(
              color: isDark
                  ? ThemeUtils.backgroundColor(context).withOpacity(bgOpacity)
                  : Colors.white.withOpacity(bgOpacity),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08 * eased)
                      : Colors.black.withOpacity(0.08 * eased),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: topBarHeight,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '返回',
                    ),
                    Expanded(
                      child: Opacity(
                        opacity: titleOpacity,
                        child: const Text(
                          '本地音乐库',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.autorenew, size: 22),
                      onPressed: _loadSongs,
                      tooltip: '刷新',
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

  Widget _buildLargeTitle() {
    final eased = Curves.easeOutCubic.transform(_collapseProgress);
    final opacity = (1 - eased).clamp(0.0, 1.0);
    final translateY = -14 * eased;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Opacity(
          opacity: opacity,
          child: const Text(
            '本地音乐库',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: MottoSearchField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: '搜索歌曲',
              onChanged: (value) {
                setState(() {});
                _filterSongs(value);
              },
              onSubmitted: (value) => _filterSongs(value),
              onClear: _clearSearch,
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showImportOptions,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: _accentColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.play_arrow_rounded,
              label: '播放',
              onTap: () => _playAllSongs(shuffle: false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.shuffle_rounded,
              label: '随机播放',
              onTap: () => _playAllSongs(shuffle: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F2);
    const textColor = _accentColor;
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _playAllSongs({required bool shuffle}) async {
    final songs = _filteredSongs ?? _songs;
    if (songs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无可播放的歌曲')),
        );
      }
      return;
    }

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (shuffle) {
      final shuffled = List<Song>.from(songs)..shuffle();
      await playerProvider.playSong(
        shuffled.first,
        playlist: shuffled,
        index: 0,
        playNow: true,
      );
    } else {
      await playerProvider.playSong(
        songs.first,
        playlist: songs,
        index: 0,
        playNow: true,
      );
    }
  }

  List<Widget> _buildContentSlivers() {
    if (_isLoading && _songs.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_filteredSongs == null || _filteredSongs!.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyView(),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        sliver: _buildSongsSliverList(),
      ),
    ];
  }

  SliverList _buildSongsSliverList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final song = _filteredSongs![index];
          return _buildSongItem(song, index);
        },
        childCount: _filteredSongs!.length,
      ),
    );
  }

  Widget _buildSongItem(Song song, int index) {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        final isPlaying = playerProvider.currentSong?.id == song.id;
        return AnimatedListItem(
          index: index,
          delay: 33,
          child: Column(
            children: [
              AppleMusicSongTile(
                title: song.title,
                artist: song.artist ?? '未知艺术家',
                coverUrl: song.albumArtPath,
                duration: song.duration != null
                    ? formatDuration(song.duration!)
                    : null,
                isPlaying: isPlaying,
                isFavorite: song.isFavorite,
                onTap: () {
                  playerProvider.playSong(song, playlist: _filteredSongs!, index: index);
                },
                onFavoriteTap: () => _toggleFavorite(song),
                onMoreTap: () => _showSongMenu(song, index),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                indent: 88,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建空视图
  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? '暂无歌曲' : '未找到匹配的歌曲',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '点击右上角 + 按钮导入音乐',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 显示歌曲菜单
  Future<void> _showSongMenu(Song song, int index) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.white.withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.white.withOpacity(0.6),
                  width: 1.5,
                ),
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  // 顶部拖动把手
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  // 歌曲信息
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        UnifiedCoverImage(
                          coverPath: song.albumArtPath,
                          width: 56,
                          height: 56,
                          borderRadius: 8,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                song.artist ?? '未知艺术家',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // 菜单项
                  ListTile(
                    leading: Icon(
                      song.isFavorite ? Icons.favorite : Icons.favorite_border,
                    ),
                    title: Text(song.isFavorite ? '取消喜欢' : '喜欢'),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleFavorite(song);
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.play_circle_outline),
                    title: const Text('插播'),
                    onTap: () {
                      Navigator.pop(context);
                      _playNext(song);
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.playlist_add),
                    title: const Text('添加到播放列表'),
                    onTap: () {
                      Navigator.pop(context);
                      _addToPlaylist(song);
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('从音乐库删除'),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteSong(song);
                    },
                  ),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 切换喜欢状态
  Future<void> _toggleFavorite(Song song) async {
    try {
      final updatedSong = song.copyWith(isFavorite: !song.isFavorite);
      await MusicDatabase.database.updateSong(updatedSong);
      await _loadSongs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(updatedSong.isFavorite ? '已添加到喜欢' : '已取消喜欢')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  /// 插播
  void _playNext(Song song) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.addToPlaylist(song);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已添加到播放列表')),
    );
  }

  /// 添加到播放列表
  void _addToPlaylist(Song song) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.addToPlaylist(song);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已添加到播放列表')),
    );
  }

  /// 删除歌曲
  Future<void> _deleteSong(Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除歌曲'),
        content: Text('确定要从音乐库删除"${song.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await MusicDatabase.database.deleteSong(song.id);
        await _loadSongs();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已删除')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  /// 构建导入选项底部弹窗
  Widget _buildImportBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.35, // 初始高度为屏幕的35%（抬高了默认位置）
      minChildSize: 0.25, // 最小高度为25%
      maxChildSize: 0.95, // 最大可拉到95%
      snap: true, // 启用吸附
      snapSizes: const [0.35, 0.7, 0.95], // 吸附点：初始、中间、最大
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.7)
                    : Colors.white.withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.15)
                        : Colors.white.withOpacity(0.4),
                    width: 1,
                  ),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                children: [
                  // 顶部把手
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Text(
                      '导入音乐',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('从文件夹导入'),
                    onTap: () {
                      Navigator.pop(context);
                      _importDirectory();
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.audio_file_outlined),
                    title: const Text('导入文件'),
                    onTap: () {
                      Navigator.pop(context);
                      _importFiles();
                    },
                  ),

                  SizedBox(height: bottomPadding + 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
