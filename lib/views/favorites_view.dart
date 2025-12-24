import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../database/database.dart';
import '../services/player_provider.dart';
import '../widgets/show_aware_page.dart';
import '../utils/theme_utils.dart';
import '../widgets/apple_music_card.dart';
import '../widgets/apple_music_song_tile.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/unified_cover_image.dart';
import '../widgets/motto_search_field.dart';
import '../widgets/global_top_bar.dart';
import '../main.dart';

/// 喜欢的音乐页面
class FavoritesView extends StatefulWidget {
  const FavoritesView({super.key});

  @override
  State<FavoritesView> createState() => FavoritesViewState();
}

class FavoritesViewState extends State<FavoritesView> with ShowAwarePage {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  List<Song> _songs = [];
  List<Song>? _filteredSongs;
  String _searchQuery = '';
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  double _collapseProgress = 0.0;
  static const double _collapseDistance = 64.0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _searchQuery);
    _searchFocusNode = FocusNode();
    _loadSongs();
    _scrollController.addListener(_handleScroll);
    _applyTopBarStyle();
  }

  @override
  void onPageShow() {
    _loadSongs();
    _applyTopBarStyle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyTopBarStyle();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// 加载喜欢的歌曲
  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('[FavoritesView] 开始加载喜欢的歌曲');
      final songs = await MusicDatabase.database.smartSearch(
        null,
        orderField: 'title',
        orderDirection: 'ASC',
        isFavorite: true,
      );
      
      debugPrint('[FavoritesView] 找到 ${songs.length} 首喜欢的歌曲');
      for (var song in songs) {
        debugPrint('  - ${song.title} (isFavorite: ${song.isFavorite})');
      }
      
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
    debugPrint('[FavoritesView] 过滤歌曲，搜索词: "$query"');
    debugPrint('  原始歌曲数: ${_songs.length}');
    
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
      
      debugPrint('  过滤后歌曲数: ${_filteredSongs?.length ?? 0}');
    });
    _applyTopBarStyle();
  }

  /// 清除搜索
  void _clearSearch() {
    _searchController.clear();
    _filterSongs('');
  }

  void _applyTopBarStyle() {
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final progress = (offset / _collapseDistance).clamp(0.0, 1.0);
    if (_collapseProgress != progress && mounted) {
      setState(() {
        _collapseProgress = progress;
      });
    }
    _applyTopBarStyleWithProgress(progress);
  }

  void _applyTopBarStyleWithProgress(double progress) {
    final barProgress = Curves.easeOutCubic.transform(
      ((progress - 0.08) / 0.72).clamp(0.0, 1.0),
    );
    final titleOpacity = Curves.easeOutCubic.transform(
      ((progress - 0.18) / 0.52).clamp(0.0, 1.0),
    );
    GlobalTopBarController.instance.set(
      GlobalTopBarStyle(
        source: 'favorites',
        title: '喜欢的音乐',
        showBackButton: false,
        centerTitle: false,
        opacity: barProgress,
        titleOpacity: titleOpacity,
        titleTranslateY: (1 - titleOpacity) * 6,
        translateY: 0.0,
        showDivider: progress > 0.28,
      ),
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final progress = (_scrollController.offset / _collapseDistance)
        .clamp(0.0, 1.0);
    if ((progress - _collapseProgress).abs() > 0.01) {
      setState(() {
        _collapseProgress = progress;
      });
    }
    _applyTopBarStyleWithProgress(progress);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    const topBarHeight = 52.0;
    final playerProvider = Provider.of<PlayerProvider>(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // 优先检查全局播放器是否全屏
          final playerKey = GlobalPlayerManager.playerKey;
          final playerState = playerKey?.currentState;
          final percentage = playerState?.percentage ?? -1;
          
          debugPrint('[FavoritesView PopScope] 播放器展开百分比: ${(percentage * 100).toStringAsFixed(1)}%');
          
          if (playerState != null && percentage >= 0.9) {
            // 播放器全屏，优先缩小播放器
            debugPrint('[FavoritesView PopScope] ✓ 拦截返回，缩小播放器');
            playerState.animateToState(false);
            return;
          }
          
          // 播放器非全屏，最小化应用（返回桌面）
          debugPrint('[FavoritesView PopScope] → 最小化应用');
          await windowManager.minimize();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? ThemeUtils.backgroundColor(context)
            : const Color(0xFFFFFFFF),
        body: RefreshIndicator(
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
              ..._buildContentSlivers(playerProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: MottoSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: '歌名 / 歌手 / 专辑',
        onChanged: _filterSongs,
        onSubmitted: (_) => _filterSongs(_searchController.text),
        onClear: _clearSearch,
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
            '喜欢的音乐',
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

  List<Widget> _buildContentSlivers(PlayerProvider playerProvider) {
    debugPrint('[FavoritesView] _isLoading: $_isLoading, _filteredSongs: ${_filteredSongs?.length}');
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final bottomSafePadding = keyboardVisible ? 24.0 : 180.0;

    if (_isLoading) {
      return [
        const SliverFillRemaining(
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
        padding: EdgeInsets.only(top: 8, bottom: bottomSafePadding),
        sliver: _buildSongsSliver(playerProvider),
      ),
    ];
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
              Icons.favorite_border,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? '暂无喜欢的歌曲' : '未找到匹配的歌曲',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '在歌曲菜单中点击爱心即可添加',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建歌曲列表
  SliverList _buildSongsSliver(PlayerProvider playerProvider) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final song = _filteredSongs![index];
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
                  isFavorite: true,
                  onTap: () {
                    playerProvider.playSong(song, playlist: _filteredSongs!, index: index);
                  },
                  onFavoriteTap: () => _toggleFavorite(song),
                  onMoreTap: () => _showSongMenu(song),
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
        childCount: _filteredSongs!.length,
      ),
    );
  }

  /// 显示歌曲菜单
  Future<void> _showSongMenu(Song song) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.7,
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

                  // 菜单项 - 取消喜欢
                  ListTile(
                    leading: const Icon(Icons.heart_broken),
                    title: const Text('取消喜欢'),
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

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 切换喜欢状态（取消喜欢）
  Future<void> _toggleFavorite(Song song) async {
    try {
      final updatedSong = song.copyWith(isFavorite: false);
      await MusicDatabase.database.updateSong(updatedSong);
      await _loadSongs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消喜欢')),
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
  Future<void> _playNext(Song song) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    debugPrint(
      '[FavoritesView] ⏭ 插播请求: songId=${song.id}, title=${song.title}, '
      'currentSongId=${playerProvider.currentSong?.id}, '
      'playlistLength=${playerProvider.playlist.length}',
    );
    await playerProvider.insertNext(song);
    if (mounted) {
      debugPrint(
        '[FavoritesView] ⏭ 插播完成: currentSongId=${playerProvider.currentSong?.id}, '
        'playlistLength=${playerProvider.playlist.length}',
      );
    }
  }

  /// 添加到播放列表
  Future<void> _addToPlaylist(Song song) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    debugPrint(
      '[FavoritesView] ➕ 添加到播放列表请求: songId=${song.id}, title=${song.title}, '
      'playlistLength=${playerProvider.playlist.length}',
    );
    await playerProvider.addToPlaylist(song);
    if (mounted) {
      debugPrint(
        '[FavoritesView] ➕ 添加到播放列表完成: playlistLength=${playerProvider.playlist.length}',
      );
    }
  }
}
