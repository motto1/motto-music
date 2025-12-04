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
import '../main.dart';

/// 喜欢的音乐页面
class FavoritesView extends StatefulWidget {
  const FavoritesView({super.key});

  @override
  State<FavoritesView> createState() => FavoritesViewState();
}

class FavoritesViewState extends State<FavoritesView> with ShowAwarePage {
  late final TextEditingController _searchController;
  
  List<Song> _songs = [];
  List<Song>? _filteredSongs;
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadSongs();
  }

  @override
  void onPageShow() {
    _loadSongs();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
  }

  /// 清除搜索
  void _clearSearch() {
    _searchController.clear();
    _filterSongs('');
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? ThemeUtils.backgroundColor(context)
            : const Color(0xFFFFFFFF),
        body: CustomScrollView(
          slivers: [
            // 液态玻璃头部容器（AppBar + 搜索框）
            SliverToBoxAdapter(
              child: _buildHeaderWithSearch(),
            ),
            
            // 内容
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 200,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建整合的头部（AppBar + 搜索框）
  Widget _buildHeaderWithSearch() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.blue.withOpacity(0.15)
                : Colors.blue.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.blue.withOpacity(0.08),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? ThemeUtils.backgroundColor(context).withOpacity(0.97)
                  : Colors.white.withOpacity(0.95),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                SizedBox(height: statusBarHeight),
                
                // AppBar 部分
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      // 移除返回按钮
                      const SizedBox(width: 20),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.favorite,
                              color: Colors.red.shade400,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '喜欢的音乐',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                
                // 搜索框部分
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1C1C1E)
                          : const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.search,
                            size: 20,
                            color: isDark
                                ? Colors.white.withOpacity(0.5)
                                : Colors.black.withOpacity(0.5),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (query) => _filterSongs(query),
                              style: TextStyle(
                                fontSize: 17,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              decoration: InputDecoration(
                                hintText: '搜索',
                                hintStyle: TextStyle(
                                  fontSize: 17,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.3),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                isDense: true,
                              ),
                              textAlignVertical: TextAlignVertical.center,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              Icons.cancel,
                              size: 18,
                              color: isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.black.withOpacity(0.5),
                            ),
                            onPressed: _clearSearch,
                            tooltip: '清除',
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    debugPrint('[FavoritesView _buildBody] _isLoading: $_isLoading, _filteredSongs: ${_filteredSongs?.length}');
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_filteredSongs == null || _filteredSongs!.isEmpty) {
      debugPrint('[FavoritesView _buildBody] 显示空视图');
      return _buildEmptyView();
    }
    
    debugPrint('[FavoritesView _buildBody] 显示歌曲列表');
    return _buildSongsList();
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? '暂无喜欢的歌曲' : '未找到匹配的歌曲',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '在歌曲菜单中点击爱心即可添加',
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

  /// 构建歌曲列表
  Widget _buildSongsList() {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 180),
          itemCount: _filteredSongs!.length,
          itemBuilder: (context, index) {
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
                    isFavorite: true, // 喜欢页面中的歌曲都是已喜欢的
                    onTap: () {
                      playerProvider.playSong(song, playlist: _filteredSongs!, index: index);
                    },
                    onFavoriteTap: () => _toggleFavorite(song),
                    onMoreTap: () => _showSongMenu(song),
                  ),
                  // Apple Music 风格分隔线
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
      },
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
}
