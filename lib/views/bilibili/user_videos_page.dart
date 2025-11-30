import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/models/bilibili/video.dart';
import 'package:motto_music/services/player_provider.dart';
import 'package:motto_music/database/database.dart' as db;
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/widgets/show_aware_page.dart';
import 'package:motto_music/views/bilibili/video_detail_page.dart';
import 'package:motto_music/widgets/apple_music_card.dart';
import 'package:motto_music/services/cache/page_cache_service.dart';

/// Bilibili 用户视频页面
/// 显示某个UP主的所有视频
class UserVideosPage extends StatefulWidget {
  final int mid; // 用户ID
  final String userName; // 用户名称
  final String? userAvatar; // 用户头像

  const UserVideosPage({
    super.key,
    required this.mid,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<UserVideosPage> createState() => _UserVideosPageState();
}

class _UserVideosPageState extends State<UserVideosPage> with ShowAwarePage {
  late final BilibiliApiService _apiService;
  final PageCacheService _pageCache = PageCacheService();
  
  bool _isLoading = false;
  List<BilibiliVideo>? _videos;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMore = true;
  
  // 动态加载的用户信息
  String? _loadedUserName;
  String? _loadedUserAvatar;

  String _cacheKeyForPage(int page) => 'uploader_${widget.mid}_page_$page';

  @override
  void initState() {
    super.initState();
    
    debugPrint('🎯 UserVideosPage.initState: mid=${widget.mid}');
    
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);
    
    _loadCachedVideos();
    // 直接在 initState 中加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🎯 PostFrameCallback: 开始加载数据');
      // 如果传入的是默认名称或没有头像，先加载用户信息
      if (widget.userName == 'UP主' || widget.userAvatar == null) {
        _loadUserInfo();
      }
      _loadVideos();
    });
  }

  Future<void> _loadCachedVideos() async {
    final cached = await _pageCache.getCachedVideoList(_cacheKeyForPage(1));
    if (!mounted || cached == null || cached.isEmpty) {
      return;
    }
    setState(() {
      _videos = cached;
      _isLoading = false;
      _currentPage = 1;
      _hasMore = cached.length >= 30;
    });
  }

  @override
  void onPageShow() {
    debugPrint('🎯 UserVideosPage.onPageShow: mid=${widget.mid}');
    // onPageShow 可能不会被调用,主要在 initState 中加载
  }

  /// 加载UP主基本信息
  Future<void> _loadUserInfo() async {
    debugPrint('📥 _loadUserInfo 开始: mid=${widget.mid}');
    
    try {
      final userInfo = await _apiService.getUserInfo(widget.mid);
      
      debugPrint('✅ 用户信息加载成功: ${userInfo.name}');
      
      if (mounted) {
        setState(() {
          _loadedUserName = userInfo.name;
          _loadedUserAvatar = userInfo.face;
        });
      }
    } catch (e) {
      debugPrint('❌ 加载用户信息失败: $e');
      // 用户信息加载失败不影响视频列表展示
    }
  }

  /// 加载UP主视频列表
  Future<void> _loadVideos({bool loadMore = false}) async {
    debugPrint('📥 _loadVideos 开始: loadMore=$loadMore, _isLoading=$_isLoading, _hasMore=$_hasMore');
    
    if (_isLoading || (!loadMore && !_hasMore)) {
      debugPrint('⚠️ _loadVideos 跳过: _isLoading=$_isLoading, _hasMore=$_hasMore');
      return;
    }
    
    setState(() {
      _isLoading = loadMore ? true : (_videos == null || _videos!.isEmpty);
      _errorMessage = null;
    });

    debugPrint('🔄 开始请求 UP主视频: mid=${widget.mid}, currentPage=$_currentPage');

    try {
      final page = loadMore ? _currentPage + 1 : 1;
      debugPrint('📡 准备调用 API: page=$page');
      
      final videos = await _apiService.getUploaderVideos(
        mid: widget.mid,
        page: page,
        pageSize: 30,
      );
      await _pageCache.cacheVideoList(_cacheKeyForPage(page), videos);
      
      debugPrint('✅ API 返回成功: ${videos.length} 个视频');
      
      if (mounted) {
        setState(() {
          if (loadMore) {
            _videos = [...?_videos, ...videos];
            _currentPage = page;
          } else {
            _videos = videos;
            _currentPage = 1;
          }
          _hasMore = videos.length >= 30;
          _isLoading = false;
        });
        debugPrint('✅ 状态更新完成: total=${_videos?.length}, hasMore=$_hasMore');
      }
    } catch (e) {
      debugPrint('❌ 加载失败: $e');
      debugPrint('❌ 错误堆栈: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
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
              Padding(
                padding: const EdgeInsets.only(bottom: 120),
                child: _buildBody(),
              ),
            ),
          ),
        ],
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
    
    // 确保 _videos 不为 null 才继续
    if (_videos == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_videos!.isEmpty) {
      return _buildEmptyView();
    }
    
    return _buildVideosList();
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // 优先使用动态加载的用户信息
    final displayName = _loadedUserName ?? widget.userName;
    final displayAvatar = _loadedUserAvatar ?? widget.userAvatar;

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
                      if (displayAvatar != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: CachedNetworkImageProvider(displayAvatar),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          displayName,
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
                        onPressed: _videos == null ? null : () => _loadVideos(),
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

  Widget _wrapWithoutStretch(Widget child) {
    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (notification) {
        notification.disallowIndicator();
        return true;
      },
      child: child,
    );
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
            '暂无视频',
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
    return RefreshIndicator(
      onRefresh: () => _loadVideos(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 36),
        itemCount: _videos!.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _videos!.length) {
            if (!_isLoading) {
              _loadVideos(loadMore: true);
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final video = _videos![index];
          return AppleMusicCard(
            title: video.title,
            subtitle: _formatPubdate(video.pubdate),
            coverUrl: video.pic,
            margin: EdgeInsets.fromLTRB(16, index == 0 ? 16 : 8, 16, 8),
            onTap: () => _navigateToVideo(video),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
          );
        },
      ),
    );
  }

  void _navigateToVideo(BilibiliVideo video) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoDetailPage(
          bvid: video.bvid,
          title: video.title,
        ),
      ),
    );
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
}
