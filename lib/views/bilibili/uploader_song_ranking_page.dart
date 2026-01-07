import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/main.dart';
import 'package:motto_music/models/bilibili/video.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/services/cache/page_cache_service.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/views/bilibili/video_detail_page.dart';
import 'package:motto_music/widgets/apple_music_song_tile.dart';
import 'package:motto_music/widgets/global_top_bar.dart';
import 'package:motto_music/widgets/unified_cover_image.dart';
import 'package:motto_music/widgets/frosted_bottom_sheet.dart';

/// 作者/制作人员 - 歌曲排行（完整列表页）
class UploaderSongRankingPage extends StatefulWidget {
  final int mid;
  final String artistName;

  const UploaderSongRankingPage({
    super.key,
    required this.mid,
    required this.artistName,
  });

  @override
  State<UploaderSongRankingPage> createState() => _UploaderSongRankingPageState();
}

class _UploaderSongRankingPageState extends State<UploaderSongRankingPage> {
  static const Color _accentColor = Color(0xFFE84C4C);

  late final BilibiliApiService _apiService;
  final PageCacheService _pageCache = PageCacheService();

  bool _isLoading = false;
  List<BilibiliVideo>? _videos;
  String? _errorMessage;

  int _currentPage = 1;
  bool _hasMore = true;

  String _cacheKeyForPage(int page) => 'uploader_${widget.mid}_song_rank_page_$page';

  @override
  void initState() {
    super.initState();

    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GlobalTopBarController.instance.push(_topBarStyle());
      _loadCached();
      _loadVideos();
    });
  }

  @override
  void dispose() {
    GlobalTopBarController.instance.pop();
    super.dispose();
  }

  GlobalTopBarStyle _topBarStyle() {
    return GlobalTopBarStyle(
      source: 'uploader-song-ranking',
      title: '歌曲排行',
      showBackButton: true,
      centerTitle: true,
      backIconColor: _accentColor,
      onBack: _handleBack,
      opacity: 1.0,
      translateY: 0.0,
      showDivider: true,
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

  Future<void> _loadCached() async {
    final cached = await _pageCache.getCachedVideoList(_cacheKeyForPage(1));
    if (!mounted || cached == null || cached.isEmpty) return;
    setState(() {
      _videos = cached;
      _currentPage = 1;
      _hasMore = cached.length >= 30;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  Future<void> _loadVideos({bool loadMore = false}) async {
    if (_isLoading) return;
    if (loadMore && !_hasMore) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final page = loadMore ? _currentPage + 1 : 1;
      final videos = await _apiService.getUploaderVideos(
        mid: widget.mid,
        page: page,
        pageSize: 30,
      );

      await _pageCache.cacheVideoList(_cacheKeyForPage(page), videos);

      if (!mounted) return;
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }
  void _openVideo(BilibiliVideo video) {
    Navigator.of(context).push(
      NamidaPageRoute(
        page: VideoDetailPage(
          bvid: video.bvid,
          title: video.title,
        ),
        type: PageTransitionType.slideLeft,
      ),
    );
  }

  String _subtitleFor(BilibiliVideo video) {
    if (video.pubdate <= 0) return widget.artistName;
    final year = DateTime.fromMillisecondsSinceEpoch(video.pubdate * 1000).year;
    return '${widget.artistName} · $year年';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: ThemeUtils.backgroundColor(context),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_videos == null && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videos == null && _errorMessage != null) {
      return _buildErrorView(message: _errorMessage!, onRetry: _loadVideos);
    }

    final videos = _videos ?? const <BilibiliVideo>[];
    if (videos.isEmpty) {
      return const Center(
        child: Text(
          '暂无内容',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10);

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 160),
      itemCount: videos.length + 1,
      itemBuilder: (context, index) {
        final isLoader = index == videos.length;
        if (isLoader) {
          if (!_isLoading && _hasMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _loadVideos(loadMore: true);
            });
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: _hasMore
                  ? const CircularProgressIndicator()
                  : const Text(
                      '没有更多了',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
            ),
          );
        }

        final video = videos[index];
        return Column(
          children: [
            AppleMusicSongTile(
              title: video.title,
              artist: _subtitleFor(video),
              coverUrl: video.pic,
              onTap: () => _openVideo(video),
              onMoreTap: () => _showVideoMenu(video, isDark: isDark),
              trailing: IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                  size: 22,
                ),
                onPressed: () => _showVideoMenu(video, isDark: isDark),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
            if (index != videos.length - 1)
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
    );
  }

  Future<void> _showVideoMenu(BilibiliVideo video, {required bool isDark}) async {
    await FrostedBottomSheet.show(
      context: context,
      initialChildSize: 0.3,
      minChildSize: 0.2,
      maxChildSize: 0.5,
      header: buildFrostedSheetHeader(
        context: context,
        cover: UnifiedCoverImage(
          coverPath: video.pic,
          width: 48,
          height: 48,
          borderRadius: 8,
          isDark: isDark,
        ),
        title: video.title,
        subtitle: _subtitleFor(video),
      ),
      tiles: [
        ListTile(
          leading: const Icon(Icons.open_in_new_rounded),
          title: const Text('打开详情'),
          onTap: () {
            Navigator.pop(context);
            _openVideo(video);
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
      ],
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
}
