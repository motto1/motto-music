import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:motto_music/models/bilibili/video.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/services/player_provider.dart';
import 'package:motto_music/services/cache/page_cache_service.dart';
import 'package:motto_music/services/cache/album_art_cache_service.dart';
import 'package:motto_music/database/database.dart' as db;
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/utils/bilibili_song_utils.dart';
import 'package:motto_music/widgets/show_aware_page.dart';
import 'package:motto_music/widgets/animated_list_item.dart';
import 'package:motto_music/widgets/apple_music_song_tile.dart';
import 'package:motto_music/widgets/unified_cover_image.dart';
import 'package:motto_music/views/bilibili/user_videos_page.dart';

/// Bilibili 视频详情页
/// 
/// 显示视频的详细信息，包括：
/// - 视频封面、标题、作者
/// - 视频时长、发布时间
/// - 视频简介
/// - 分P列表（多P视频）
/// - 添加到播放列表功能
class VideoDetailPage extends StatefulWidget {
  /// 视频BV号
  final String bvid;
  
  /// 可选的视频标题（用于AppBar显示，加载前使用）
  final String? title;

  const VideoDetailPage({
    super.key,
    required this.bvid,
    this.title,
  });

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> with ShowAwarePage {
  late final BilibiliApiService _apiService;
  final PageCacheService _pageCache = PageCacheService();
  
  BilibiliVideo? _video;
  List<BilibiliVideoPage>? _pages;
  bool _isLoading = false;
  String? _errorMessage;
  int _selectedPageIndex = 0;

  @override
  void initState() {
    super.initState();
    
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);
    
    _loadCachedData();
    // 页面初始化时立即加载视频详情
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVideoDetails();
    });
  }

  Future<void> _loadCachedData() async {
    final cachedVideo = await _pageCache.getCachedVideoDetail(widget.bvid);
    final cachedPages = await _pageCache.getCachedVideoPages(widget.bvid);
    if (!mounted || cachedVideo == null) return;

    setState(() {
      _video = cachedVideo;
      if (cachedPages != null && cachedPages.isNotEmpty) {
        _pages = cachedPages;
      }
      _isLoading = false;
    });
  }

  @override
  void onPageShow() {
    // ShowAwarePage 回调，页面显示时刷新数据
    // 如果已经有数据则不重新加载，避免重复请求
    if (_video == null && !_isLoading) {
      _loadVideoDetails();
    }
  }

  /// 加载视频详情
  Future<void> _loadVideoDetails() async {
    setState(() {
      _isLoading = _video == null;
      _errorMessage = null;
    });

    try {
      debugPrint('🎬 开始加载视频详情: ${widget.bvid}');
      
      // 获取视频详情
      final video = await _apiService.getVideoDetails(widget.bvid);
      debugPrint('✅ 视频详情加载成功: ${video.title}');
      
      // 获取分P列表
      final pages = await _apiService.getVideoPages(widget.bvid);
      debugPrint('✅ 分P列表加载成功: ${pages.length} 个分P');
      await _pageCache.cacheVideoDetail(widget.bvid, video);
      await _pageCache.cacheVideoPages(widget.bvid, pages);
      
      if (mounted) {
        setState(() {
          _video = video;
          _pages = pages;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 视频详情加载失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载失败: $e\n\n请检查网络连接或稍后重试';
        });
      }
    }
  }

  /// 格式化时长（秒 -> MM:SS）
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// 格式化发布时间
  String _formatPubdate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 365) {
      return '${diff.inDays ~/ 365}年前';
    } else if (diff.inDays > 30) {
      return '${diff.inDays ~/ 30}个月前';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  /// 播放指定分P
  Future<void> _playPage(int pageIndex) async {
    if (_pages == null || _video == null) return;

    setState(() {
      _selectedPageIndex = pageIndex;
    });

    try {
      debugPrint('🎵 [视频详情页] 准备播放视频分P:');
      debugPrint('  - 视频 BVID: ${_video!.bvid}');
      debugPrint('  - 视频标题: ${_video!.title}');
      debugPrint('  - 分P总数: ${_pages!.length}');
      debugPrint('  - 当前选择索引: $pageIndex');

      // 创建播放列表（参考收藏夹详情页的实现）
      final List<db.Song> playlist = [];

      for (int i = 0; i < _pages!.length; i++) {
        final page = _pages![i];

        // 创建临时 Song 对象
        final tempSong = db.Song(
          id: -(i + 1), // 使用负数避免与数据库 ID 冲突
          title: page.part,
          artist: _video!.owner.name,
          album: _video!.title,
          filePath: buildBilibiliFilePath(
            bvid: _video!.bvid,
            cid: page.cid,
            pageNumber: page.page,
          ),
          lyrics: null,
          bitrate: null,
          sampleRate: null,
          duration: page.duration,
          albumArtPath: _video!.pic,
          dateAdded: DateTime.now(),
          isFavorite: false,
          lastPlayedTime: DateTime.now(),
          playedCount: 0,
          source: 'bilibili',
          bvid: _video!.bvid,
          cid: page.cid,
          pageNumber: page.page,
          bilibiliVideoId: null,
          bilibiliFavoriteId: null,
        );

        playlist.add(tempSong);

        debugPrint('  - P${page.page}: ${page.part} (CID: ${page.cid})');
      }

      if (playlist.isEmpty) {
        throw Exception('播放列表为空');
      }

      final song = playlist[pageIndex];

      debugPrint('  - 当前播放: ${song.title}');
      debugPrint('  - BVID: ${song.bvid}');
      debugPrint('  - CID: ${song.cid}');
      debugPrint('  - PageNumber: ${song.pageNumber}');

      if (mounted) {
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        await playerProvider.playSong(
          song,
          playlist: playlist,
          index: pageIndex,
          shuffle: false,
          playNow: true,
        );

        debugPrint('✅ [视频详情页] 播放列表已设置');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [视频详情页] 播放失败: $e');
      debugPrint('堆栈: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 显示添加到音乐库对话框
  Future<void> _showAddToLibraryDialog() async {
    try {
      final database = db.MusicDatabase.database;
      
      // 获取音乐库中已添加的收藏夹
      final allFavorites = await database.getAllBilibiliFavorites();
      final addedFavorites = allFavorites.where((f) => f.isAddedToLibrary).toList();
      
      if (!mounted) return;
      
      // 显示选择收藏夹对话框（底部弹窗样式）
      final result = await showModalBottomSheet<_FavoriteDialogResult>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _AddToFavoriteDialog(
          favorites: addedFavorites,
          onCreateNew: () => Navigator.pop(context, _FavoriteDialogResult.createNew()),
        ),
      );
      
      if (result == null) return;
      
      if (result.isCreateNew) {
        // 创建新收藏夹
        await _createAndAddToFavorite();
      } else if (result.favorite != null) {
        // 添加到已有收藏夹
        await _addVideoToFavorite(result.favorite!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  /// 创建新收藏夹并添加视频
  Future<void> _createAndAddToFavorite() async {
    final titleController = TextEditingController(text: _video?.title ?? '');
    final introController = TextEditingController(text: _video?.desc ?? '');
    
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CreateFavoriteDialog(
        titleController: titleController,
        introController: introController,
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    final title = titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('收藏夹名称不能为空')),
      );
      return;
    }
    
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在创建收藏夹...')),
        );
      }

      final database = db.MusicDatabase.database;

      // 统一封面来源：优先将视频封面缓存到本地
      String? coverPath = _video?.pic;
      if (coverPath != null && coverPath.isNotEmpty) {
        try {
          final cookieManager = CookieManager();
          final cookie = await cookieManager.getCookieString();
          final localCover = await AlbumArtCacheService.instance.ensureLocalPath(
            coverPath,
            cookie: cookie.isEmpty ? null : cookie,
          );
          if (localCover != null && localCover.isNotEmpty) {
            coverPath = localCover;
          }
        } catch (e) {
          debugPrint('[VideoDetailPage] 缓存封面失败: $e');
        }
      }

      // 创建本地收藏夹（封面优先使用本地缓存路径）
      final favoriteId = await database.into(database.bilibiliFavorites).insert(
        db.BilibiliFavoritesCompanion.insert(
          remoteId: DateTime.now().millisecondsSinceEpoch,
          title: title,
          description: Value(introController.text.trim()),
          coverUrl: Value(coverPath ?? _video!.pic),
          mediaCount: Value(_pages?.length ?? 1),
          syncedAt: DateTime.now(),
          isAddedToLibrary: const Value(true),
          isLocal: const Value(true),
        ),
      );

      // 获取所有分P并添加到收藏夹
      final pages = _pages ?? [];
      for (final page in pages) {
        final filePath = buildBilibiliFilePath(
          bvid: _video!.bvid,
          cid: page.cid,
          pageNumber: page.page,
        );

        // 先检查是否已存在同一音源的歌曲，避免 UNIQUE(file_path) 冲突
        db.Song? existingSong = await database.getSongByPath(filePath);

        if (existingSong == null) {
          existingSong = await database.getSongByBvidAndCid(
            _video!.bvid,
            page.cid,
          );
        }

        if (existingSong != null) {
          final updated = existingSong.copyWith(
            bilibiliFavoriteId: Value(favoriteId),
          );
          await database.updateSong(updated);
        } else {
          await database.into(database.songs).insert(
            db.SongsCompanion.insert(
              title: page.part,
              artist: Value(_video!.owner.name),
              album: Value(_video!.title),
              filePath: filePath,
              duration: Value(page.duration),
              albumArtPath: Value(coverPath ?? _video!.pic),
              source: const Value('bilibili'),
              bvid: Value(_video!.bvid),
              cid: Value(page.cid),
              pageNumber: Value(page.page),
              bilibiliFavoriteId: Value(favoriteId),
            ),
          );
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已创建收藏夹"$title"并添加${pages.length}首歌曲')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    }
  }

  /// 添加视频到收藏夹
  Future<void> _addVideoToFavorite(db.BilibiliFavorite favorite) async {
    try {
      // 调用API添加到B站收藏夹
      await _apiService.addToFavorite(
        mediaId: _video!.aid,
        favoriteId: favorite.remoteId,
      );
      
      if (mounted) {
        final pageInfo = _video!.isMultiPage ? '（含${_pages?.length ?? 1}个分P）' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加到: ${favorite.title}$pageInfo')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  /// 跳转到UP主主页
  void _navigateToUploader() {
    if (_video == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserVideosPage(
          mid: _video!.owner.mid,
          userName: _video!.owner.name,
          userAvatar: _video!.owner.face,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final title = _video?.title ?? widget.title ?? '视频详情';

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
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: '返回',
                      ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _loadVideoDetails,
                        tooltip: '刷新',
                      ),
                      IconButton(
                        icon: const Icon(Icons.playlist_add, size: 22),
                        onPressed: _video != null ? _showAddToLibraryDialog : null,
                        tooltip: '添加到音乐库',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? ThemeUtils.backgroundColor(context)
          : const Color(0xFFFFFFFF),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _video == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _video == null) {
      return _buildErrorView();
    }

    if (_video == null) {
      return const Center(child: Text('未找到视频信息'));
    }

    return _buildVideoContent();
  }

  /// 构建错误视图
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              '加载失败',
              style: TextStyle(fontSize: 18),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadVideoDetails,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = _pages;

    return RefreshIndicator(
      onRefresh: _loadVideoDetails,
      child: Container(
        // 统一的背景色，防止 BackdropFilter 模糊到不同颜色
        color: isDark ? ThemeUtils.backgroundColor(context) : const Color(0xFFFFFFFF),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildVideoHeader(),
            ),
            if (pages != null && pages.length > 1)
              _buildPagesSliverList(pages),
            const SliverPadding(
              padding: EdgeInsets.only(bottom: 180),
            ),
          ],
        ),
      ),
    );
  }

  /// 页面头部（完全复刻收藏夹详情页视觉）
  Widget _buildVideoHeader() {
    if (_video == null) {
      return const SizedBox.shrink();
    }

    final video = _video!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final coverSize = MediaQuery.of(context).size.width * 0.6;
    final pagesCount = _pages?.length ?? 1;

    final statsLine =
        '播放 ${_formatCount(video.view)} · 收藏 ${_formatCount(video.favorite)} · 投币 ${_formatCount(video.coin)} · 点赞 ${_formatCount(video.like)}';

    return Container(
      padding: EdgeInsets.fromLTRB(16, statusBarHeight + 16, 16, 24),
      color:
          isDark ? ThemeUtils.backgroundColor(context) : const Color(0xFFFFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 顶部返回 + 更多操作
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 22,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '返回',
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  size: 22,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: _showVideoPageMenu,
                tooltip: '更多操作',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 大封面（与收藏夹页一致）
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: UnifiedCoverImage(
              coverPath: video.pic,
              width: coverSize,
              height: coverSize,
              borderRadius: 8,
            ),
          ),

          const SizedBox(height: 20),

          // 标题
          Text(
            video.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.2,
              color: isDark ? Colors.white : Colors.black,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.15),
                  offset: const Offset(0, 1),
                  blurRadius: 8,
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // 作者
          GestureDetector(
            onTap: _navigateToUploader,
            child: Text(
              video.owner.name,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? Colors.white.withOpacity(0.6)
                    : Colors.black.withOpacity(0.6),
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 1),
                    blurRadius: 6,
                  ),
                ],
                decoration: TextDecoration.underline,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 8),

          // 统计信息（先按已有数据渲染，后续再补齐映射/接口）
          Text(
            statsLine,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? Colors.white.withOpacity(0.6)
                  : Colors.black.withOpacity(0.6),
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 1),
                  blurRadius: 6,
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          if (pagesCount > 1) ...[
            const SizedBox(height: 8),
            Text(
              '共 $pagesCount 个分P',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? Colors.white.withOpacity(0.55)
                    : Colors.black.withOpacity(0.55),
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          // 播放/添加按钮（与收藏夹页玻璃按钮一致）
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGlassButton(
                onPressed: () => _playPage(_selectedPageIndex),
                icon: Icons.play_arrow,
                label: '播放',
                isPrimary: true,
              ),
              const SizedBox(width: 16),
              _buildGlassButton(
                onPressed: _showAddToLibraryDialog,
                icon: Icons.playlist_add,
                label: '添加',
                isPrimary: false,
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  SliverList _buildPagesSliverList(List<BilibiliVideoPage> pages) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final page = pages[index];
          final isSelected = index == _selectedPageIndex;

          return AnimatedListItem(
            index: index,
            delay: 33,
            child: Column(
              children: [
                AppleMusicSongTile(
                  title: 'P${page.page} ${page.part}',
                  artist: _video?.owner.name,
                  coverUrl: _video?.pic,
                  duration: _formatDuration(page.duration),
                  isPlaying: isSelected,
                  onTap: () => _playPage(index),
                  onMoreTap: () => _showPageMenu(page, index),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 88,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.1),
                ),
              ],
            ),
          );
        },
        childCount: pages.length,
      ),
    );
  }

  void _showPageMenu(BilibiliVideoPage page, int index) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('播放该分P'),
                onTap: () {
                  Navigator.pop(context);
                  _playPage(index);
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  void _showVideoPageMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('刷新'),
                onTap: () {
                  Navigator.pop(context);
                  _loadVideoDetails();
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('添加到音乐库'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToLibraryDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('查看UP主'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToUploader();
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? Colors.red.withOpacity(0.3)
                : (isDark
                    ? Colors.blue.withOpacity(0.15)
                    : Colors.black.withOpacity(0.1)),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              splashColor: Colors.white.withOpacity(0.3),
              highlightColor: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? const Color(0xFFFF3B30).withOpacity(0.9)
                      : (isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.white.withOpacity(0.85)),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isPrimary
                        ? Colors.transparent
                        : (isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.white.withOpacity(0.4)),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isPrimary
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isPrimary
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black),
                      ),
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

  /// 详情头部（复用收藏夹页的列表风格）
  Widget _buildIntegratedCard() {
    final video = _video!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surface = Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context)
        .colorScheme
        .onSurface
        .withOpacity(isDark ? 0.10 : 0.08);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部条目：封面 + 标题 + 作者 + 操作
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildCover(video.pic, isDark),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: _navigateToUploader,
                        child: Text(
                          video.owner.name,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.2,
                            decoration: TextDecoration.underline,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.55),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCardAction(
                      icon: Icons.play_arrow_rounded,
                      tooltip: '播放',
                      onTap: () => _playPage(_selectedPageIndex),
                    ),
                    _buildCardAction(
                      icon: Icons.playlist_add,
                      tooltip: '添加到音乐库',
                      onTap: _showAddToLibraryDialog,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            _buildStatsRow(
              view: video.view,
              favorite: video.favorite,
              coin: video.coin,
              like: video.like,
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _playPage(_selectedPageIndex),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('播放'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE84C4C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showAddToLibraryDialog,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('添加'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip('BV号', video.bvid),
                _buildInfoChip('时长', _formatDuration(video.duration)),
                _buildInfoChip('分P', '${_pages?.length ?? 1} 个'),
                _buildInfoChip('发布', _formatPubdate(video.pubdate)),
              ],
            ),

            if (video.desc != null && video.desc!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                video.desc!,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow({
    required int? view,
    required int? favorite,
    required int? coin,
    required int? like,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            icon: Icons.play_arrow_rounded,
            label: '播放',
            value: view,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            icon: Icons.star_border_rounded,
            label: '收藏',
            value: favorite,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            icon: Icons.monetization_on_outlined,
            label: '投币',
            value: coin,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            icon: Icons.thumb_up_alt_outlined,
            label: '点赞',
            value: like,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int? value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context)
        .colorScheme
        .onSurface
        .withOpacity(isDark ? 0.75 : 0.7);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          '${_formatCount(value)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacity(0.45),
          ),
        ),
      ],
    );
  }

  String _formatCount(int? value) {
    if (value == null) return '--';
    if (value < 0) return '--';
    if (value < 10000) return value.toString();
    if (value < 100000000) {
      final v = value / 10000.0;
      return '${v.toStringAsFixed(v >= 100 ? 0 : 1)}万';
    }
    final v = value / 100000000.0;
    return '${v.toStringAsFixed(v >= 100 ? 0 : 1)}亿';
  }

  /// 构建封面（统一使用 UnifiedCoverImage，保持与收藏夹页一致）
  Widget _buildCover(String? coverUrl, bool isDark) {
    return UnifiedCoverImage(
      coverPath: coverUrl,
      width: 56,
      height: 56,
      borderRadius: 6,
      isDark: isDark,
    );
  }

  /// 构建信息标签
  Widget _buildInfoChip(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.9);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.white.withOpacity(0.25);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPagesSection() {
    final pages = _pages!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Text(
            '分P列表',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...pages.asMap().entries.map((entry) {
          final index = entry.key;
          final page = entry.value;
          final isSelected = index == _selectedPageIndex;

          return Column(
            children: [
              InkWell(
                onTap: () => _playPage(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      UnifiedCoverImage(
                        coverPath: _video!.pic,
                        width: 56,
                        height: 56,
                        borderRadius: 6,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'P${page.page} ${page.part}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '时长 ${_formatDuration(page.duration)}',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.2,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected
                            ? Icons.play_arrow_rounded
                            : Icons.play_circle_outline,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
              ),
              if (index != pages.length - 1)
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 88,
                  color: theme.colorScheme.onSurface.withOpacity(0.1),
                ),
            ],
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCardAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final baseColor = isDark ? Colors.white : Colors.black87;
        final iconColor = onTap == null ? baseColor.withOpacity(0.3) : baseColor;
        return Tooltip(
          message: tooltip,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
          ),
        );
      },
    );
  }

  Widget _wrapWithoutStretch(Widget child) {
    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (notification) {
        notification.disallowIndicator();
        return true;
      },
      child: child,
    );
  }
}

/// 收藏夹对话框返回结果
class _FavoriteDialogResult {
  final db.BilibiliFavorite? favorite;
  final bool isCreateNew;

  _FavoriteDialogResult._({this.favorite, this.isCreateNew = false});

  factory _FavoriteDialogResult.favorite(db.BilibiliFavorite fav) =>
      _FavoriteDialogResult._(favorite: fav);

  factory _FavoriteDialogResult.createNew() =>
      _FavoriteDialogResult._(isCreateNew: true);
}

/// 添加到收藏夹对话框（模仿合集页面的底部弹窗样式）
class _AddToFavoriteDialog extends StatelessWidget {
  final List<db.BilibiliFavorite> favorites;
  final VoidCallback onCreateNew;

  const _AddToFavoriteDialog({
    required this.favorites,
    required this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.white.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark
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
                      color: isDark
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                
                // 标题
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Text(
                    '添加到收藏夹',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                
                // 创建新收藏夹按钮
                ListTile(
                  leading: Icon(
                    Icons.add_circle_outline,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  title: Text(
                    '创建新收藏夹',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: onCreateNew,
                ),
                
                if (favorites.isNotEmpty) ...[ 
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Text(
                      '选择已有收藏夹',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ),
                  ...favorites.map((favorite) => ListTile(
                    leading: Icon(
                      Icons.folder_outlined,
                      color: isDark ? Colors.white.withOpacity(0.8) : Colors.black54,
                    ),
                    title: Text(
                      favorite.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      '${favorite.mediaCount} 个视频',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.6),
                      ),
                    ),
                    onTap: () => Navigator.pop(
                      context,
                      _FavoriteDialogResult.favorite(favorite),
                    ),
                  )),
                ],
                
                // 底部留白
                SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 创建收藏夹对话框（底部弹窗样式）
class _CreateFavoriteDialog extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController introController;

  const _CreateFavoriteDialog({
    required this.titleController,
    required this.introController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.7,
      builder: (context, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.white.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.6),
                width: 1.5,
              ),
            ),
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              children: [
                // 顶部拖动把手
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                
                // 标题
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Text(
                    '创建新收藏夹',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                
                // 收藏夹名称输入框
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: titleController,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      labelText: '收藏夹名称',
                      hintText: '请输入收藏夹名称',
                      labelStyle: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.6),
                      ),
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black.withOpacity(0.3),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.blue : Colors.blue,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 简介输入框
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: introController,
                    maxLines: 3,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      labelText: '简介（可选）',
                      hintText: '请输入收藏夹简介',
                      labelStyle: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.6),
                      ),
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black.withOpacity(0.3),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.blue : Colors.blue,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 按钮
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '取消',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF3B30),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '创建',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
