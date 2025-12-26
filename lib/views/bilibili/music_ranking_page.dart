import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motto_music/models/bilibili/video.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/services/cache/page_cache_service.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/views/bilibili/video_detail_page.dart';
import 'package:motto_music/widgets/global_top_bar.dart';
import 'package:motto_music/widgets/unified_cover_image.dart';
import 'package:motto_music/router/route_observer.dart';

enum MusicZoneBrowseMode {
  /// 自动选择：主分区用 ranking/v2，子分区用 newlist_rank。
  auto,

  /// 分区排行榜：`/x/web-interface/ranking/v2`（仅主分区 rid 有意义）。
  rankingV2,

  /// 分区热榜：`/x/web-interface/newlist_rank`（使用 cate_id，可用于子分区）。
  newListRank,
}

/// B站音乐索引页面
class MusicRankingPage extends StatefulWidget {
  final String title;
  final Color accentColor;
  final int zoneTid;
  final String rankingType;
  final int pageSize;
  final MusicZoneBrowseMode browseMode;

  const MusicRankingPage({
    super.key,
    this.title = '音乐索引',
    this.accentColor = const Color(0xFFE84C4C),
    required this.zoneTid,
    this.rankingType = 'all',
    this.pageSize = 30,
    this.browseMode = MusicZoneBrowseMode.auto,
  });

  @override
  State<MusicRankingPage> createState() => _MusicRankingPageState();
}

class _MusicRankingPageState extends State<MusicRankingPage> with RouteAware {
  late final BilibiliApiService _apiService;
  late final ScrollController _scrollController;
  final PageCacheService _pageCache = PageCacheService();

  final List<BilibiliVideo> _videos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  late final MusicZoneBrowseMode _browseMode;
  late String _filterValue;
  int _page = 1;
  int _loadGeneration = 0;

  static const Map<String, String> _rankingTypeLabels = {
    'all': '综合',
    'rokkie': '新人',
    'origin': '原创',
  };

  static const Map<String, String> _newListOrderLabels = {
    'click': '播放',
    'scores': '评分',
    'stow': '收藏',
    'coin': '投币',
    'dm': '弹幕',
  };

  static const double _topBarBottomHeight = 44.0;

