import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:motto_music/models/bilibili/video.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/views/bilibili/video_detail_page.dart';
import 'package:motto_music/views/bilibili/user_videos_page.dart';
import 'package:motto_music/views/bilibili/global_search_page.dart';
import 'package:motto_music/database/database.dart' as db;
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/utils/bilibili_song_utils.dart';
import 'package:motto_music/services/player_provider.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:motto_music/widgets/apple_music_card.dart';

/// 全局搜索结果页
/// 
/// 显示视频搜索结果，支持分页加载
class GlobalSearchResultPage extends StatefulWidget {
  /// 搜索关键词
  final String query;

  const GlobalSearchResultPage({
    super.key,
    required this.query,
  });

  @override
  State<GlobalSearchResultPage> createState() => _GlobalSearchResultPageState();
}

class _GlobalSearchResultPageState extends State<GlobalSearchResultPage> {
  late final BilibiliApiService _apiService;
  late final ScrollController _scrollController;
  
  List<BilibiliVideo> _videos = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);
    
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    _loadSearchResults();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动监听，实现无限滚动
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // 距离底部200像素时开始加载下一页
      if (!_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  /// 加载搜索结果（首页）
  Future<void> _loadSearchResults() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      final videos = await _apiService.searchVideos(widget.query, _currentPage);
      
      if (mounted) {
        setState(() {
          _videos = videos;
          _isLoading = false;
          _hasMore = videos.isNotEmpty && videos.length >= 20; // 假设每页20条
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

  /// 加载更多
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final videos = await _apiService.searchVideos(widget.query, nextPage);
      
      if (mounted) {
        setState(() {
          _videos.addAll(videos);
          _currentPage = nextPage;
          _isLoadingMore = false;
          _hasMore = videos.isNotEmpty && videos.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载更多失败: $e')),
        );
      }
    }
  }

  /// 下拉刷新
  Future<void> _refresh() async {
    await _loadSearchResults();
  }

  /// 格式化时长（秒 -> MM:SS）
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeUtils.backgroundColor(context),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _wrapWithoutStretch(
              _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _videos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _videos.isEmpty) {
      return _buildErrorView();
    }

    if (_videos.isEmpty) {
      return _buildEmptyView();
    }

    return _buildVideoList();
  }

  Widget _buildHeader(BuildContext context) {
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
                          '搜索: ${widget.query}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, size: 20),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GlobalSearchPage(initialQuery: widget.query),
                            ),
                          );
                        },
                        tooltip: '新搜索',
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

  Widget _wrapWithoutStretch(Widget child) {
    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (notification) {
        notification.disallowIndicator();
        return true;
      },
      child: child,
    );
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
              '搜索失败',
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
              onPressed: _loadSearchResults,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
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
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '未找到相关视频',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '搜索: "${widget.query}"',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建视频列表
  Widget _buildVideoList() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 36),
        itemCount: _videos.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _videos.length) {
            return _buildLoadingMoreIndicator();
          }

          final video = _videos[index];
          return AppleMusicCard(
            title: video.title,
            subtitle: '${video.owner.name} · ${_formatDuration(video.duration)}',
            coverUrl: video.pic,
            margin: EdgeInsets.fromLTRB(16, index == 0 ? 16 : 8, 16, 8),
            trailing: Text(
              _formatPubdate(video.pubdate),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            onTap: () => _navigateToVideoDetail(video),
            onLongPress: () => _playVideo(video, index),
            onAuthorTap: () => _navigateToUploader(video.owner.mid, video.owner.name, video.owner.face),
          );
        },
      ),
    );
  }
  /// 构建加载更多指示器
  Widget _buildLoadingMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: _isLoadingMore
            ? const CircularProgressIndicator()
            : const SizedBox.shrink(),
      ),
    );
  }

  /// 构建视频卡片
  Widget _buildVideoCard(BilibiliVideo video) {
    final index = _videos.indexOf(video);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        onTap: () => _navigateToVideoDetail(video),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面（可点击播放）
              InkWell(
                onTap: () => _playVideo(video, index),
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: video.pic,
                        width: 120,
                        height: 75,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 120,
                          height: 75,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 120,
                          height: 75,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ),
                      
                      // 播放图标覆盖层
                      Container(
                        width: 120,
                        height: 75,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      
                      // 时长标签
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            _formatDuration(video.duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      video.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // 作者
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            video.owner.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // BV号
                    Row(
                      children: [
                        Icon(
                          Icons.videocam,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          video.bvid,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 箭头
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 跳转到视频详情
  void _navigateToVideoDetail(BilibiliVideo video) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoDetailPage(
          bvid: video.bvid,
          title: video.title,
        ),
      ),
    );
  }

  /// 跳转到UP主主页
  void _navigateToUploader(int mid, String name, String? face) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserVideosPage(
          mid: mid,
          userName: name,
          userAvatar: face,
        ),
      ),
    );
  }

  /// 直接播放视频
  Future<void> _playVideo(BilibiliVideo video, int index) async {
    try {
      // 创建当前视频的 Song 对象
      final song = db.Song(
        id: -(index + 1), // 使用负数ID避免与数据库冲突
        title: video.title,
        artist: video.owner.name,
        album: '搜索结果',
        filePath: buildBilibiliFilePath(
          bvid: video.bvid,
          cid: null,
        ),
        lyrics: null,
        bitrate: null,
        sampleRate: null,
        duration: video.duration,
        albumArtPath: video.pic,
        dateAdded: DateTime.now(),
        isFavorite: false,
        lastPlayedTime: DateTime.now(),
        playedCount: 0,
        source: 'bilibili',
        bvid: video.bvid,
        cid: null, // 将在播放时获取
        pageNumber: null,
        bilibiliVideoId: null,
      );

      // 创建播放列表（当前搜索结果的所有视频）
      final playlist = _videos.asMap().entries.map((entry) {
        final idx = entry.key;
        final v = entry.value;
        return db.Song(
          id: -(idx + 1),
          title: v.title,
          artist: v.owner.name,
          album: '搜索结果',
          filePath: buildBilibiliFilePath(
            bvid: v.bvid,
            cid: null,
          ),
          lyrics: null,
          bitrate: null,
          sampleRate: null,
          duration: v.duration,
          albumArtPath: v.pic,
          dateAdded: DateTime.now(),
          isFavorite: false,
          lastPlayedTime: DateTime.now(),
          playedCount: 0,
          source: 'bilibili',
          bvid: v.bvid,
          cid: null,
          pageNumber: null,
          bilibiliVideoId: null,
        );
      }).toList();

      if (mounted) {
        final playerProvider = context.read<PlayerProvider>();
        await playerProvider.playSong(
          song,
          playlist: playlist,
          index: index,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }
}
