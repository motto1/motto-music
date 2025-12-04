import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:motto_music/models/bilibili/favorite.dart';
import 'package:motto_music/database/database.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/services/player_provider.dart';
import 'package:motto_music/services/cache/page_cache_service.dart';
import 'package:motto_music/widgets/frosted_container.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/utils/bilibili_song_utils.dart';
import 'package:motto_music/views/bilibili/user_videos_page.dart';
import 'package:motto_music/router/router.dart';
import 'package:motto_music/widgets/show_aware_page.dart';
import 'package:motto_music/contants/app_contants.dart';
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/main.dart'; // 导入以访问全局播放器 Key
import 'package:motto_music/widgets/animated_list_item.dart';
import 'package:drift/drift.dart' as drift;
import 'dart:ui';
import 'package:motto_music/widgets/apple_music_song_tile.dart';
import 'package:motto_music/widgets/audio_quality_section.dart';
import 'package:motto_music/widgets/unified_cover_image.dart';

/// 收藏夹详情页面
class FavoriteDetailPage extends StatefulWidget {
  final int favoriteId;
  final String title;
  
  const FavoriteDetailPage({
    super.key,
    required this.favoriteId,
    required this.title,
  });

  @override
  State<FavoriteDetailPage> createState() => _FavoriteDetailPageState();
}

class _FavoriteDetailPageState extends State<FavoriteDetailPage> with ShowAwarePage {
  late final BilibiliApiService _apiService;
  late final MusicDatabase _db;
  final _pageCache = PageCacheService();

  bool _isLoading = false;
  List<BilibiliFavoriteItem>? _videos;
  BilibiliFavoriteInfo? _favoriteInfo;  // 收藏夹信息（包含封面��
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLocalFavorite = false;
  final Map<String, bool> _favoriteStatusMap = {};

  String _favoriteKey(String? bvid, int? cid) =>
      '${bvid ?? 'unknown'}_${cid ?? 0}';

