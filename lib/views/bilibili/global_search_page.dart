import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:motto_music/models/bilibili/search_strategy.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/services/bilibili/url_parser_service.dart';
import 'package:motto_music/views/bilibili/global_search_result_page.dart';
import 'package:motto_music/views/bilibili/music_ranking_page.dart';
import 'package:motto_music/views/bilibili/video_detail_page.dart';
import 'package:motto_music/views/bilibili/favorite_detail_page.dart';
import 'package:motto_music/views/bilibili/collection_detail_page.dart';
import 'package:motto_music/views/bilibili/user_videos_page.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/widgets/show_aware_page.dart';
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/widgets/apple_music_card.dart';
import 'package:motto_music/widgets/unified_cover_image.dart';
import 'package:motto_music/widgets/global_top_bar.dart';
import 'package:motto_music/router/route_observer.dart';
import 'package:motto_music/widgets/motto_search_field.dart';

class _SearchCategory {
  final String title;
  final int tid;
  final Color overlayColor;
  final String? coverUrl;

  const _SearchCategory({
    required this.title,
    required this.tid,
    required this.overlayColor,
    this.coverUrl,
  });

  _SearchCategory copyWith({String? coverUrl}) {
    return _SearchCategory(
      title: title,
      tid: tid,
      overlayColor: overlayColor,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }
}

class _SearchCategoryGroup {
  final String title;
  final List<_SearchCategory> categories;

  const _SearchCategoryGroup({
    required this.title,
    required this.categories,
  });

  _SearchCategoryGroup copyWith({List<_SearchCategory>? categories}) {
    return _SearchCategoryGroup(
      title: title,
      categories: categories ?? this.categories,
    );
  }
}

class _MusicZoneSpec {
  final String title;
  final int tid;

  const _MusicZoneSpec(this.title, this.tid);
}

/// 全局智能搜索页面
/// 
/// 支持多种输入格式：
/// - BV号: BV1xx4y1x7xx
/// - AV号: av12345678
/// - b23.tv短链: https://b23.tv/xxxxx
/// - 完整URL: 收藏夹/合集/UP主链接
/// - 关键词: 任意搜索词
class GlobalSearchPage extends StatefulWidget {
  final String? initialQuery;
  
  const GlobalSearchPage({super.key, this.initialQuery});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage>
    with ShowAwarePage, RouteAware {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late final BilibiliUrlParserService _urlParser;
  late final BilibiliApiService _apiService;
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _isLoadingCategories = false;
  bool _categoriesLoaded = false;
  late List<_SearchCategoryGroup> _categoryGroups;
  final Map<int, String?> _categoryCoverCache = {};
  double _collapseProgress = 0.0;
  bool _didOpenInitialQuery = false;

  static const Color _accentColor = Color(0xFFE84C4C);
  static const double _collapseDistance = 64.0;

  static const List<Color> _categoryPalette = [
    Color(0xFFE35C84),
    Color(0xFFE0617F),
    Color(0xFF8C842C),
    Color(0xFF7A4F2E),
    Color(0xFF5F7FCA),
    Color(0xFF2A2A2A),
    Color(0xFF9A5AC7),
    Color(0xFF5A6AC7),
    Color(0xFFCF3C3C),
    Color(0xFF3D6B5C),
    Color(0xFF6B6B6B),
    Color(0xFF4C6A8A),
  ];

  // 来源：video_zone (v1) 文档中的音乐分区 tid 列表
  static const List<_MusicZoneSpec> _musicZoneV1 = [
    _MusicZoneSpec('音乐(主分区)', 3),
    _MusicZoneSpec('原创音乐', 28),
    _MusicZoneSpec('音乐现场', 29),
    _MusicZoneSpec('翻唱', 31),
    _MusicZoneSpec('演奏', 59),
    _MusicZoneSpec('乐评盘点', 243),
    _MusicZoneSpec('VOCALOID·UTAU', 30),
    _MusicZoneSpec('MV', 193),
    _MusicZoneSpec('音乐粉丝饭拍', 266),
    _MusicZoneSpec('AI音乐', 265),
    _MusicZoneSpec('电台', 267),
    _MusicZoneSpec('音乐教学', 244),
    _MusicZoneSpec('音乐综合', 130),
  ];

  @override
  void initState() {
    super.initState();
    
    _searchController = TextEditingController(text: widget.initialQuery);
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
    _categoryGroups = [];
    
    // 初始化服务
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);
    _urlParser = BilibiliUrlParserService(_apiService);

    _loadCategories();
  }

