import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:motto_music/models/bilibili/video.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/views/bilibili/video_detail_page.dart';
import 'package:motto_music/widgets/global_top_bar.dart';

/// B站音乐索引页面
class MusicRankingPage extends StatefulWidget {
  final String title;
  final Color accentColor;
  final int zoneTid;
  final String rankingType;
  final int pageSize;

  const MusicRankingPage({
    super.key,
    this.title = '音乐索引',
    this.accentColor = const Color(0xFFE84C4C),
    required this.zoneTid,
    this.rankingType = 'all',
    this.pageSize = 30,
  });

  @override
  State<MusicRankingPage> createState() => _MusicRankingPageState();
}

class _MusicRankingPageState extends State<MusicRankingPage> {
  late final BilibiliApiService _apiService;
  late final ScrollController _scrollController;

  final List<BilibiliVideo> _videos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  late String _rankingType;
  int _page = 1;

  static const Map<String, String> _rankingTypeLabels = {
    'all': '综合',
    'rokkie': '新人',
    'origin': '原创',
  };

  @override
  void initState() {
    super.initState();
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);
    _scrollController = ScrollController()..addListener(_handleScroll);
    _rankingType = widget.rankingType;
    _loadFirstPage();
    GlobalTopBarController.instance.push(
      GlobalTopBarStyle(
        source: 'detail',
        title: widget.title,
        showBackButton: true,
        centerTitle: true,
        backIconColor: widget.accentColor,
        onBack: () => Navigator.of(context).pop(),
        opacity: 1.0,
        translateY: 0.0,
        showDivider: true,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    GlobalTopBarController.instance.pop();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _errorMessage = null;
      _page = 1;
    });

    try {
      final videos = await _apiService.getZoneRankingV2(
        rid: widget.zoneTid,
        type: _rankingType,
        page: _page,
        pageSize: widget.pageSize,
      );
      if (mounted) {
        setState(() {
          _videos
            ..clear()
            ..addAll(videos);
          _isLoading = false;
          _hasMore = videos.length >= widget.pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载失败: $e';
          _isLoading = false;
        });
      }
    }
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
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _page + 1;
      final videos = await _apiService.getZoneRankingV2(
        rid: widget.zoneTid,
        type: _rankingType,
        page: nextPage,
        pageSize: widget.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _videos.addAll(videos);
        _isLoadingMore = false;
        _hasMore = videos.length >= widget.pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  String get _rankingTypeLabel => _rankingTypeLabels[_rankingType] ?? _rankingType;

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
          SizedBox(height: topPadding + topBarHeight + 1),
          _buildFilters(textColor, isDark),
          Expanded(
            child: _buildContent(textColor, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(Color textColor, bool isDark) {
    final dividerColor = Colors.black.withValues(alpha: isDark ? 0.15 : 0.08);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor, width: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'TOP100 · $_rankingTypeLabel',
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
            initialValue: _rankingType,
            onSelected: (value) {
              if (value == _rankingType) return;
              setState(() {
                _rankingType = value;
              });
              _loadFirstPage();
            },
            itemBuilder: (context) {
              return _rankingTypeLabels.entries
                  .map(
                    (e) => PopupMenuItem<String>(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList();
            },
            child: _buildFilterChip(
              icon: Icons.filter_list_rounded,
              label: '类型',
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
          childAspectRatio: 0.75,
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
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: const Icon(Icons.music_note, color: Colors.grey, size: 24),
              ),
              errorWidget: (context, url, error) => Container(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey, size: 24),
              ),
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
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            errorWidget: (context, url, error) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
          ),
        ),
      ),
    );
  }
}
