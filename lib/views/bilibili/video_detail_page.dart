import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:motto_music/widgets/apple_music_card.dart';
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
      backgroundColor: ThemeUtils.backgroundColor(context),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _wrapWithoutStretch(
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildBody(),
              ),
            ),
          ),
        ],
      ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIntegratedCard(),
          if (_video!.isMultiPage && _pages != null && _pages!.isNotEmpty)
            _buildPagesSection(),
        ],
      ),
    );
  }
  /// 整合的卡片容器（模仿合集页面样式）
  Widget _buildIntegratedCard() {
    final video = _video!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.blue.withOpacity(0.12)
                : Colors.blue.withOpacity(0.2),
            blurRadius: isDark ? 16 : 18,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.blue.withOpacity(0.06),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.white.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 上半部分：封面 + 标题 + 播放按钮
                  Row(
                    children: [
                      // 封面
                      _buildCover(video.pic, isDark),
                      const SizedBox(width: 16),

                      // 标题和UP主
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              video.title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => _navigateToUploader(),
                              child: Text(
                                video.owner.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.6)
                                      : Colors.black.withOpacity(0.5),
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 播放按钮
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCardAction(
                            icon: Icons.play_arrow_rounded,
                            tooltip: '播放当前',
                            onTap: () => _playPage(_selectedPageIndex),
                          ),
                          const SizedBox(width: 4),
                          _buildCardAction(
                            icon: Icons.playlist_add,
                            tooltip: '添加到音乐库',
                            onTap: _showAddToLibraryDialog,
                          ),
                        ],
                      ),
                    ],
                  ),

                  // 信息标签
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

                  // 简介（如果有）
                  if (video.desc != null && video.desc!.trim().isNotEmpty) ...[ 
                    const SizedBox(height: 12),
                    Text(
                      video.desc!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white.withOpacity(0.7)
                            : Colors.black.withOpacity(0.6),
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建封面
  Widget _buildCover(String? coverUrl, bool isDark) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF3A3A3C)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: coverUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                errorWidget: (context, error, stackTrace) => Icon(
                  Icons.video_library,
                  size: 32,
                  color: isDark
                      ? Colors.white.withOpacity(0.3)
                      : Colors.black.withOpacity(0.3),
                ),
              ),
            )
          : Icon(
              Icons.video_library,
              size: 32,
              color: isDark
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.3),
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Text(
            '视频选集',
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
          final theme = Theme.of(context);
          return AppleMusicCard(
            title: 'P${page.page} ${page.part}',
            subtitle: '时长 ${_formatDuration(page.duration)}',
            coverUrl: _video!.pic,
            margin: EdgeInsets.fromLTRB(16, index == 0 ? 12 : 8, 16, 8),
            accentColor: isSelected ? theme.colorScheme.primary : null,
            trailing: Icon(
              isSelected ? Icons.play_arrow_rounded : Icons.play_circle_outline,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            onTap: () => _playPage(index),
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
