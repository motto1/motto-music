import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/main.dart';
import 'package:motto_music/models/bilibili/collection.dart';
import 'package:motto_music/models/bilibili/video.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/services/cache/page_cache_service.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/views/bilibili/collection_detail_page.dart';
import 'package:motto_music/views/bilibili/uploader_song_ranking_page.dart';
import 'package:motto_music/views/bilibili/video_detail_page.dart';
import 'package:motto_music/widgets/apple_music_song_tile.dart';
import 'package:motto_music/widgets/global_top_bar.dart';
import 'package:motto_music/widgets/unified_cover_image.dart';

/// 制作人员 / 作者页面（基于 Bilibili UP 主）
///
/// 目标：复刻参考图的交互与布局：
/// - 顶部大封面 + 名称
/// - 名称位置的「歌曲/专辑」切换
/// - 歌曲=视频列表，专辑=合集列表
/// - 使用统一顶栏，滚动时背景淡入，切换控件上移到顶栏
class UserVideosPage extends StatefulWidget {
  final int mid;
  final String userName;
  final String? userAvatar;

  const UserVideosPage({
    super.key,
    required this.mid,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<UserVideosPage> createState() => _UserVideosPageState();
}

class _UserVideosPageState extends State<UserVideosPage> {
  static const double _heroHeight = 380.0;
  static const double _collapseDistance = 220.0;
  static const double _topBarBottomHeight = 44.0;
  static const Color _accentColor = Color(0xFFE84C4C);

  late final BilibiliApiService _apiService;
  final PageCacheService _pageCache = PageCacheService();

  late final ScrollController _scrollController;
  double _collapseProgress = 0.0;

  // tab: 0 = 歌曲(视频), 1 = 专辑(合集)
  int _selectedTab = 0;

  // 视频
  bool _isLoadingVideos = false;
  List<BilibiliVideo>? _videos;
  String? _videosError;
  int _currentVideoPage = 1;
  bool _hasMoreVideos = true;

  // 合集
  bool _isLoadingCollections = false;
  List<BilibiliCollection>? _collections;
  String? _collectionsError;

  // 动态加载的用户信息
  String? _loadedUserName;
  String? _loadedUserAvatar;

  String _cacheKeyForVideoPage(int page) => 'uploader_${widget.mid}_page_$page';

  String get _displayName => _loadedUserName ?? widget.userName;

  String? get _displayAvatar => _loadedUserAvatar ?? widget.userAvatar;

  @override
  void initState() {
    super.initState();

    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);

    _scrollController = ScrollController()..addListener(_handleScroll);

    _loadCachedVideos();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GlobalTopBarController.instance.push(_topBarStyle(progress: 0.0));
      if (widget.userName == 'UP主' || widget.userAvatar == null) {
        _loadUserInfo();
      }
      _loadVideos();
      _loadCollections();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    GlobalTopBarController.instance.pop();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final progress = (_scrollController.offset / _collapseDistance)
        .clamp(0.0, 1.0);
    if ((progress - _collapseProgress).abs() < 0.01) return;

    if (mounted) {
      setState(() {
        _collapseProgress = progress;
      });
    }

    GlobalTopBarController.instance.set(_topBarStyle(progress: progress));
  }

  Color _topBarIconColor(double backgroundOpacity, bool isDark) {
    if (backgroundOpacity < 0.25) {
      return Colors.white;
    }
    return _accentColor;
  }

  GlobalTopBarStyle _topBarStyle({required double progress}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundOpacity = Curves.easeOutCubic.transform(
      ((progress - 0.06) / 0.54).clamp(0.0, 1.0),
    );
    final titleOpacity = Curves.easeOutCubic.transform(
      ((progress - 0.18) / 0.52).clamp(0.0, 1.0),
    );
    final bottomOpacity = Curves.easeOutCubic.transform(
      ((progress - 0.22) / 0.42).clamp(0.0, 1.0),
    );
    final iconColor = _topBarIconColor(backgroundOpacity, isDark);

    return GlobalTopBarStyle(
      source: 'uploader',
      title: _displayName,
      showBackButton: true,
      centerTitle: false,
      backIconColor: iconColor,
      onBack: _handleBack,
      // 关键：顶栏内容始终可见，背景随滚动淡入。
      opacity: 1.0,
      contentOpacity: 1.0,
      backgroundOpacity: backgroundOpacity,
      titleOpacity: titleOpacity,
      titleTranslateY: (1 - titleOpacity) * 6,
      translateY: 0.0,
      showDivider: backgroundOpacity > 0.7,
      trailing: _buildTopBarTrailing(iconColor),
      bottom: SizedBox(
        height: _topBarBottomHeight,
        child: Opacity(
          opacity: bottomOpacity,
          child: _buildSwitchControl(
            overImage: false,
            isDark: isDark,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBarTrailing(Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '收藏',
          onPressed: () {},
          icon: Icon(Icons.star_border_rounded, color: iconColor, size: 22),
        ),
        IconButton(
          tooltip: '更多',
          onPressed: () {},
          icon: Icon(Icons.more_vert_rounded, color: iconColor, size: 22),
        ),
      ],
    );
  }

  void _handleBack() {
    final playerKey = GlobalPlayerManager.playerKey;
    final playerState = playerKey?.currentState;
    final percentage = playerState?.percentage ?? -1;

    if (playerState != null && percentage >= 0.9) {
      playerState.animateToState(false);
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _loadCachedVideos() async {
    final cached = await _pageCache.getCachedVideoList(_cacheKeyForVideoPage(1));
    if (!mounted || cached == null || cached.isEmpty) return;
    setState(() {
      _videos = cached;
      _isLoadingVideos = false;
      _currentVideoPage = 1;
      _hasMoreVideos = cached.length >= 30;
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      final userInfo = await _apiService.getUserInfo(widget.mid);
      if (!mounted) return;
      setState(() {
        _loadedUserName = userInfo.name;
        _loadedUserAvatar = userInfo.face;
      });

      // 同步刷新顶栏标题（保持 source 不变）。
      GlobalTopBarController.instance.set(_topBarStyle(progress: _collapseProgress));
    } catch (_) {
      // ignore: 用户信息失败不阻塞主流程
    }
  }

  Future<void> _loadCollections() async {
    if (_isLoadingCollections) return;
    setState(() {
      _isLoadingCollections = true;
      _collectionsError = null;
    });

    try {
      final raw = await _apiService.getUploaderSeasons(widget.mid);
      final collections = raw
          .whereType<Map<String, dynamic>>()
          .map(BilibiliCollection.fromJson)
          .where((e) => e.id != 0)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _collections = collections;
        _isLoadingCollections = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _collectionsError = e.toString();
        _isLoadingCollections = false;
      });
    }
  }

  Future<void> _loadVideos({bool loadMore = false}) async {
    if (_isLoadingVideos) return;
    if (loadMore && !_hasMoreVideos) return;

    setState(() {
      _isLoadingVideos = true;
      _videosError = null;
    });

    try {
      final page = loadMore ? _currentVideoPage + 1 : 1;
      final videos = await _apiService.getUploaderVideos(
        mid: widget.mid,
        page: page,
        pageSize: 30,
      );

      await _pageCache.cacheVideoList(_cacheKeyForVideoPage(page), videos);

      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _videos = [...?_videos, ...videos];
          _currentVideoPage = page;
        } else {
          _videos = videos;
          _currentVideoPage = 1;
        }
        _hasMoreVideos = videos.length >= 30;
        _isLoadingVideos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingVideos = false;
        _videosError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: ThemeUtils.backgroundColor(context),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (notification) {
            notification.disallowIndicator();
            return true;
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeroHeader(isDark: isDark),
              ),
              ..._buildTabContentSlivers(isDark: isDark),
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 160),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader({required bool isDark}) {
    final avatar = _displayAvatar;
    final name = _displayName;

    final headerSwitchOpacity = (1.0 - Curves.easeOutCubic.transform(
      ((_collapseProgress - 0.16) / 0.52).clamp(0.0, 1.0),
    ));

    return SizedBox(
      height: _heroHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: avatar == null || avatar.isEmpty
                ? Container(
                    color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                  )
                : UnifiedCoverImage(
                    coverPath: avatar,
                    width: MediaQuery.of(context).size.width,
                    height: _heroHeight,
                    borderRadius: 0,
                    fit: BoxFit.cover,
                    isDark: isDark,
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                Opacity(
                  opacity: headerSwitchOpacity,
                  child: _buildSwitchControl(overImage: true, isDark: isDark),
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: 64,
            child: _buildPlayButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    final enabled = _videos != null && _videos!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => _navigateToVideo(_videos!.first) : null,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _accentColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: Colors.white.withValues(alpha: enabled ? 1.0 : 0.6),
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchControl({required bool overImage, required bool isDark}) {
    final baseBg = overImage
        ? Colors.white.withValues(alpha: isDark ? 0.10 : 0.18)
        : Colors.black.withValues(alpha: isDark ? 0.22 : 0.05);
    final borderColor = overImage
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: isDark ? 0.25 : 0.10);

    final selectedBg = overImage
        ? Colors.white.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: isDark ? 0.22 : 0.06);

    final selectedText = overImage ? Colors.white : ThemeUtils.textColor(context);
    final unselectedText = overImage
        ? Colors.white.withValues(alpha: 0.7)
        : ThemeUtils.textColor(context).withValues(alpha: 0.75);

    final child = Container(
      height: 34,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: baseBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSwitchItem(
            label: '歌曲',
            selected: _selectedTab == 0,
            selectedBg: selectedBg,
            selectedText: selectedText,
            unselectedText: unselectedText,
            onTap: () => _selectTab(0),
          ),
          _buildSwitchItem(
            label: '专辑',
            selected: _selectedTab == 1,
            selectedBg: selectedBg,
            selectedText: selectedText,
            unselectedText: unselectedText,
            onTap: () => _selectTab(1),
          ),
        ],
      ),
    );

    if (!overImage) {
      return child;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: child,
      ),
    );
  }

  Widget _buildSwitchItem({
    required String label,
    required bool selected,
    required Color selectedBg,
    required Color selectedText,
    required Color unselectedText,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? selectedText : unselectedText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    if (_selectedTab == index) return;
    setState(() {
      _selectedTab = index;
    });

    // 切换后立即刷新顶栏 bottom 的选中态。
    GlobalTopBarController.instance.set(_topBarStyle(progress: _collapseProgress));

    // 专辑页签首次切换时，确保已加载。
    if (index == 1 && _collections == null && !_isLoadingCollections) {
      _loadCollections();
    }
  }

  List<Widget> _buildTabContentSlivers({required bool isDark}) {
    return _selectedTab == 0
        ? _buildSongsSlivers(isDark: isDark)
        : _buildAlbumsSlivers(isDark: isDark);
  }

  List<Widget> _buildSongsSlivers({required bool isDark}) {
    final collections = _collections;

    return [
      if (collections != null && collections.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _buildFeaturedCollection(collections.first, isDark: isDark),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: InkWell(
            onTap: _openSongRankingPage,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '歌曲排行',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: ThemeUtils.textColor(context).withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ..._buildSongRankingPreviewSlivers(isDark: isDark),
    ];
  }

  Widget _buildFeaturedCollection(BilibiliCollection collection, {required bool isDark}) {
    final textColor = ThemeUtils.textColor(context);
    final borderColor = Colors.black.withValues(alpha: isDark ? 0.22 : 0.10);
    final bg = Colors.black.withValues(alpha: isDark ? 0.18 : 0.03);

    return InkWell(
      onTap: () => _openCollection(collection),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: UnifiedCoverImage(
                coverPath: collection.cover,
                width: 64,
                height: 64,
                borderRadius: 0,
                fit: BoxFit.cover,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${collection.mediaCount} 个内容',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, size: 18, color: _accentColor),
                  SizedBox(width: 4),
                  Text(
                    '添加',
                    style: TextStyle(
                      color: _accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSongRankingPage() {
    Navigator.of(context).push(
      NamidaPageRoute(
        page: UploaderSongRankingPage(
          mid: widget.mid,
          artistName: _displayName,
        ),
        type: PageTransitionType.slideLeft,
      ),
    );
  }

  List<Widget> _buildSongRankingPreviewSlivers({required bool isDark}) {
    if (_videos == null && _isLoadingVideos) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }

    if (_videos == null && _videosError != null) {
      return [
        SliverToBoxAdapter(
          child: _buildErrorView(message: _videosError!, onRetry: _loadVideos),
        ),
      ];
    }

    final videos = _videos ?? const <BilibiliVideo>[];
    if (videos.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '暂无内容',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ),
        ),
      ];
    }

    const maxPreviewCount = 4;
    final previewCount = videos.length < maxPreviewCount ? videos.length : maxPreviewCount;
    final dividerColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10);

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final video = videos[index];
            return Column(
              children: [
                AppleMusicSongTile(
                  title: video.title,
                  artist: _songSubtitleFor(video),
                  coverUrl: video.pic,
                  onTap: () => _navigateToVideo(video),
                  onMoreTap: () => _showVideoMenu(video, isDark: isDark),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: ThemeUtils.textColor(context).withValues(alpha: 0.5),
                      size: 22,
                    ),
                    onPressed: () => _showVideoMenu(video, isDark: isDark),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
                if (index != previewCount - 1)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 88,
                    endIndent: 16,
                    color: dividerColor,
                  ),
              ],
            );
          },
          childCount: previewCount,
        ),
      ),
    ];
  }

  String _songSubtitleFor(BilibiliVideo video) {
    if (video.pubdate <= 0) return _displayName;
    final year = DateTime.fromMillisecondsSinceEpoch(video.pubdate * 1000).year;
    return '$_displayName · $year年';
  }

  Future<void> _showVideoMenu(BilibiliVideo video, {required bool isDark}) async {
    final textColor = ThemeUtils.textColor(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ThemeUtils.backgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    UnifiedCoverImage(
                      coverPath: video.pic,
                      width: 48,
                      height: 48,
                      borderRadius: 8,
                      fit: BoxFit.cover,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _songSubtitleFor(video),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('打开详情'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToVideo(video);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('复制 BV 号'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: video.bvid));
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('已复制 BV 号')),
                  );
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildAlbumsSlivers({required bool isDark}) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            '专辑',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: ThemeUtils.textColor(context),
            ),
          ),
        ),
      ),
      if (_collections == null && _isLoadingCollections)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_collections == null && _collectionsError != null)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildErrorView(
            message: _collectionsError!,
            onRetry: _loadCollections,
          ),
        )
      else
        _buildCollectionsGrid(isDark: isDark),
    ];
  }

  Widget _buildCollectionsGrid({required bool isDark}) {
    final collections = _collections ?? const <BilibiliCollection>[];
    if (collections.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            '暂无专辑',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final collection = collections[index];
            return _buildCollectionCard(collection, isDark: isDark);
          },
          childCount: collections.length,
        ),
      ),
    );
  }

  Widget _buildCollectionCard(BilibiliCollection collection, {required bool isDark}) {
    final textColor = ThemeUtils.textColor(context);
    return InkWell(
      onTap: () => _openCollection(collection),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: UnifiedCoverImage(
                coverPath: collection.cover,
                width: double.infinity,
                height: double.infinity,
                borderRadius: 0,
                fit: BoxFit.cover,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            collection.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${collection.mediaCount} 个内容',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView({required String message, required VoidCallback onRetry}) {
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
            const SizedBox(height: 12),
            const Text('加载失败', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  void _openCollection(BilibiliCollection collection) {
    Navigator.of(context).push(
      NamidaPageRoute(
        page: CollectionDetailPage(
          collectionId: collection.id,
          mid: widget.mid,
          title: collection.title,
        ),
        type: PageTransitionType.slideLeft,
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

}
