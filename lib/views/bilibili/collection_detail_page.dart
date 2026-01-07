import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motto_music/models/bilibili/collection.dart';
import 'package:motto_music/database/database.dart' as db;
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/services/player_provider.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/utils/bilibili_song_utils.dart';
import 'package:motto_music/widgets/show_aware_page.dart';
import 'package:motto_music/main.dart';
import 'dart:ui';
import 'package:drift/drift.dart' as drift;
import 'package:motto_music/services/cache/page_cache_service.dart';
import 'package:motto_music/services/cache/album_art_cache_service.dart';
import 'package:motto_music/widgets/animated_list_item.dart';
import 'package:motto_music/widgets/apple_music_song_tile.dart';
import 'package:motto_music/widgets/unified_cover_image.dart';
import 'package:motto_music/widgets/frosted_bottom_sheet.dart';

/// 合集详情页面（参考视频详情页设计）
class CollectionDetailPage extends StatefulWidget {
  final int collectionId;
  final int? mid;
  final String title;

  const CollectionDetailPage({
    super.key,
    required this.collectionId,
    this.mid,
    required this.title,
  });

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> with ShowAwarePage {
  late final BilibiliApiService _apiService;
  final PageCacheService _pageCache = PageCacheService();

  bool _isLoading = false;
  List<BilibiliCollectionItem>? _videos;
  BilibiliCollection? _collectionInfo;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMore = true;
  int? _mid;
  int _selectedVideoIndex = 0;

  @override
  void initState() {
    super.initState();

    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);
    _mid = widget.mid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVideos();
    });
  }

  @override
  void onPageShow() {
    if (_videos == null && !_isLoading) {
      _loadVideos();
    }
  }

  Future<void> _loadVideos({bool loadMore = false}) async {
    if (_mid == null && !loadMore) {
      setState(() {
        _errorMessage = 'UP主ID未提供，无法加载合集';
        _isLoading = false;
      });
      return;
    }

    if (_isLoading) return;
    if (loadMore && !_hasMore) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final page = loadMore ? _currentPage + 1 : 1;

      final data = await _apiService.getCollectionContents(
        seasonId: widget.collectionId,
        mid: _mid!,
        page: page,
      );

      final meta = data['meta'] as Map<String, dynamic>?;
      final archives = data['archives'] as List<dynamic>? ?? [];
      final page_info = data['page'] as Map<String, dynamic>?;

      if (meta != null && _collectionInfo == null) {
        _collectionInfo = BilibiliCollection.fromJson(meta);
        _mid ??= _collectionInfo!.mid;
      }

      final videos = archives
          .map((item) => BilibiliCollectionItem.fromJson(item as Map<String, dynamic>))
          .toList();

      // 修复 CID：为每个视频获取正确的 CID
      final videosWithCid = await _fixVideoCids(videos);

      if (mounted) {
        setState(() {
          if (loadMore) {
            _videos = [...?_videos, ...videosWithCid];
            _currentPage = page;
          } else {
            _videos = videosWithCid;
            _currentPage = 1;
          }
          final total = page_info?['total'] as int? ?? 0;
          _hasMore = (_videos?.length ?? 0) < total;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 合集内容加载失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// 修复视频 CID（获取第一个分P的 CID）
  Future<List<BilibiliCollectionItem>> _fixVideoCids(List<BilibiliCollectionItem> videos) async {
    final result = <BilibiliCollectionItem>[];
    
    for (final video in videos) {
      // 如果已有 CID，直接使用
      if (video.cid != 0) {
        result.add(video);
        continue;
      }
      
      // 否则获取视频的分P列表
      try {
        final bvid = video.bvid;
        if (bvid.isEmpty) {
          result.add(video);
          continue;
        }
        final pages = await _pageCache.getOrFetchVideoPages(
          bvid,
          () => _apiService.getVideoPages(bvid),
        );
        if (pages.isNotEmpty) {
          final firstPage = pages[0];
          result.add(video.copyWith(
            cid: firstPage.cid,
            duration: firstPage.duration,
          ));
          debugPrint('✓ 修复 CID: ${video.title} -> CID=${firstPage.cid}');
        } else {
          result.add(video);
          debugPrint('✗ 未找到分P: ${video.title}');
        }
      } catch (e) {
        debugPrint('✗ 获取分P失败: ${video.title}, $e');
        result.add(video);
      }
    }
    
    return result;
  }
  Future<void> _playVideo(int index) async {
    if (_videos == null || _videos!.isEmpty) return;

    setState(() {
      _selectedVideoIndex = index;
    });

    try {
      final video = _videos![index];

      debugPrint('🎵 准备播放合集视频:');
      debugPrint('  - 点击的视频: ${video.title}');
      debugPrint('  - 点击的索引: $index');
      debugPrint('  - BVID: ${video.bvid}');
      debugPrint('  - CID: ${video.cid}');
      debugPrint('  - AID: ${video.aid}');

      final List<db.Song> playlist = [];

      final cookieManager = CookieManager();
      final cookie = await cookieManager.getCookieString();

      for (int i = 0; i < _videos!.length; i++) {
        final item = _videos![i];

        String? cachedCover;
        try {
          cachedCover = await AlbumArtCacheService.instance.ensureLocalPath(
            item.cover,
            cookie: cookie.isEmpty ? null : cookie,
          );
        } catch (_) {
          // 降级为使用远程 URL
        }

        final tempSong = db.Song(
          id: -(item.aid),
          title: item.title,
          artist: item.upName,
          album: _collectionInfo?.title ?? '合集',
          filePath: buildBilibiliFilePath(
            bvid: item.bvid,
            cid: item.cid,
          ),
          lyrics: null,
          bitrate: null,
          sampleRate: null,
          duration: item.duration,
          albumArtPath: cachedCover ?? item.cover,
          dateAdded: DateTime.now(),
          isFavorite: false,
          lastPlayedTime: DateTime.now(),
          playedCount: 0,
          source: 'bilibili',
          bvid: item.bvid,
          cid: item.cid,
          pageNumber: null,
          bilibiliVideoId: null,
        );
        playlist.add(tempSong);
      }

      if (playlist.isEmpty) {
        throw Exception('合集为空');
      }

      final clickedSong = playlist[index];

      debugPrint('  - 播放列表长度: ${playlist.length}');
      debugPrint('  - 实际播放歌曲: ${clickedSong.title}');
      debugPrint('  - 实际播放BVID: ${clickedSong.bvid ?? "null"}');
      debugPrint('  - 实际播放CID: ${clickedSong.cid ?? "null"}');
      debugPrint('  - 实际播放索引: $index');
      debugPrint('  - 播放列表前3首: ${playlist.take(3).map((s) => '${s.title}(${s.bvid ?? "null"})').join(", ")}');

      if (mounted) {
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        await playerProvider.playSong(
          clickedSong,
          playlist: playlist,
          index: index,
          shuffle: false,
          playNow: true,
        );
        debugPrint('✅ 播放列表已更新');
      }
    } catch (e) {
      debugPrint('❌ 播放失败: $e');
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

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final title = _collectionInfo?.title ?? widget.title;

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
                        icon: const Icon(Icons.folder_outlined, size: 20),
                        onPressed: _showAddToLibraryDialog,
                        tooltip: '添加到收藏夹',
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _loadVideos,
                        tooltip: '刷新',
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          final playerKey = GlobalPlayerManager.playerKey;
          final playerState = playerKey?.currentState;
          final percentage = playerState?.percentage ?? -1;
          debugPrint('[CollectionDetailPage PopScope] 播放器展开百分比: ${(percentage * 100).toStringAsFixed(1)}%');

          if (playerState != null && percentage >= 0.9) {
            debugPrint('[CollectionDetailPage PopScope] ✓拦截返回，缩小播放器');
            playerState.animateToState(false);
            return;
          }

          debugPrint('[CollectionDetailPage PopScope] → 返回上一页');
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: ThemeUtils.backgroundColor(context),
        body: _wrapWithoutStretch(_buildBody()),
      ),
    );
  }
  Widget _buildBody() {
    if (_isLoading && _videos == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _videos == null) {
      return _buildErrorView();
    }

    if (_videos == null) {
      return const Center(child: Text('未找到合集信息'));
    }

    return _buildCollectionContent();
  }

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
              onPressed: _loadVideos,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final coverSize = MediaQuery.of(context).size.width * 0.6;

    final info = _collectionInfo;
    final title = info?.title ?? widget.title;
    final cover = info?.cover ??
        ((_videos != null && _videos!.isNotEmpty) ? _videos!.first.cover : null);
    final upName = info?.upName.isNotEmpty == true
        ? info!.upName
        : ((_videos != null && _videos!.isNotEmpty) ? _videos!.first.upName : '');
    final pCount = info?.mediaCount ?? (_videos?.length ?? 0);

    final subtitleLine = [
      if (upName.isNotEmpty) upName,
      if (pCount > 0) '${pCount}P',
    ].join(' · ');

    return Container(
      padding: EdgeInsets.fromLTRB(16, statusBarHeight + 16, 16, 24),
      color: isDark ? ThemeUtils.backgroundColor(context) : const Color(0xFFFFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                onPressed: _showCollectionMenu,
                tooltip: '更多操作',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: UnifiedCoverImage(
                coverPath: cover,
                width: coverSize,
                height: coverSize,
                borderRadius: 0,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitleLine.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitleLine,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? Colors.white.withOpacity(0.6)
                    : Colors.black.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGlassButton(
                onPressed: _playSelectedFromHeader,
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

  void _playSelectedFromHeader() {
    final videos = _videos;
    if (videos == null || videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可播放内容')),
      );
      return;
    }
    final index = _selectedVideoIndex.clamp(0, videos.length - 1);
    _playVideo(index);
  }

  void _showCollectionMenu() {
    final info = _collectionInfo;
    final cover = info?.cover ??
        ((_videos != null && _videos!.isNotEmpty) ? _videos!.first.cover : null);
    final title = info?.title ?? widget.title;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    FrostedBottomSheet.show(
      context: context,
      initialChildSize: 0.32,
      minChildSize: 0.2,
      maxChildSize: 0.6,
      header: buildFrostedSheetHeader(
        context: context,
        cover: UnifiedCoverImage(
          coverPath: cover,
          width: 48,
          height: 48,
          borderRadius: 8,
          isDark: isDark,
        ),
        title: title,
      ),
      tiles: [
        ListTile(
          leading: const Icon(Icons.play_arrow_rounded),
          title: const Text('播放'),
          onTap: () {
            Navigator.pop(context);
            _playSelectedFromHeader();
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
      ],
    );
  }

  void _showCollectionItemMenu(BilibiliCollectionItem video, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    FrostedBottomSheet.show(
      context: context,
      initialChildSize: 0.28,
      minChildSize: 0.2,
      maxChildSize: 0.6,
      header: buildFrostedSheetHeader(
        context: context,
        cover: UnifiedCoverImage(
          coverPath: video.cover,
          width: 48,
          height: 48,
          borderRadius: 8,
          isDark: isDark,
        ),
        title: video.title,
        subtitle: '时长 ${_formatDuration(video.duration)}',
      ),
      tiles: [
        ListTile(
          leading: const Icon(Icons.play_arrow_rounded),
          title: const Text('播放该视频'),
          onTap: () {
            Navigator.pop(context);
            _playVideo(index);
          },
        ),
      ],
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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

  Widget _buildCollectionContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async => _loadVideos(loadMore: false),
      child: Container(
        // 复刻多P页面的纯色背景逻辑
        color: isDark ? ThemeUtils.backgroundColor(context) : const Color(0xFFFFFFFF),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildCollectionHeader(),
            ),
            if (_videos != null && _videos!.isNotEmpty)
              _buildVideosSection(),
            if (_hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : _buildGlassLoadMoreButton(),
                  ),
                ),
              ),
            const SliverPadding(
              padding: EdgeInsets.only(bottom: 180),
            ),
          ],
        ),
      ),
    );
  }

  /// 整合的卡片容器（模仿 AppleMusicCard 样式）
  Widget _buildIntegratedCard() {
    final info = _collectionInfo;
    if (info == null) return const SizedBox.shrink();

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
                      _buildCover(info.cover, isDark),
                      const SizedBox(width: 16),

                      // 标题和副标题
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              info.title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              info.upName,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white.withOpacity(0.6)
                                    : Colors.black.withOpacity(0.5),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                            onTap: () => _playVideo(_selectedVideoIndex),
                          ),
                          const SizedBox(width: 4),
                          _buildCardAction(
                            icon: Icons.shuffle,
                            tooltip: '随机播放',
                            onTap: () => _playVideo(0),
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
                      _buildInfoChip('合集ID', '${widget.collectionId}'),
                      _buildInfoChip('视频数', '${_videos?.length ?? 0} 个'),
                      if (info.upName.isNotEmpty)
                        _buildInfoChip('UP主', info.upName),
                    ],
                  ),

                  // 简介（如果有）
                  if (info.intro.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      info.intro,
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
              child: UnifiedCoverImage(
                coverPath: coverUrl,
                width: 70,
                height: 70,
                borderRadius: 0,
                fit: BoxFit.cover,
                isDark: isDark,
                placeholder: Container(
                  color: isDark
                      ? const Color(0xFF3A3A3C)
                      : const Color(0xFFFFFFFF),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: Icon(
                  Icons.folder_outlined,
                  size: 32,
                  color: isDark
                      ? Colors.white.withOpacity(0.3)
                      : Colors.black.withOpacity(0.3),
                ),
              ),
            )
          : Icon(
              Icons.folder_outlined,
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

  /// 合集视频列表（复刻多P页面的 SliverList + AppleMusicSongTile 样式）
  SliverList _buildVideosSection() {
    final videos = _videos!;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final video = videos[index];
          final isSelected = index == _selectedVideoIndex;

          return AnimatedListItem(
            index: index,
            delay: 33,
            child: Column(
              children: [
                AppleMusicSongTile(
                  title: video.title,
                  artist: video.upName,
                  coverUrl: video.cover,
                  duration: _formatDuration(video.duration),
                  isPlaying: isSelected,
                  onTap: () => _playVideo(index),
                  onMoreTap: () => _showCollectionItemMenu(video, index),
                ),
                if (index != videos.length - 1)
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
        childCount: videos.length,
      ),
    );
  }

  /// 构建液态玻璃风格的"加载更多"按钮
  Widget _buildGlassLoadMoreButton() {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.blue.withOpacity(0.15)
                    : Colors.black.withOpacity(0.1),
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
                  onTap: () => _loadVideos(loadMore: true),
                  splashColor: Colors.white.withOpacity(0.3),
                  highlightColor: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.white.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.expand_more,
                          size: 20,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '加载更多',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
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
      },
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

  /// 显示添加到音乐库对话框
  Future<void> _showAddToLibraryDialog() async {
    try {
      final database = db.MusicDatabase.database;
      
      // 获取音乐库中已添加的收藏夹
      final allFavorites = await database.getAllBilibiliFavorites();
      final addedFavorites = allFavorites.where((f) => f.isAddedToLibrary).toList();
      
      if (!mounted) return;
      
      // 显示选择收藏夹对话框（使用底部弹窗样式）
      final result = await showModalBottomSheet<_FavoriteDialogResult>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.transparent, // 完全移除遮罩，让背景完全透明
        isScrollControlled: true, // 允许控制高度和滚动
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
        await _addCollectionToFavorite(result.favorite!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  /// 创建新收藏夹并添加合集视频
  Future<void> _createAndAddToFavorite() async {
    final titleController = TextEditingController(text: _collectionInfo?.title ?? '');
    final introController = TextEditingController(text: _collectionInfo?.intro ?? '');
    
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

      // 统一封面来源：优先将合集封面缓存到本地
      String? coverPath = _collectionInfo?.cover;
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
          debugPrint('[CollectionDetailPage] 缓存合集封面失败: $e');
        }
      }

      // 创建本地收藏夹（封面优先使用本地缓存路径）
      final favoriteId = await database.into(database.bilibiliFavorites).insert(
        db.BilibiliFavoritesCompanion.insert(
          remoteId: DateTime.now().millisecondsSinceEpoch,
          title: title,
          description: drift.Value(introController.text.trim()),
          coverUrl: drift.Value(coverPath ?? (_collectionInfo?.cover ?? '')),
          mediaCount: drift.Value(_videos?.length ?? 0),
          syncedAt: DateTime.now(),
          isAddedToLibrary: const drift.Value(true),
          isLocal: const drift.Value(true),
        ),
      );

      // 获取所有视频并添加到收藏夹
      final videos = _videos ?? [];
      for (final video in videos) {
        final filePath = buildBilibiliFilePath(
          bvid: video.bvid,
          cid: video.cid,
        );

        // 先检查是否已存在同一音源的歌曲，避免 UNIQUE(file_path) 冲突
        db.Song? existingSong = await database.getSongByPath(filePath);

        if (existingSong == null &&
            video.bvid.isNotEmpty &&
            video.cid != null) {
          existingSong =
              await database.getSongByBvidAndCid(video.bvid, video.cid!);
        }

        if (existingSong != null) {
          final updated = existingSong.copyWith(
            bilibiliFavoriteId: drift.Value(favoriteId),
          );
          await database.updateSong(updated);
        } else {
          // 为每个视频封面尝试获取本地缓存路径
          String? songCoverPath = video.cover;
          if (songCoverPath != null && songCoverPath.isNotEmpty) {
            try {
              final cookieManager = CookieManager();
              final cookie = await cookieManager.getCookieString();
              final localCover =
                  await AlbumArtCacheService.instance.ensureLocalPath(
                songCoverPath,
                cookie: cookie.isEmpty ? null : cookie,
              );
              if (localCover != null && localCover.isNotEmpty) {
                songCoverPath = localCover;
              }
            } catch (e) {
              debugPrint('[CollectionDetailPage] 缓存歌曲封面失败: $e');
            }
          }

          await database.into(database.songs).insert(
            db.SongsCompanion.insert(
              title: video.title,
              artist: drift.Value(video.upName),
              album: drift.Value(_collectionInfo?.title ?? '合集'),
              filePath: filePath,
              duration: drift.Value(video.duration),
              albumArtPath: drift.Value(songCoverPath ?? video.cover),
              source: const drift.Value('bilibili'),
              bvid: drift.Value(video.bvid),
              cid: drift.Value(video.cid),
              bilibiliFavoriteId: drift.Value(favoriteId),
            ),
          );
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已创建收藏夹"$title"并添加${videos.length}首歌曲')),
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

  /// 添加合集到收藏夹
  Future<void> _addCollectionToFavorite(db.BilibiliFavorite favorite) async {
    try {
      final database = db.MusicDatabase.database;
      final videos = _videos ?? [];
      
      if (videos.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('合集为空，无法添加')),
          );
        }
        return;
      }
      
      // 添加所有视频到收藏夹（先查再插，避免 UNIQUE(file_path) 冲突）
      for (final video in videos) {
        final filePath = buildBilibiliFilePath(
          bvid: video.bvid,
          cid: video.cid,
        );

        db.Song? existingSong = await database.getSongByPath(filePath);

        if (existingSong == null &&
            video.bvid.isNotEmpty &&
            video.cid != null) {
          existingSong =
              await database.getSongByBvidAndCid(video.bvid, video.cid!);
        }

        if (existingSong != null) {
          final updated = existingSong.copyWith(
            bilibiliFavoriteId: drift.Value(favorite.id),
          );
          await database.updateSong(updated);
        } else {
          // 为每个视频封面尝试获取本地缓存路径
          String? songCoverPath = video.cover;
          if (songCoverPath != null && songCoverPath.isNotEmpty) {
            try {
              final cookieManager = CookieManager();
              final cookie = await cookieManager.getCookieString();
              final localCover =
                  await AlbumArtCacheService.instance.ensureLocalPath(
                songCoverPath,
                cookie: cookie.isEmpty ? null : cookie,
              );
              if (localCover != null && localCover.isNotEmpty) {
                songCoverPath = localCover;
              }
            } catch (e) {
              debugPrint('[CollectionDetailPage] 缓存歌曲封面失败: $e');
            }
          }

          await database.into(database.songs).insert(
            db.SongsCompanion.insert(
              title: video.title,
              artist: drift.Value(video.upName),
              album: drift.Value(_collectionInfo?.title ?? '合集'),
              filePath: filePath,
              duration: drift.Value(video.duration),
              albumArtPath: drift.Value(songCoverPath ?? video.cover),
              source: const drift.Value('bilibili'),
              bvid: drift.Value(video.bvid),
              cid: drift.Value(video.cid),
              bilibiliFavoriteId: drift.Value(favorite.id),
            ),
          );
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加${videos.length}首歌曲到: ${favorite.title}')),
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

/// 添加到收藏夹对话框（模仿收藏夹页面的底部弹窗样式）
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
      initialChildSize: 0.6, // 初始高度为屏幕60%
      minChildSize: 0.4,      // 最小40%
      maxChildSize: 0.9,      // 最大90%，留出顶部空间
      builder: (context, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), // 强化模糊效果
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.3) // 大幅降低不透明度
                  : Colors.white.withOpacity(0.5), // 大幅降低不透明度
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.2) // 增强边框可见度
                    : Colors.white.withOpacity(0.6), // 增强边框可见度
                width: 1.5,
              ),
            ),
            child: ListView(
              controller: scrollController,
              children: [
                // 顶部拖动把手（iOS 风格）
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.2) // 深色模式更柔和
                          : Colors.black.withOpacity(0.2), // 浅色模式更柔和
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
                
                // 底部留白（避免内容紧贴底部）
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
