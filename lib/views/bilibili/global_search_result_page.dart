import 'package:flutter/material.dart';
import 'dart:async';
import 'package:motto_music/models/bilibili/video.dart';
import 'package:motto_music/models/bilibili/search_strategy.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/services/bilibili/url_parser_service.dart';
import 'package:motto_music/views/bilibili/video_detail_page.dart';
import 'package:motto_music/views/bilibili/user_videos_page.dart';
import 'package:motto_music/database/database.dart' as db;
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/utils/bilibili_song_utils.dart';
import 'package:motto_music/services/player_provider.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:motto_music/widgets/apple_music_song_tile.dart';
import 'package:motto_music/services/cache/page_cache_service.dart';
import 'package:motto_music/services/cache/album_art_cache_service.dart';
import 'package:motto_music/views/bilibili/search_strategy_navigator.dart';
import 'package:motto_music/widgets/motto_search_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局搜索结果页
/// 
/// 显示视频搜索结果，支持分页加载
class GlobalSearchResultPage extends StatefulWidget {
  const GlobalSearchResultPage({
    super.key,
    this.initialQuery,
  });

  /// 初始搜索内容（可为空）
  final String? initialQuery;

  @override
  State<GlobalSearchResultPage> createState() => _GlobalSearchResultPageState();
}