  @override
  void onPageShow() {
    _applyTopBarStyle();
    if (!_categoriesLoaded) {
      _loadCategories();
    }
    // 如果有初始查询，进入搜索页并自动搜索（避免在索引页直接导航/弹窗）
    if (!_didOpenInitialQuery) {
      final initial = widget.initialQuery?.trim();
      if (initial != null && initial.isNotEmpty) {
        _didOpenInitialQuery = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _openSearchPage(initialQuery: initial);
        });
      }
    }
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
    _applyTopBarStyle();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _applyTopBarStyle() {
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final progress = (offset / _collapseDistance).clamp(0.0, 1.0);
    if (_collapseProgress != progress && mounted) {
      setState(() {
        _collapseProgress = progress;
      });
    }
    _applyTopBarStyleWithProgress(progress);
  }

  void _applyTopBarStyleWithProgress(double progress) {
    final barProgress = Curves.easeOutCubic.transform(
      ((progress - 0.08) / 0.72).clamp(0.0, 1.0),
    );
    final titleOpacity = Curves.easeOutCubic.transform(
      ((progress - 0.18) / 0.52).clamp(0.0, 1.0),
    );
    GlobalTopBarController.instance.set(
      GlobalTopBarStyle(
        source: 'global-search',
        title: '搜索',
        showBackButton: false,
        centerTitle: false,
        opacity: barProgress,
        titleOpacity: titleOpacity,
        titleTranslateY: (1 - titleOpacity) * 6,
        translateY: 0.0,
        showDivider: progress > 0.28,
        trailing: _buildTopBarTrailing(),
      ),
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final progress = (_scrollController.offset / _collapseDistance)
        .clamp(0.0, 1.0);
    if ((progress - _collapseProgress).abs() > 0.01) {
      setState(() {
        _collapseProgress = progress;
      });
    }
    _applyTopBarStyleWithProgress(progress);
  }

  Widget _buildTopBarTrailing() {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.more_vert,
          size: 20,
          color: _accentColor,
        ),
        onPressed: () {},
      ),
    );
  }

  /// 处理搜索
  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _errorMessage = '请输入搜索内容';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 匹配搜索策略
      final strategy = await _urlParser.matchSearchStrategy(query);
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        // 根据策略导航
        await _navigateWithStrategy(strategy);
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '搜索失败: $e';
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    if (_isLoadingCategories || _categoriesLoaded) {
      return;
    }

    setState(() {
      _isLoadingCategories = true;
    });

    final groups = _buildMusicZoneGroups();

    if (!mounted) return;
    setState(() {
      _categoryGroups = groups;
    });

    final updated = <_SearchCategoryGroup>[];
    for (final group in groups) {
      final categories = await _loadCategoryCovers(group.categories);
      updated.add(group.copyWith(categories: categories));
    }
    if (!mounted) return;
    setState(() {
      _categoryGroups = updated;
      _isLoadingCategories = false;
      _categoriesLoaded = true;
    });
  }

  List<_SearchCategoryGroup> _buildMusicZoneGroups() {
    final categories = <_SearchCategory>[];
    for (var index = 0; index < _musicZoneV1.length; index++) {
      final zone = _musicZoneV1[index];
      categories.add(
        _SearchCategory(
          title: zone.title,
          tid: zone.tid,
          overlayColor: _categoryPalette[index % _categoryPalette.length],
        ),
      );
    }

    return [
      _SearchCategoryGroup(title: '音乐分区（v1）', categories: categories),
    ];
  }

  Future<List<_SearchCategory>> _loadCategoryCovers(
    List<_SearchCategory> source,
  ) async {
    if (source.isEmpty) return const [];
    final results = source.toList(growable: false);

    var nextIndex = 0;
    final workers = <Future<void>>[];
    final concurrency = source.length < 4 ? source.length : 4;

    Future<void> worker() async {
      while (true) {
        final current = nextIndex++;
        if (current >= source.length) return;
        final category = source[current];

        if (_categoryCoverCache.containsKey(category.tid)) {
          results[current] =
              category.copyWith(coverUrl: _categoryCoverCache[category.tid]);
          continue;
        }

        String? coverUrl;
        try {
          final list = await _apiService.getZoneRankList(
            cateId: category.tid,
            order: 'click',
            page: 1,
            pageSize: 1,
          );
          if (list.isNotEmpty && list.first.pic.isNotEmpty) {
            coverUrl = list.first.pic;
          }
        } catch (_) {
          coverUrl = null;
        }

        _categoryCoverCache[category.tid] = coverUrl;
        results[current] = category.copyWith(coverUrl: coverUrl);
      }
    }

    for (var i = 0; i < concurrency; i++) {
      workers.add(worker());
    }
    await Future.wait(workers);

    return results;
  }

  /// 根据搜索策略导航到对应页面
  Future<void> _navigateWithStrategy(SearchStrategy strategy) async {
    debugPrint('导航策略: ${strategy.type}, bvid=${strategy.bvid}, id=${strategy.id}, mid=${strategy.mid}');
    
    if (!mounted) {
      debugPrint('组件已卸载，取消导航');
      return;
    }

    switch (strategy.type) {
      case SearchStrategyType.bvid:
        // 跳转到视频详情页
        if (strategy.bvid != null) {
          debugPrint('导航到视频详情页: ${strategy.bvid}');
          await Navigator.of(context).push(
            NamidaPageRoute(
              page: VideoDetailPage(
                bvid: strategy.bvid!,
                title: '视频详情',
              ),
              type: PageTransitionType.slideLeft,
            ),
          );
        } else {
          debugPrint('BV号为空，无法导航');
        }
        break;
        
      case SearchStrategyType.favorite:
        // 跳转到收藏夹详情页
        if (strategy.id != null) {
          final favoriteId = int.tryParse(strategy.id!);
          if (favoriteId != null) {
            debugPrint('导航到收藏夹详情页: $favoriteId');
            await Navigator.of(context).push(
              NamidaPageRoute(
                page: FavoriteDetailPage(
                  favoriteId: favoriteId,
                  title: '收藏夹',
                ),
                type: PageTransitionType.slideLeft,
              ),
            );
          } else {
            debugPrint('收藏夹ID解析失败: ${strategy.id}');
            _showMessage('收藏夹ID格式错误');
          }
        } else {
          debugPrint('收藏夹ID为空，无法导航');
        }
        break;
        
      case SearchStrategyType.collection:
        // 跳转到合集详情页
        if (strategy.id != null) {
          final collectionId = int.tryParse(strategy.id!);
          final mid = strategy.mid != null ? int.tryParse(strategy.mid!) : null;
          
          if (collectionId != null) {
            debugPrint('导航到合集详情页: collectionId=$collectionId, mid=$mid');
            await Navigator.of(context).push(
              NamidaPageRoute(
                page: CollectionDetailPage(
                  collectionId: collectionId,
                  mid: mid,
                  title: '合集',
                ),
                type: PageTransitionType.slideLeft,
              ),
            );
          } else {
            debugPrint('合集ID解析失败: ${strategy.id}');
            _showMessage('合集ID格式错误');
          }
        } else {
          debugPrint('合集ID为空，无法导航');
          _showMessage('无法获取合集信息');
        }
        break;
        
      case SearchStrategyType.uploader:
        // 跳转到UP主页面
        if (strategy.mid != null) {
          final mid = int.tryParse(strategy.mid!);
          if (mid != null) {
            debugPrint('导航到UP主页面: mid=$mid');
            await Navigator.of(context).push(
              NamidaPageRoute(
                page: UserVideosPage(
                  mid: mid,
                  userName: 'UP主',  // 默认名称，页面内会加载真实信息
                ),
                type: PageTransitionType.slideLeft,
              ),
            );
          } else {
            debugPrint('UP主ID解析失败: ${strategy.mid}');
            _showMessage('UP主ID格式错误');
          }
        } else {
          debugPrint('UP主ID为空，无法导航');
          _showMessage('无法获取UP主信息');
        }
        break;
        
      case SearchStrategyType.search:
        if (strategy.query != null && strategy.query!.trim().isNotEmpty) {
          _openSearchPage(initialQuery: strategy.query!.trim());
        }
        break;
        
      case SearchStrategyType.b23ResolveError:
        _showMessage('b23.tv短链解析失败: ${strategy.error}');
        break;
        
      case SearchStrategyType.b23NoBvidError:
        _showMessage('短链解析成功，但未找到可识别内容\n解析结果: ${strategy.resolvedUrl}');
        break;
        
      case SearchStrategyType.avParseError:
        _showMessage('AV号解析失败');
        break;
        
      case SearchStrategyType.invalidUrlNoCtype:
        _showMessage('链接缺少必要参数，请检查是否复制完整');
        break;
    }
  }

  /// 显示消息提示
  void _showMessage(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white.withOpacity(0.9),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isDark 
            ? const Color(0xFF2C2C2E).withOpacity(0.95)
            : const Color(0xFF3A3A3C).withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 3),
        elevation: 8,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textColor = ThemeUtils.textColor(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: Offset(0, -14 * Curves.easeOutCubic.transform(_collapseProgress)),
            child: Opacity(
              opacity:
                  (1 - Curves.easeOutCubic.transform(_collapseProgress)).clamp(
                0.0,
                1.0,
              ),
              child: Text(
                '搜索',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                  color: textColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSearchField(context),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return MottoSearchField(
      hintText: '艺人、歌曲、歌词以及更多内容',
      onTap: _openSearchPage,
    );
  }

  void _openSearchPage({String? initialQuery}) {
    Navigator.of(context).push(
      NamidaPageRoute(
        page: GlobalSearchResultPage(initialQuery: initialQuery),
        type: PageTransitionType.slideLeft,
      ),
    );
  }

  SliverGrid _buildCategoryGrid(List<_SearchCategory> categories) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.65,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final category = categories[index];
          return _buildCategoryCard(category);
        },
        childCount: categories.length,
      ),
    );
  }

  List<Widget> _buildCategorySections() {
    if (_isLoadingCategories && _categoryGroups.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }

    final slivers = <Widget>[];
    for (final group in _categoryGroups) {
      if (group.categories.isEmpty) continue;
      slivers.add(
        SliverToBoxAdapter(child: _buildCategoryHeader(group.title)),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          sliver: _buildCategoryGrid(group.categories),
        ),
      );
    }

    if (slivers.isEmpty) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                '暂无音乐分区分类',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildCategoryHeader(String title) {
    final textColor = ThemeUtils.textColor(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildCategoryCard(_SearchCategory category) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openCategory(category),
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (category.coverUrl != null)
                Positioned.fill(
                  child: UnifiedCoverImage(
                  coverPath: category.coverUrl!,
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: category.overlayColor.withValues(alpha: 0.6),
                  ),
                  errorWidget: Container(
                    color: category.overlayColor.withValues(alpha: 0.6),
                  ),
                )
              else
                Container(
                  color: category.overlayColor.withValues(alpha: 0.6),
                ),
              Container(
                color: category.overlayColor.withValues(alpha: 0.55),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    category.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCategory(_SearchCategory category) {
    Navigator.of(context).push(
      NamidaPageRoute(
        page: MusicRankingPage(
          title: category.title,
          accentColor: category.overlayColor,
          zoneTid: category.tid,
          rankingType: 'all',
        ),
        type: PageTransitionType.slideLeft,
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final topPadding = MediaQuery.of(context).padding.top;
    const topBarHeight = 52.0;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: ThemeUtils.backgroundColor(context),
      body: _wrapWithoutStretch(
        CustomScrollView(
          key: const PageStorageKey<String>('global_search_scroll'),
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: topPadding + topBarHeight + 1),
            ),
            SliverToBoxAdapter(child: _buildHeader(context)),
            if (_errorMessage != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _buildErrorBanner(),
                ),
              ),
            ..._buildCategorySections(),
            SliverToBoxAdapter(
              child: SizedBox(
                height: (keyboardVisible ? 24.0 : 140.0) + bottomPadding,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建使用说明
  Widget _buildUsageGuide() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white.withOpacity(0.85) : Colors.black87;
    final secondaryColor = isDark ? Colors.white.withOpacity(0.6) : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 20),
          child: Text(
            '支持的输入格式',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: secondaryColor,
              letterSpacing: 0.3,
            ),
          ),
        ),
        _buildHintItem(
          emoji: '🎬',
          title: 'BV / AV 视频号',
          description: '输入 BV1xx4y1x7xx 或 av12345678，直接跳转播放',
          textColor: textColor,
          secondaryColor: secondaryColor,
        ),
        _buildHintItem(
          emoji: '⭐',
          title: '收藏夹 / 合集链接',
          description: '粘贴完整链接，智能识别并打开',
          textColor: textColor,
          secondaryColor: secondaryColor,
        ),
        _buildHintItem(
          emoji: '👤',
          title: 'UP 主主页',
          description: '分享 UP 主链接，查看全部视频',
          textColor: textColor,
          secondaryColor: secondaryColor,
        ),
        _buildHintItem(
          emoji: '🔗',
          title: 'b23.tv 短链',
          description: '自动解析真实目标，支持番剧、视频、收藏夹',
          textColor: textColor,
          secondaryColor: secondaryColor,
        ),
        _buildHintItem(
          emoji: '🔍',
          title: '关键词搜索',
          description: '任意关键词，全站搜索结果',
          textColor: textColor,
          secondaryColor: secondaryColor,
        ),
      ],
    );
  }

  Widget _buildHintItem({
    required String emoji,
    required String title,
    required String description,
    required Color textColor,
    required Color secondaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryColor,
                    height: 1.4,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF3A2A2A).withOpacity(0.5)
            : const Color(0xFFFFE5E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.red.withOpacity(0.3)
              : Colors.red.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: isDark ? Colors.red.shade300 : Colors.red.shade700,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '搜索失败',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _errorMessage ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark 
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black.withOpacity(0.6),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.red.shade300 : Colors.red.shade700,
              size: 20,
            ),
            onPressed: _handleSearch,
            tooltip: '重试',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
