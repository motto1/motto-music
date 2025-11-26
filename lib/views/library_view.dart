import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'dart:io';
import '../database/database.dart';
import '../services/player_provider.dart';
import '../widgets/show_aware_page.dart';
import '../utils/theme_utils.dart';
import '../widgets/motto_toast.dart';
import '../widgets/music_import_dialog.dart';
import '../widgets/apple_music_card.dart';
import '../widgets/apple_music_song_tile.dart';
import '../widgets/animated_list_item.dart';
import '../main.dart';

/// 本地音乐库页面
class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => LibraryViewState();
}

class LibraryViewState extends State<LibraryView> with ShowAwarePage {
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? ThemeUtils.backgroundColor(context)
            : const Color(0xFFF2F2F7),
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
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: '返回',
                      ),
                      const Expanded(
                        child: Text(
                          '本地音乐库',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
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
                
                // 搜索框部分
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      // iOS 风格搜索框
                      Expanded(
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
                      
                      // 导入按钮
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showImportOptions,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF3B30),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_filteredSongs == null || _filteredSongs!.isEmpty) {
      return _buildEmptyView();
    }
    
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
                    coverUrl: song.source == 'bilibili'
                        ? song.albumArtPath
                        : (song.albumArtPath != null && File(song.albumArtPath!).existsSync()
                            ? song.albumArtPath
                            : null),
                    isLocalFile: song.source != 'bilibili' && song.albumArtPath != null,
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
                  // Apple Music 风格分隔线
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 88, // 左侧缩进（封面宽度 + padding）
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: song.albumArtPath != null &&
                                 (song.source == 'bilibili' || File(song.albumArtPath!).existsSync())
                              ? (song.source == 'bilibili'
                                  ? CachedNetworkImage(
                                      imageUrl: song.albumArtPath!,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(song.albumArtPath!),
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    ))
                              : Container(
                                  width: 56,
                                  height: 56,
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.music_note),
                                ),
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