class _GlobalSearchResultPageState extends State<GlobalSearchResultPage>
    with SingleTickerProviderStateMixin {
  static const String _recentSearchKey = 'bilibili_global_search_recent';
  static const int _recentSearchMax = 10;

  late final BilibiliApiService _apiService;
  late final BilibiliUrlParserService _urlParser;
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final TabController _tabController;
  final PageCacheService _pageCache = PageCacheService();

  List<String> _recentSearches = const [];
  String _submittedQuery = '';
  List<BilibiliVideo> _videos = [];
  bool _isResolving = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMore = true;
  int _searchGeneration = 0;

  final Map<String, List<BilibiliVideoPage>> _videoPagesCache = {};
  final Set<String> _videoPagesLoading = {};

  String _normalizeQuery(String query) => query.trim().toLowerCase();
  String _cacheKeyForPage(String query, int page) =>
      '${_normalizeQuery(query)}_page_$page';

  List<BilibiliVideoPage>? _cachedPagesFor(BilibiliVideo video) =>
      _videoPagesCache[video.bvid] ?? video.pages;

  bool _isAlbumVideo(BilibiliVideo video) {
    final pages = _cachedPagesFor(video);
    return pages != null && pages.length > 1;
  }

  Future<void> _ensureVideoPages({required List<BilibiliVideo> videos, int limit = 12}) async {
    final pending = <BilibiliVideo>[];
    for (final video in videos) {
      if (video.bvid.isEmpty) continue;
      if (_videoPagesCache.containsKey(video.bvid)) continue;
      if (_videoPagesLoading.contains(video.bvid)) continue;
      pending.add(video);
      if (pending.length >= limit) break;
    }

    if (pending.isEmpty) return;

    _videoPagesLoading.addAll(pending.map((e) => e.bvid));
    if (mounted) setState(() {});

    for (final video in pending) {
      try {
        final pages = await _apiService.getVideoPages(video.bvid);
        _videoPagesCache[video.bvid] = pages;
      } catch (_) {
        _videoPagesCache[video.bvid] = const <BilibiliVideoPage>[];
      } finally {
        _videoPagesLoading.remove(video.bvid);
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void initState() {
    super.initState();
    
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);
    _urlParser = BilibiliUrlParserService(_apiService);

    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _searchFocusNode = FocusNode();
    _searchController.addListener(() {
      if (!mounted) return;
      final text = _searchController.text.trim();
      if (_submittedQuery.isNotEmpty && text != _submittedQuery) {
        _resetSearchState();
        return;
      }
      setState(() {});
    });

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 1) {
        unawaited(_ensureVideoPages(videos: _videos, limit: 12));
      }
    });
    
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    unawaited(_loadRecentSearches());

    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _submitAndSearch(initial);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
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

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentSearchKey) ?? const <String>[];
    if (!mounted) return;
    setState(() {
      _recentSearches = List.unmodifiable(
        list.where((e) => e.trim().isNotEmpty).take(_recentSearchMax),
      );
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;

    final next = <String>[normalized];
    for (final entry in _recentSearches) {
      if (entry == normalized) continue;
      next.add(entry);
      if (next.length >= _recentSearchMax) break;
    }

    setState(() => _recentSearches = List.unmodifiable(next));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchKey, next);
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches = const []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchKey);
  }

  bool _isStrategyError(SearchStrategyType type) {
    return type == SearchStrategyType.b23ResolveError ||
        type == SearchStrategyType.b23NoBvidError ||
        type == SearchStrategyType.avParseError ||
        type == SearchStrategyType.invalidUrlNoCtype;
  }

  void _resetSearchState() {
    setState(() {
      _submittedQuery = '';
      _videos = [];
      _videoPagesCache.clear();
      _videoPagesLoading.clear();
      _isLoading = false;
      _isLoadingMore = false;
      _errorMessage = null;
      _currentPage = 1;
      _hasMore = true;
    });
  }

  Future<void> _submitAndSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _searchController.text = trimmed;
    _searchController.selection = TextSelection.collapsed(offset: trimmed.length);
    await _handleSubmitted();
  }

  Future<void> _handleSubmitted() async {
    final input = _searchController.text.trim();
    if (input.isEmpty) {
      _resetSearchState();
      return;
    }

    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    try {
      final strategy = await _urlParser.matchSearchStrategy(input);
      if (!mounted) return;

      setState(() => _isResolving = false);

      if (!_isStrategyError(strategy.type)) {
        unawaited(_saveRecentSearch(input));
      }

      if (strategy.type == SearchStrategyType.search) {
        final query = (strategy.query ?? input).trim();
        FocusScope.of(context).unfocus();
        await _loadSearchResults(query);
        return;
      }

      await navigateBySearchStrategy(
        context,
        strategy,
        showMessage: _showMessage,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResolving = false;
        _errorMessage = '搜索失败: $e';
      });
    }
  }

  /// 加载搜索结果（首页）
  Future<void> _loadSearchResults([String? query]) async {
    final normalized = (query ?? _submittedQuery).trim();
    if (normalized.isEmpty) return;

    final generation = ++_searchGeneration;
    setState(() {
      _submittedQuery = normalized;
      _isLoading = _videos.isEmpty || query != null;
      _isLoadingMore = false;
      _errorMessage = null;
      _currentPage = 1;
      _hasMore = true;
      if (query != null) _videos = [];
    });
    _tabController.animateTo(0);

    final cached = await _pageCache.getCachedSearchResults(
      _cacheKeyForPage(normalized, 1),
    );
    if (mounted && generation == _searchGeneration && cached != null) {
      if (cached.isNotEmpty) {
        setState(() {
          _videos = cached;
          _isLoading = false;
          _hasMore = cached.length >= 20;
        });
        unawaited(_ensureVideoPages(videos: cached, limit: 12));
      }
    }

    try {
      final videos = await _apiService.searchVideos(normalized, 1);
      await _pageCache.cacheSearchResults(_cacheKeyForPage(normalized, 1), videos);

      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _videos = videos;
        _isLoading = false;
        _hasMore = videos.isNotEmpty && videos.length >= 20;
      });
      unawaited(_ensureVideoPages(videos: videos, limit: 12));
    } catch (e) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// 加载更多
  Future<void> _loadMore() async {
    if (_submittedQuery.isEmpty || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    final query = _submittedQuery;
    final generation = _searchGeneration;

    try {
      final nextPage = _currentPage + 1;
      final videos = await _apiService.searchVideos(query, nextPage);
      await _pageCache.cacheSearchResults(_cacheKeyForPage(query, nextPage), videos);

      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _videos.addAll(videos);
        _currentPage = nextPage;
        _isLoadingMore = false;
        _hasMore = videos.isNotEmpty && videos.length >= 20;
      });
      unawaited(_ensureVideoPages(videos: _videos, limit: 12));
    } catch (e) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载更多失败: $e')),
      );
    }
  }

  /// 下拉刷新
  Future<void> _refresh() async {
    await _loadSearchResults(_submittedQuery);
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
      resizeToAvoidBottomInset: true,
      backgroundColor: ThemeUtils.backgroundColor(context),
      body: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _wrapWithoutStretch(
                _buildBody(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_submittedQuery.isEmpty) {
      final pending = _searchController.text.trim();
      if (pending.isEmpty) {
        return _buildRecentSearchesView(context);
      }
      return _buildPendingSearchView(context, pending);
    }

    if (_isLoading && _videos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _videos.isEmpty) {
      return _buildErrorView();
    }

    if (_videos.isEmpty) {
      return _buildEmptyView();
    }

    return _buildResultsView(context);
  }

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: MottoSearchField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true,
          hintText: '艺人、歌曲、歌词以及更多内容',
          isLoading: _isResolving,
          leadingIcon: Icons.arrow_back_ios_new,
          onLeadingTap: () => Navigator.of(context).maybePop(),
          showSearchIcon: false,
          onSubmitted: (_) => unawaited(_handleSubmitted()),
          onClear: () {
            _searchController.clear();
            _resetSearchState();
            _searchFocusNode.requestFocus();
          },
        ),
      ),
    );
  }

  Widget _buildRecentSearchesView(BuildContext context) {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Text(
          '暂无最近搜索',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _recentSearches.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  '最近搜索',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ThemeUtils.textColor(context),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearRecentSearches,
                  child: const Text('清除'),
                ),
              ],
            ),
          );
        }

        final query = _recentSearches[index - 1];
        return ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            child: Icon(
              Icons.history,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          title: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _submitAndSearch(query),
        );
      },
    );
  }

  Widget _buildPendingSearchView(BuildContext context, String pending) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            child: Icon(
              Icons.search,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          title: Text('搜索 \"$pending\"'),
          onTap: () => _submitAndSearch(pending),
        ),
        if (_recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  '最近搜索',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ThemeUtils.textColor(context),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearRecentSearches,
                  child: const Text('清除'),
                ),
              ],
            ),
          ),
          ..._recentSearches.take(6).map(
                (query) => ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.08),
                    child: Icon(
                      Icons.history,
                      size: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                  title: Text(
                    query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _submitAndSearch(query),
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildResultsView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white : Colors.black;
    final unselectedLabelColor =
        isDark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.55);

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
          labelColor: labelColor,
          unselectedLabelColor: unselectedLabelColor,
          indicatorColor: const Color(0xFFE84C4C),
          tabs: const [
            Tab(text: '歌曲'),
            Tab(text: '多P'),
            Tab(text: '作者'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSongTab(context),
              _buildAlbumTab(context),
              _buildArtistTab(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBestTab(BuildContext context) {
    final best = _videos.isNotEmpty ? _videos.first : null;
    if (best == null) return const SizedBox.shrink();

    final artist = best.owner.name.isNotEmpty ? best.owner.name : 'UP主';
    final subtitle = '$artist · ${_formatPubdate(best.pubdate)}';

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: [
        AppleMusicSongTile(
          title: best.title,
          artist: subtitle,
          coverUrl: best.pic,
          duration: _formatDuration(best.duration),
          onTap: () => _playVideo(best, 0),
          onLongPress: () => unawaited(_showResultMenu(best, 0)),
          onMoreTap: () => _showResultMenu(best, 0),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          indent: 88,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
      ],
    );
  }

  List<BilibiliUploader> _buildUploaderList() {
    final seen = <int>{};
    final uploaders = <BilibiliUploader>[];
    for (final video in _videos) {
      final mid = video.owner.mid;
      if (mid == 0 || seen.contains(mid)) continue;
      seen.add(mid);
      uploaders.add(video.owner);
    }
    return uploaders;
  }

  Widget _buildArtistTab(BuildContext context) {
    final uploaders = _buildUploaderList();
    if (uploaders.isEmpty) {
      return Center(
        child: Text(
          '暂无作者结果',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: uploaders.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.5,
        indent: 72,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
      ),
      itemBuilder: (context, index) {
        final uploader = uploaders[index];
        final face = uploader.face;
        return ListTile(
          leading: CircleAvatar(
            radius: 22,
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            backgroundImage: (face != null && face.isNotEmpty)
                ? CachedNetworkImageProvider(face)
                : null,
            child: (face == null || face.isEmpty)
                ? Icon(
                    Icons.person,
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  )
                : null,
          ),
          title: Text(
            uploader.name.isEmpty ? 'UP主' : uploader.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _navigateToUploader(
            uploader.mid,
            uploader.name.isEmpty ? 'UP主' : uploader.name,
            face,
          ),
        );
      },
    );
  }

  Widget _buildAlbumTab(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final albums = _videos.where(_isAlbumVideo).toList(growable: false);
    final hasUnknown = _videos.any(
      (video) =>
          video.bvid.isNotEmpty &&
          !_videoPagesCache.containsKey(video.bvid) &&
          !_videoPagesLoading.contains(video.bvid),
    );

    if (albums.isEmpty) {
      if (hasUnknown) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_ensureVideoPages(videos: _videos, limit: 12));
        });
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                '正在识别专辑（多P视频）…',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        );
      }

      return Center(
        child: Text(
          '暂无专辑结果',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: 16 + bottomPadding),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final video = albums[index];
        final pages = _cachedPagesFor(video);
        final count = pages?.length ?? 0;

        final author = video.owner.name.isNotEmpty ? video.owner.name : 'UP主';
        final subtitle = count > 0 ? '$author · $count首' : author;

        return Column(
          children: [
            AppleMusicSongTile(
              title: video.title,
              artist: subtitle,
              coverUrl: video.pic,
              duration: count > 0 ? '$count首' : null,
              onTap: () => _navigateToVideoDetail(video),
              onMoreTap: () => _showResultMenu(video, _videos.indexOf(video)),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              indent: 88,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSongTab(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final songs =
        _videos.where((video) => !_isAlbumVideo(video)).toList(growable: false);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(bottom: 16 + bottomPadding),
        itemCount: songs.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == songs.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _isLoadingMore
                    ? const CircularProgressIndicator()
                    : const SizedBox.shrink(),
              ),
            );
          }

          final video = songs[index];
          final globalIndex = _videos.indexOf(video);
          final artist = video.owner.name.isNotEmpty ? video.owner.name : 'UP主';
          final subtitle = '$artist · ${_formatPubdate(video.pubdate)}';

          return Column(
            children: [
              AppleMusicSongTile(
                title: video.title,
                artist: subtitle,
                coverUrl: video.pic,
                duration: _formatDuration(video.duration),
                onTap: () => _playVideo(video, globalIndex),
                onLongPress: () => unawaited(_showResultMenu(video, globalIndex)),
                onMoreTap: () => _showResultMenu(video, globalIndex),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                indent: 88,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showResultMenu(BilibiliVideo video, int index) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('播放'),
                onTap: () {
                  Navigator.pop(context);
                  _playVideo(video, index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('查看详情'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToVideoDetail(video);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('查看UP主'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToUploader(
                    video.owner.mid,
                    video.owner.name.isEmpty ? 'UP主' : video.owner.name,
                    video.owner.face,
                  );
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
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
              '未找到相关内容',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '搜索: "$_submittedQuery"',
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
      // 为当前点击的视频封面优先获取本地缓存路径
      final cookieManager = CookieManager();
      final cookie = await cookieManager.getCookieString();
      final localCoverPath = await AlbumArtCacheService.instance.ensureLocalPath(
        video.pic,
        cookie: cookie.isEmpty ? null : cookie,
      );

      // 创建当前视频的 Song 对象（封面路径优先使用本地缓存）
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
        albumArtPath: localCoverPath ?? video.pic,
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
      final playlist = <db.Song>[];
      for (final entry in _videos.asMap().entries) {
        final idx = entry.key;
        final v = entry.value;

        String? cachedPath;
        try {
          cachedPath = await AlbumArtCacheService.instance.ensureLocalPath(
            v.pic,
            cookie: cookie.isEmpty ? null : cookie,
          );
        } catch (_) {
          // 静默降级，保留原始 URL
        }

        playlist.add(
          db.Song(
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
            albumArtPath: cachedPath ?? v.pic,
            dateAdded: DateTime.now(),
            isFavorite: false,
            lastPlayedTime: DateTime.now(),
            playedCount: 0,
            source: 'bilibili',
            bvid: v.bvid,
            cid: null,
            pageNumber: null,
            bilibiliVideoId: null,
          ),
        );
      }

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