  @override
  void initState() {
    super.initState();
    
    _db = MusicDatabase.database;
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);
  }

  @override
  void onPageShow() {
    print('FavoriteDetailPage onPageShow called');
    _checkIfLocalAndLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 确保页面显示时加载数据
    if (_videos == null && !_isLoading) {
      print('FavoriteDetailPage didChangeDependencies - loading data');
      _checkIfLocalAndLoad();
    }
  }

  /// 检查是否为本地收藏夹
  Future<void> _checkIfLocalAndLoad() async {
    print('_checkIfLocalAndLoad called with favoriteId: ${widget.favoriteId}');
    try {
      final favorite = await _db.getBilibiliFavoriteByRemoteId(widget.favoriteId);
      if (favorite != null) {
        _isLocalFavorite = favorite.isLocal;
        print('Found favorite: ${favorite.title}, isLocal: ${favorite.isLocal}');
      } else {
        print('No favorite found with remoteId: ${widget.favoriteId}');
      }
      await _loadVideos();
    } catch (e) {
      print('Error in _checkIfLocalAndLoad: $e');
      await _loadVideos();
    }
  }

  /// 加载本地收藏夹的歌曲
  Future<void> _loadLocalFavoriteSongs() async {
    try {
      final favorite = await _db.getBilibiliFavoriteByRemoteId(widget.favoriteId);
      if (favorite == null) {
        if (mounted) {
          setState(() {
            _videos = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 获取收藏夹信息
      _favoriteInfo = BilibiliFavoriteInfo(
        id: favorite.remoteId,
        title: favorite.title,
        intro: favorite.description ?? '',
        cover: favorite.coverUrl ?? '',
        mediaCount: favorite.mediaCount,
        upper: BilibiliFavoriteUploader(name: '本地收藏夹', mid: 0),
      );

      // 从数据库查询关联的歌曲
      final songs = await (_db.select(_db.songs)
            ..where((s) => s.bilibiliFavoriteId.equals(favorite.id)))
          .get();

      // 本地收藏夹显示歌曲,转换为视频格式以复用UI
      final videos = songs.map((song) => BilibiliFavoriteItem(
        id: song.id,
        bvid: song.bvid ?? '',
        title: song.title,
        cover: song.albumArtPath ?? '',
        duration: song.duration ?? 0,
        upper: BilibiliFavoriteUploader(name: song.artist ?? '', mid: 0),
        cid: song.cid,
      )).toList();

      if (mounted) {
        setState(() {
          _videos = videos;
          _hasMore = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// 加载视频列表
  Future<void> _loadVideos({bool loadMore = false}) async {
    print('_loadVideos called: loadMore=$loadMore, _isLoading=$_isLoading, _hasMore=$_hasMore');
    if (_isLoading || (!loadMore && !_hasMore)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 本地收藏夹从数据库读取歌曲
      if (_isLocalFavorite) {
        print('Loading local favorite songs');
        await _loadLocalFavoriteSongs();
        return;
      }

      // 在线收藏夹：先尝试从缓存读取
      if (!loadMore) {
        final cachedVideos = await _pageCache.getCachedFavoriteDetail(widget.favoriteId);
        if (cachedVideos != null && cachedVideos.isNotEmpty) {
          debugPrint('🎯 收藏夹详情缓存命中: ${cachedVideos.length} 个视频');

          // 从数据库加载收藏夹基本信息（用于头部UI）
          final favorite = await _db.getBilibiliFavoriteByRemoteId(widget.favoriteId);
          if (favorite != null) {
            _favoriteInfo = BilibiliFavoriteInfo(
              id: favorite.remoteId,
              title: favorite.title,
              intro: favorite.description ?? '',
              cover: favorite.coverUrl ?? '',
              mediaCount: favorite.mediaCount,
              upper: BilibiliFavoriteUploader(
                name: _isLocalFavorite ? '本地收藏夹' : 'Bilibili',
                mid: 0,
              ),
            );
          }

          if (mounted) {
            setState(() {
              _videos = cachedVideos;
              _currentPage = 1;
              _hasMore = false; // 缓存只保存第一页
              _isLoading = false;
            });

            // 查询喜欢状态
            await _loadFavoriteStatus();
          }

          // 延迟2秒后再后台刷新，避免打断用户浏览
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _refreshVideosInBackground();
            }
          });
          return;
        }
      }

      // 缓存未命中或加载更多，从API获取
      final page = loadMore ? _currentPage + 1 : 1;
      debugPrint('📡 从API加载收藏夹详情: favoriteId=${widget.favoriteId}, page=$page');

      // 使用新的API方法获取完整信息
      final contents = await _apiService.getFavoriteContentsWithInfo(
        widget.favoriteId,
        page,
      );
      print('API response received: ${contents.medias?.length ?? 0} items');

      // 展开多P视频为独立条目
      final expandedVideos = await _expandMultiPageVideos(contents.medias ?? []);

      // 首次加载时缓存视频列表
      if (page == 1 && expandedVideos.isNotEmpty) {
        await _pageCache.cacheFavoriteDetail(widget.favoriteId, expandedVideos);
      }

      if (mounted) {
        setState(() {
          // 首次加载时保存收藏夹信息
          if (page == 1) {
            _favoriteInfo = contents.info;
            // 更新数据库中的封面信息
            _updateFavoriteCover(contents.info);
          }

          if (loadMore) {
            _videos = [...?_videos, ...expandedVideos];
            _currentPage = page;
          } else {
            _videos = expandedVideos;
            _currentPage = 1;
          }
          _hasMore = contents.hasMore;
          _isLoading = false;
        });
        print('Videos loaded successfully: ${_videos?.length ?? 0} items');

        // 查询喜欢状态
        await _loadFavoriteStatus();
      }
    } catch (e) {
      print('Error loading videos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// 后台刷新视频列表（静默更新缓存，不影响UI）
  Future<void> _refreshVideosInBackground() async {
    try {
      debugPrint('🔄 后台刷新收藏夹详情...');
      final contents = await _apiService.getFavoriteContentsWithInfo(widget.favoriteId, 1);
      final expandedVideos = await _expandMultiPageVideos(contents.medias ?? []);

      // 只更新缓存，不触发 UI 重建，完全避免滚动跳动
      await _pageCache.cacheFavoriteDetail(widget.favoriteId, expandedVideos);

      debugPrint('✅ 后台刷新完成（仅更新缓存）');
    } catch (e) {
      debugPrint('⚠️ 后台刷新失败: $e');
    }
  }

  /// 展开多P视频为独立条目
  Future<List<BilibiliFavoriteItem>> _expandMultiPageVideos(List<BilibiliFavoriteItem> videos) async {
    final expanded = <BilibiliFavoriteItem>[];
    
    for (final video in videos) {
      // 获取视频的分P列表
      try {
        if ((video.bvid ?? '').isEmpty) {
          expanded.add(video);
          continue;
        }

        final pages = await _pageCache.getOrFetchVideoPages(
          video.bvid!,
          () => _apiService.getVideoPages(video.bvid!),
        );
        
        if (pages.length > 1) {
          // 多P视频：为每个分P创建独立条目
          for (final page in pages) {
            expanded.add(BilibiliFavoriteItem(
              id: video.id,
              bvid: video.bvid,
              cid: page.cid,
              title: page.part,
              cover: video.cover,
              duration: page.duration,
              upper: video.upper,
              pubdate: video.pubdate,
            ));
          }
        } else {
          // 单P视频：直接添加
          expanded.add(video);
        }
      } catch (e) {
        // 获取分P失败，使用原视频
        expanded.add(video);
      }
    }
    
    return expanded;
  }

  /// 更新数据库中的收藏夹封面信息
  Future<void> _updateFavoriteCover(BilibiliFavoriteInfo info) async {
    try {
      // 先获取现有记录，保留 isAddedToLibrary 和 isLocal
      final existing = await _db.getBilibiliFavoriteByRemoteId(info.id);
      
      await _db.insertBilibiliFavorite(
        BilibiliFavoritesCompanion.insert(
          remoteId: info.id,
          title: info.title,
          description: drift.Value(info.intro),
          coverUrl: drift.Value(info.cover),
          mediaCount: drift.Value(info.mediaCount),
          syncedAt: DateTime.now(),
          isAddedToLibrary: drift.Value(existing?.isAddedToLibrary ?? false),
          isLocal: drift.Value(existing?.isLocal ?? false),
        ),
      );
    } catch (e) {
      // 静默失败，不影响UI
      debugPrint('更新收藏夹封面失败: $e');
    }
  }

  /// 播放视频并设置播放列表（不添加到音乐库）
  Future<void> _playVideoAndSetPlaylist(
    BilibiliFavoriteItem clickedItem,
    int clickedIndex,
    {bool shuffle = false}
  ) async {
    if (_videos == null || _videos!.isEmpty) return;

    try {
      // 本地收藏夹直接从数据库读取歌曲
      if (_isLocalFavorite) {
        final favorite = await _db.getBilibiliFavoriteByRemoteId(widget.favoriteId);
        if (favorite != null) {
          final songs = await (_db.select(_db.songs)
                ..where((s) => s.bilibiliFavoriteId.equals(favorite.id)))
              .get();
          
          if (songs.isNotEmpty && mounted) {
            final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
            await playerProvider.playSong(
              songs[clickedIndex],
              playlist: songs,
              index: clickedIndex,
              shuffle: shuffle,
              playNow: true,
            );
          }
        }
        return;
      }
      
      // 在线收藏夹:将视频转换为临时 Song 列表
      final List<Song> playlist = [];

      for (int i = 0; i < _videos!.length; i++) {
        final item = _videos![i];

        // 创建临时 Song ��象（使用负数 ID 表示临时对象）
        final tempSong = Song(
          id: -(i + 1), // 使用负数避免与数据库 ID 冲突
          title: item.title,
          artist: item.upper?.name,
          album: null,
          filePath: buildBilibiliFilePath(
            bvid: item.bvid,
            cid: item.cid,
          ),
          lyrics: null,
          bitrate: null,
          sampleRate: null,
          duration: item.duration,
          albumArtPath: item.cover, // 使用 Bilibili 封面 URL
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
        throw Exception('收藏夹为空');
      }

      // 找到被点击的歌曲
      final clickedSong = playlist[clickedIndex];

      // 获取 PlayerProvider 并播放
      if (mounted) {
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        await playerProvider.playSong(
          clickedSong,
          playlist: playlist,
          index: clickedIndex,
          shuffle: shuffle,
          playNow: true,
        );

        // 播放后不自动打开播放界面，用户可以通过点击小播放器展开
      }
    } catch (e) {
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
          
          debugPrint('[FavoriteDetailPage PopScope] 播放器展开百分比: ${(percentage * 100).toStringAsFixed(1)}%');
          
          if (playerState != null && percentage >= 0.9) {
            // 播放器全屏，优先缩小播放器
            debugPrint('[FavoriteDetailPage PopScope] ✓ 拦截返回，缩小播放器');
            playerState.animateToState(false);
            return;
          }
          
          // 播放器非全屏，正常返回上一页
          debugPrint('[FavoriteDetailPage PopScope] → 返回上一页');
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? ThemeUtils.backgroundColor(context)
            : const Color(0xFFFFFFFF),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _videos == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_errorMessage != null && _videos == null) {
      return _buildErrorView();
    }
    
    if (_videos != null && _videos!.isEmpty) {
      return _buildEmptyView();
    }
    
    return _buildVideosList();
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
            const Text('加载失败', style: TextStyle(fontSize: 18)),
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
              onPressed: () => _loadVideos(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '收藏夹为空',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosList() {
    if (_videos == null) {
      return Center(child: CircularProgressIndicator());
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      // 统一的背景色，防止BackdropFilter模糊到不同颜色
      color: isDark 
          ? ThemeUtils.backgroundColor(context)
          : const Color(0xFFFFFFFF),
      child: CustomScrollView(
        slivers: [
              // 简洁的头部（移除固定的 AppBar）
              SliverToBoxAdapter(
                child: _buildFavoriteHeader(),
              ),
              
              // 歌曲列表（添加动画）
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _videos!.length && _hasMore) {
                      // 加载更多
                      if (!_isLoading) {
                        _loadVideos(loadMore: true);
                      }
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    
                    if (index >= _videos!.length) return null;
                    
                    final video = _videos![index];
                    return AnimatedListItem(
                      index: index,
                      delay: 33, // 加快1.5倍（50 / 1.5 ≈ 33）
                      child: Column(
                        children: [
                          AppleMusicSongTile(
                            title: video.title,
                            artist: video.upper?.name,
                            coverUrl: video.cover,
                            duration: video.duration != null 
                                ? formatDuration(video.duration!)
                                : null,
                            isFavorite: _getSongFavoriteStatus(video),
                            onTap: () => _playVideoAndSetPlaylist(video, index),
                            onFavoriteTap: () => _toggleFavoriteForVideo(video, index),
                            onMoreTap: () => _showSongMenu(video, index),
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
                  childCount: _videos!.length + (_hasMore ? 1 : 0),
                ),
              ),
              
              // 底部安全区域（避免被播放器遮挡）
              SliverPadding(
                padding: EdgeInsets.only(bottom: 180),
              ),
            ],
          ),
    );
  }
  
  /// 构建浮动返回按钮（液态玻璃效果）
  Widget _buildFloatingBackButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.blue.withOpacity(0.15)
                : Colors.blue.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.white.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: '返回',
            ),
          ),
        ),
      ),
    );
  }
  
  /// 构建收藏夹头部（显示封面和信息）
  Widget _buildFavoriteHeader() {
    if (_favoriteInfo == null) {
      return const SizedBox.shrink();
    }
    
    final info = _favoriteInfo!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    
    return Container(
      padding: EdgeInsets.fromLTRB(16, statusBarHeight + 16, 16, 24),
      color: isDark
          ? ThemeUtils.backgroundColor(context)
          : const Color(0xFFFFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 返回按钮
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: 22,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: '返回',
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Apple Music 风格的封面 - 带阴影
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: info.cover,
                width: MediaQuery.of(context).size.width * 0.6,
                height: MediaQuery.of(context).size.width * 0.6,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: MediaQuery.of(context).size.width * 0.6,
                  color: isDark
                      ? const Color(0xFF3A3A3C)
                      : const Color(0xFFE5E5EA),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: MediaQuery.of(context).size.width * 0.6,
                  color: isDark
                      ? const Color(0xFF3A3A3C)
                      : const Color(0xFFE5E5EA),
                  child: Icon(
                    Icons.folder_outlined,
                    size: 64,
                    color: isDark
                        ? Colors.white.withOpacity(0.3)
                        : Colors.black.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 标题（添加浅泛阴影）
          Text(
            widget.title,
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
          
          if (info.intro.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              info.intro,
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
          ],
          
          const SizedBox(height: 24),
          
          // 播放和随机按钮 - 液态玻璃效果
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 播放按钮
              _buildGlassButton(
                onPressed: () => _playAll(shuffle: false),
                icon: Icons.play_arrow,
                label: '播放',
                isPrimary: true,
              ),
              
              const SizedBox(width: 16),
              
              // 随机播放按钮
              _buildGlassButton(
                onPressed: () => _playAll(shuffle: true),
                icon: Icons.shuffle,
                label: '随机',
                isPrimary: false,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  /// 构建液态玻璃按钮
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
                : (isDark ? Colors.blue.withOpacity(0.15) : Colors.black.withOpacity(0.1)),
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
              splashColor: Colors.white.withOpacity(0.3), // 点击光晕
              highlightColor: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? const Color(0xFFFF3B30).withOpacity(0.9) // 主按钮红色
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
                      color: isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black),
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
  
  /// 播放全部（支持随机）
  Future<void> _playAll({required bool shuffle}) async {
    if (_videos == null || _videos!.isEmpty) return;
    await _playVideoAndSetPlaylist(_videos![0], 0, shuffle: shuffle);
  }

  /// 显示歌曲菜单
  Future<void> _showSongMenu(BilibiliFavoriteItem video, int index) async {
    // 获取对应的Song对象
    Song? song;
    if (_isLocalFavorite) {
      final favorite = await _db.getBilibiliFavoriteByRemoteId(widget.favoriteId);
      if (favorite != null) {
        final songs = await (_db.select(_db.songs)
              ..where((s) => s.bilibiliFavoriteId.equals(favorite.id)))
            .get();
        if (index < songs.length) {
          song = songs[index];
        }
      }
    } else {
      // 在线收藏夹，先查询数据库看是否已存在
      final query = _db.select(_db.songs)
        ..where((s) => s.bvid.equals(video.bvid));

      if (video.cid != null) {
        query.where((s) => s.cid.equals(video.cid!));
      }

      final existingSongs = await query.get();

      if (existingSongs.isNotEmpty) {
        // 如果数据库中已存在，使用数据库中的歌曲
        song = existingSongs.first;
      } else {
        // 创建临时Song对象，使用当前的喜欢状态
        song = Song(
          id: -(index + 1),
          title: video.title,
          artist: video.upper?.name,
          album: null,
          filePath: buildBilibiliFilePath(
            bvid: video.bvid,
            cid: video.cid,
          ),
          duration: video.duration,
          albumArtPath: video.cover,
          dateAdded: DateTime.now(),
          isFavorite: _getSongFavoriteStatus(video),
          lastPlayedTime: DateTime.now(),
          playedCount: 0,
          source: 'bilibili',
          bvid: video.bvid,
          cid: video.cid,
        );
      }
    }

    if (song == null || !mounted) return;

    final currentSong = song; // 保存为非null变量

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
                  // 拖动把手
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
                          coverPath: currentSong.albumArtPath,
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
                                currentSong.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentSong.artist ?? '',
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

                  // ========== 原有菜单项 ==========
                  if (_isLocalFavorite) ...[
                    ListTile(
                      leading: const Icon(Icons.remove_circle_outline),
                      title: const Text('从收藏夹移除'),
                      onTap: () {
                        Navigator.pop(context);
                        _removeFromFavorite(currentSong);
                      },
                    ),
                  ],
                  ListTile(
                    leading: Icon(
                      currentSong.isFavorite ? Icons.favorite : Icons.favorite_border,
                    ),
                    title: Text(currentSong.isFavorite ? '取消喜欢' : '喜欢'),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleFavorite(currentSong);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.play_circle_outline),
                    title: const Text('插播'),
                    onTap: () {
                      Navigator.pop(context);
                      _playNext(currentSong);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_add),
                    title: const Text('添加到播放列表'),
                    onTap: () {
                      Navigator.pop(context);
                      _addToPlaylist(currentSong);
                    },
                  ),
                  // ========== ⭐ 音质选择和下载区域 ==========
                  if (currentSong.source == 'bilibili' && currentSong.bvid != null)
                    AudioQualitySection(song: currentSong),
                  if (video.upper != null)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('查看制作人员'),
                      onTap: () {
                        Navigator.pop(context);
                        _viewCreator(video.upper!);
                      },
                    ),
                  // 底部留白
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 从收藏夹移除（仅本地收藏夹）
  Future<void> _removeFromFavorite(Song song) async {
    try {
      await (_db.delete(_db.songs)..where((s) => s.id.equals(song.id))).go();
      
      // 重新加载
      await _loadVideos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已从收藏夹移除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移除失败: $e')),
        );
      }
    }
  }

  /// 切换喜欢状态
  Future<void> _toggleFavorite(Song song) async {
    try {
      final targetStatus = !song.isFavorite;
      final filePath = song.filePath.isNotEmpty
          ? song.filePath
          : buildBilibiliFilePath(
              bvid: song.bvid,
              cid: song.cid,
              pageNumber: song.pageNumber,
            );

      if (song.id < 0) {
        debugPrint('[_toggleFavorite] 准备为临时歌曲创建/更新记录');
        debugPrint('  标题: ${song.title}');
        debugPrint('  当前喜欢状态: ${song.isFavorite}');
        debugPrint('  将设置为: $targetStatus');

        final existingSong = await _db.getSongByPath(filePath) ??
            ((song.bvid != null && song.cid != null)
                ? await _db.getSongByBvidAndCid(song.bvid!, song.cid!)
                : null);

        if (existingSong != null) {
          final updatedExisting = existingSong.copyWith(isFavorite: targetStatus);
          await _db.updateSong(updatedExisting);
          _favoriteStatusMap[_favoriteKey(song.bvid, song.cid)] =
              updatedExisting.isFavorite;
          debugPrint('  已更新已有歌曲 ID: ${existingSong.id}');
        } else {
          final newId = await _db.insertSong(
            SongsCompanion.insert(
              title: song.title,
              filePath: filePath,
              source: drift.Value(song.source),
              artist: drift.Value(song.artist),
              album: drift.Value(song.album),
              duration: drift.Value(song.duration),
              albumArtPath: drift.Value(song.albumArtPath),
              dateAdded: drift.Value(song.dateAdded),
              isFavorite: drift.Value(targetStatus),
              bvid: drift.Value(song.bvid),
              cid: drift.Value(song.cid),
              lastPlayedTime: drift.Value(song.lastPlayedTime),
              playedCount: drift.Value(song.playedCount),
            ),
          );
          debugPrint('  已插入新歌曲 ID: $newId');
          _favoriteStatusMap[_favoriteKey(song.bvid, song.cid)] = targetStatus;
        }
      } else {
        debugPrint('[_toggleFavorite] 更新已存在歌曲 ID: ${song.id}');
        final updatedSong = song.copyWith(isFavorite: targetStatus);
        await _db.updateSong(updatedSong);
        _favoriteStatusMap[_favoriteKey(song.bvid, song.cid)] =
            updatedSong.isFavorite;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(targetStatus ? '已添加到喜欢' : '已取消喜欢')),
        );
        setState(() {
          if (_isLocalFavorite && _videos != null) {
            _loadVideos();
          }
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[_toggleFavorite] 错误: $e');
      debugPrint('  堆栈: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  /// 插播（添加到下一首）
  Future<void> _playNext(Song song) async {
    try {
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      // 使用addToPlaylist添加到播放列表
      playerProvider.addToPlaylist(song);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已添加到播放列表')),
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

  /// 添加到播放列表
  Future<void> _addToPlaylist(Song song) async {
    try {
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      playerProvider.addToPlaylist(song);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已添加到播放列表')),
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

  /// 查看制作人员
  void _viewCreator(BilibiliFavoriteUploader uploader) {
    Navigator.of(context).push(
      NamidaPageRoute(
        page: UserVideosPage(
          mid: uploader.mid,
          userName: uploader.name,
        ),
        type: PageTransitionType.slideLeft,
      ),
    );
  }

  Widget _buildVideoCard(BilibiliFavoriteItem video, int index) {
    return Column(
      children: [
        InkWell(
          onTap: () => _playVideoAndSetPlaylist(video, index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 方形封面
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: video.cover,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 56,
                      height: 56,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 56,
                      height: 56,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.music_note, size: 24),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 标题
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
                      
                      // 艺术家
                      if (video.upper != null)
                        Text(
                          video.upper!.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                
                // 三点菜单
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    size: 20,
                  ),
                  onPressed: () => _showSongMenu(video, index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 分隔线
        Divider(
          height: 1,
          thickness: 0.5,
          indent: 88,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
      ],
    );
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '--:--';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  String _formatCount(int? count) {
    if (count == null || count == 0) return '0';
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return count.toString();
  }

  /// 获取歌曲的喜欢状态
  bool _getSongFavoriteStatus(BilibiliFavoriteItem video) {
    final key = _favoriteKey(video.bvid, video.cid);
    return _favoriteStatusMap[key] ?? false;
  }

  /// 加载所有歌曲的喜欢状态
  Future<void> _loadFavoriteStatus() async {
    if (_videos == null || _videos!.isEmpty) return;
    
    try {
      for (final video in _videos!) {
        final key = _favoriteKey(video.bvid, video.cid);
        
        // 查询数据库中是否存在该歌曲
        final query = _db.select(_db.songs)
          ..where((s) => s.bvid.equals(video.bvid));
        
        if (video.cid != null) {
          query.where((s) => s.cid.equals(video.cid!));
        }
        
        final existingSongs = await query.get();
        
        if (existingSongs.isNotEmpty) {
          _favoriteStatusMap[key] = existingSongs.first.isFavorite;
        } else {
          _favoriteStatusMap[key] = false;
        }
      }
      
      if (mounted) {
        setState(() {}); // 刷新UI
      }
    } catch (e) {
      debugPrint('加载喜欢状态失败: $e');
    }
  }

  /// 更新歌曲的喜欢状态（用于UI刷新）
  Future<void> _toggleFavoriteForVideo(BilibiliFavoriteItem video, int index) async {
    final key = _favoriteKey(video.bvid, video.cid);
    final currentStatus = _favoriteStatusMap[key] ?? false;
    final targetStatus = !currentStatus;
    final filePath = buildBilibiliFilePath(
      bvid: video.bvid,
      cid: video.cid,
    );
    
    // 创建临时Song对象用于数据库操作
    Song? song;
    if (_isLocalFavorite) {
      final favorite = await _db.getBilibiliFavoriteByRemoteId(widget.favoriteId);
      if (favorite != null) {
        final songs = await (_db.select(_db.songs)
              ..where((s) => s.bilibiliFavoriteId.equals(favorite.id)))
            .get();
        if (index < songs.length) {
          song = songs[index];
        }
      }
    } else {
      // 在线收藏夹，查询数据库看是否已存在
      final query = _db.select(_db.songs)
        ..where((s) => s.bvid.equals(video.bvid));
      
      if (video.cid != null) {
        query.where((s) => s.cid.equals(video.cid!));
      }
      
      final existingSongs = await query.get();
      
      if (existingSongs.isNotEmpty) {
        song = existingSongs.first;
      }
    }

    song ??= await _db.getSongByPath(filePath);

    // 更新或创建歌曲
    if (song != null && song.id > 0) {
      // 已存在的歌曲，直接更新
      final updatedSong = song.copyWith(isFavorite: targetStatus);
      await _db.updateSong(updatedSong);
    } else {
      // 新歌曲，使用 Companion.insert 让数据库自动生成 ID
      await _db.insertSong(
        SongsCompanion.insert(
          title: video.title,
          filePath: filePath,
          source: const drift.Value('bilibili'),
          artist: drift.Value(video.upper?.name),
          album: const drift.Value(null),
          duration: drift.Value(video.duration),
          albumArtPath: drift.Value(video.cover),
          dateAdded: drift.Value(DateTime.now()),
          isFavorite: drift.Value(targetStatus),
          bvid: drift.Value(video.bvid),
          cid: drift.Value(video.cid),
          lastPlayedTime: drift.Value(DateTime.now()),
          playedCount: const drift.Value(0),
        ),
      );
    }

    // 更新UI状态
    setState(() {
      _favoriteStatusMap[key] = targetStatus;
      if (_isLocalFavorite && _videos != null) {
        _loadVideos();
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(targetStatus ? '已添加到喜欢' : '已取消喜欢')),
      );
    }
  }
}