  @override
  void initState() {
    super.initState();
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);
    _scrollController = ScrollController()..addListener(_handleScroll);
    _browseMode = _resolveBrowseMode();
    _filterValue = _browseMode == MusicZoneBrowseMode.rankingV2
        ? widget.rankingType
        : 'click';
    _loadFirstPage();
    GlobalTopBarController.instance.push(_topBarStyle());
  }

  GlobalTopBarStyle _topBarStyle() {
    return GlobalTopBarStyle(
      source: 'music-ranking',
      title: widget.title,
      showBackButton: true,
      centerTitle: true,
      backIconColor: widget.accentColor,
      onBack: () => Navigator.of(context).pop(),
      opacity: 1.0,
      translateY: 0.0,
      bottom: _buildTopBarBottom(),
      showDivider: true,
    );
  }

  Widget _buildTopBarBottom() {
    return Builder(
      builder: (context) {
        final textColor = ThemeUtils.textColor(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SizedBox(
          height: _topBarBottomHeight,
          child: _buildFilters(textColor, isDark),
        );
      },
    );
  }

  void _applyTopBarStyle() {
    GlobalTopBarController.instance.set(_topBarStyle());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // 从子页面返回时，确保恢复统一顶栏样式。
    _applyTopBarStyle();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    GlobalTopBarController.instance.pop();
    super.dispose();
  }

  MusicZoneBrowseMode _resolveBrowseMode() {
    final mode = widget.browseMode;
    if (mode != MusicZoneBrowseMode.auto) return mode;

    // 本页面主要被音乐分区入口调用：tid=3 为主分区，其余为音乐子分区。
    // ranking/v2 接口仅支持主分区，否则大概率返回空列表。
    return widget.zoneTid == 3
        ? MusicZoneBrowseMode.rankingV2
        : MusicZoneBrowseMode.newListRank;
  }

  Future<void> _loadFirstPage() async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _errorMessage = null;
      _page = 1;
    });

    final cacheKey = _cacheKeyForPage(page: 1);
    final cached = await _pageCache.getCachedVideoList(cacheKey);
    final hasCached = cached != null && cached.isNotEmpty;

    if (hasCached && mounted && generation == _loadGeneration) {
      setState(() {
        _videos
          ..clear()
          ..addAll(cached);
        _isLoading = false;
        _hasMore = cached.length >= widget.pageSize;
      });
    }

    try {
      final videos = await _loadPage(page: _page);
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _videos
            ..clear()
            ..addAll(videos);
          _isLoading = false;
          _hasMore = videos.length >= widget.pageSize;
        });
        await _pageCache.cacheVideoList(cacheKey, videos, ttl: _cacheTtl);
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          if (!hasCached) {
            _errorMessage = '加载失败: $e';
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<List<BilibiliVideo>> _loadPage({required int page}) async {
    if (_browseMode == MusicZoneBrowseMode.rankingV2) {
      return _apiService.getZoneRankingV2(
        rid: widget.zoneTid,
        type: _filterValue,
        page: page,
        pageSize: widget.pageSize,
      );
    }

    return _apiService.getZoneRankList(
      cateId: widget.zoneTid,
      order: _filterValue,
      page: page,
      pageSize: widget.pageSize,
    );
  }

  String _cacheKeyForPage({required int page}) {
    final modeKey = _browseMode == MusicZoneBrowseMode.rankingV2
        ? 'ranking_v2'
        : 'newlist_rank';
    return 'music_zone:$modeKey:tid=${widget.zoneTid}:filter=$_filterValue:page=$page:pageSize=${widget.pageSize}';
  }

  Duration get _cacheTtl {
    return _browseMode == MusicZoneBrowseMode.rankingV2
        ? const Duration(hours: 1)
        : const Duration(minutes: 30);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 800) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    final generation = _loadGeneration;
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _page + 1;
      final cacheKey = _cacheKeyForPage(page: nextPage);
      final cached = await _pageCache.getCachedVideoList(cacheKey);
      if (!mounted || generation != _loadGeneration) return;
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _page = nextPage;
          _videos.addAll(cached);
          _isLoadingMore = false;
          _hasMore = cached.length >= widget.pageSize;
        });
        return;
      }

      final videos = await _loadPage(page: nextPage);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _page = nextPage;
        _videos.addAll(videos);
        _isLoadingMore = false;
        _hasMore = videos.length >= widget.pageSize;
      });
      await _pageCache.cacheVideoList(cacheKey, videos, ttl: _cacheTtl);
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  String get _filterLabel {
    if (_browseMode == MusicZoneBrowseMode.rankingV2) {
      return _rankingTypeLabels[_filterValue] ?? _filterValue;
    }
    return _newListOrderLabels[_filterValue] ?? _filterValue;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = ThemeUtils.backgroundColor(context);
    final textColor = ThemeUtils.textColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    const topBarHeight = 52.0;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          SizedBox(
            height: topPadding + topBarHeight + _topBarBottomHeight + 1,
          ),
          Expanded(
            child: _buildContent(textColor, isDark),
          ),
        ],
      ),
    );
  }

  IconData _iconForFilterKey(String key) {
    if (_browseMode == MusicZoneBrowseMode.rankingV2) {
      switch (key) {
        case 'all':
          return Icons.grid_view_rounded;
        case 'rokkie':
          return Icons.fiber_new_rounded;
        case 'origin':
          return Icons.auto_awesome_rounded;
      }
      return Icons.local_fire_department_rounded;
    }

    switch (key) {
      case 'click':
        return Icons.play_arrow_rounded;
      case 'scores':
        return Icons.star_rounded;
      case 'stow':
        return Icons.bookmark_rounded;
      case 'coin':
        return Icons.monetization_on_rounded;
      case 'dm':
        return Icons.chat_bubble_rounded;
    }
    return Icons.sort_rounded;
  }

  Widget _buildFilters(Color textColor, bool isDark) {
    final modeLabel = _browseMode == MusicZoneBrowseMode.rankingV2 ? 'TOP100' : '热榜';
    return Padding(
      // 顶栏 bottom 区域固定高度为 44：这里的上下内边距必须收敛，否则会导致按钮被裁切。
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              '$modeLabel · $_filterLabel',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.78),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<String>(
            initialValue: _filterValue,
            onSelected: (value) {
              if (value == _filterValue) return;
              setState(() {
                _filterValue = value;
              });
              _applyTopBarStyle();
              _loadFirstPage();
            },
            itemBuilder: (context) {
              final entries = _browseMode == MusicZoneBrowseMode.rankingV2
                  ? _rankingTypeLabels.entries
                  : _newListOrderLabels.entries;
              return entries
                  .map(
                    (e) => PopupMenuItem<String>(
                      value: e.key,
                      child: Row(
                        children: [
                          Icon(_iconForFilterKey(e.key), size: 18),
                          const SizedBox(width: 10),
                          Text(e.value),
                        ],
                      ),
                    ),
                  )
                  .toList();
            },
            child: _buildFilterChip(
              icon: Icons.filter_list_rounded,
              label: _browseMode == MusicZoneBrowseMode.rankingV2 ? '类型' : '排序',
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final borderColor = Colors.black.withValues(alpha: isDark ? 0.22 : 0.12);
    final background = Colors.black.withValues(alpha: isDark ? 0.18 : 0.04);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color textColor, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFirstPage,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_videos.isEmpty) {
      return const Center(
        child: Text(
          '暂无内容',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 20,
          childAspectRatio: 0.70,
        ),
        itemCount: _videos.length + (_isLoadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= _videos.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildGridItem(_videos[index], index, textColor, isDark);
        },
      ),
    );
  }

  Widget _buildGridItem(BilibiliVideo video, int index, Color textColor, bool isDark) {
    final isFeatured = index < 2;
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          NamidaPageRoute(
            page: VideoDetailPage(bvid: video.bvid),
            type: PageTransitionType.slideUp,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: _buildCoverCard(video.pic, isDark, isFeatured),
          ),
          const SizedBox(height: 8),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            video.owner.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverCard(String imageUrl, bool isDark, bool showAvatars) {
    final borderColor = Colors.black.withValues(alpha: isDark ? 0.18 : 0.12);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return UnifiedCoverImage(
                  coverPath: imageUrl,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  borderRadius: 0,
                  fit: BoxFit.cover,
                  isDark: isDark,
                  placeholder: Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Icon(
                      Icons.music_note,
                      color: Colors.grey,
                      size: 24,
                    ),
                  ),
                  errorWidget: Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 0.8),
              ),
            ),
          ),
          if (showAvatars)
            Positioned(
              right: 8,
              bottom: 8,
              child: _buildAvatarStack(imageUrl, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack(String imageUrl, bool isDark) {
    const double size = 28;
    const double overlap = 14;

    return SizedBox(
      width: size + overlap * 2,
      height: size,
      child: Stack(
        children: [
          _buildAvatar(imageUrl, 0, size, isDark),
          _buildAvatar(imageUrl, overlap, size, isDark),
          _buildAvatar(imageUrl, overlap * 2, size, isDark),
        ],
      ),
    );
  }

  Widget _buildAvatar(String imageUrl, double left, double size, bool isDark) {
    return Positioned(
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white,
            width: 1,
          ),
        ),
        child: ClipOval(
          child: UnifiedCoverImage(
            coverPath: imageUrl,
            width: size,
            height: size,
            borderRadius: 0,
            fit: BoxFit.cover,
            isDark: isDark,
            placeholder: Container(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            errorWidget: Container(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
          ),
        ),
      ),
    );
  }
}
