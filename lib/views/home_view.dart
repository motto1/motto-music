import 'package:flutter/material.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:provider/provider.dart';
import '../database/database.dart';
import '../services/player_provider.dart';
import '../widgets/show_aware_page.dart';
import '../widgets/themed_background.dart';
import '../widgets/unified_cover_image.dart';
import '../widgets/ranking_carousel.dart';
import '../widgets/global_top_bar.dart';
import '../utils/platform_utils.dart';
import '../animations/page_transitions.dart';
import '../views/recently_played_detail_page.dart';
import '../router/router.dart';
import '../contants/app_contants.dart';
import '../router/route_observer.dart';

/// 最近播放卡片的吸附滚动物理效果
class _RecentPlayedSnappingPhysics extends ScrollPhysics {
  final double itemExtent;

  const _RecentPlayedSnappingPhysics({required this.itemExtent, super.parent});

  @override
  _RecentPlayedSnappingPhysics applyTo(ScrollPhysics? ancestor) {
    return _RecentPlayedSnappingPhysics(
      itemExtent: itemExtent,
      parent: buildParent(ancestor),
    );
  }

  double _getTargetPixels(ScrollMetrics position, Tolerance tolerance, double velocity) {
    double page = position.pixels / itemExtent;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return (page.roundToDouble() * itemExtent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final currentTolerance = toleranceFor(position);
    final double target = _getTargetPixels(position, currentTolerance, velocity);
    if (target == position.pixels) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: currentTolerance,
    );
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> with ShowAwarePage, RouteAware {
  List<Song> recentSongs = [];
  late final VoidCallback _recentSongListener;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _homeTopBarProgress = ValueNotifier(0.0);
  static const double _collapseDistance = 64.0;

  @override
  void onPageShow() {
    _loadRecentSongs();
    _applyHomeTopBarStyle();
  }

  void _applyHomeTopBarStyle() {
    GlobalTopBarController.instance.set(
      GlobalTopBarStyle(
        source: 'home',
        title: '主页',
        showBackButton: false,
        centerTitle: false,
        opacity: 0.0,
        titleOpacity: 0.0,
        titleTranslateY: 0.0,
        translateY: 0.0,
        showDivider: false,
        trailing: SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.more_vert,
              size: 20,
              color: Color(0xFFFF3B30),
            ),
            onPressed: () {},
          ),
        ),
      ),
    );
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final progress = _calcHomeTopBarProgress(offset);
    _homeTopBarProgress.value = progress;
    GlobalTopBarController.instance.updateHomeProgress(progress);
  }

  @override
  void initState() {
    super.initState();
    _recentSongListener = () {
      _loadRecentSongs();
    };
    PlayerProvider.addSongChangeListener(_recentSongListener);
    _loadRecentSongs();
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
    _applyHomeTopBarStyle();
  }

  @override
  void dispose() {
    PlayerProvider.removeSongChangeListener(_recentSongListener);
    _scrollController.dispose();
    _homeTopBarProgress.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  double _calcHomeTopBarProgress(double offset) {
    const start = 0.0;
    final end = _collapseDistance;
    return ((offset - start) / (end - start)).clamp(0.0, 1.0);
  }

  Future<void> _loadRecentSongs() async {
    try {
      final songs = await MusicDatabase.database.smartSearch(
        null,
        orderField: 'lastPlayedTime',
        orderDirection: 'DESC',
        isLastPlayed: true,
      );
      if (!mounted) return;
      setState(() {
        recentSongs = songs.take(20).toList();
      });
    } catch (e) {
      print('加载最近播放失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        return ThemedBackground(
          builder: (context, theme) {
            final topPadding = MediaQuery.of(context).padding.top;
            const topBarHeight = 52.0;
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (MenuManager().currentPage.value != PlayerPage.home) {
                  return false;
                }
                if (notification.metrics.axis != Axis.vertical) {
                  return false;
                }
                final offset = notification.metrics.pixels;
                final progress = _calcHomeTopBarProgress(offset);
                _homeTopBarProgress.value = progress;
                GlobalTopBarController.instance.updateHomeProgress(progress);
                return false;
              },
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: topPadding + topBarHeight + 1),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                    child: ValueListenableBuilder<double>(
                      valueListenable: _homeTopBarProgress,
                      builder: (context, progress, child) {
                        final eased = Curves.easeOutCubic.transform(progress);
                        final titleOpacity = (1.0 - eased).clamp(0.0, 1.0);
                        final titleTranslateY = -14 * eased;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Transform.translate(
                              offset: Offset(0, titleTranslateY),
                              child: Opacity(
                                opacity: titleOpacity,
                                child: const Text(
                                  '主页',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                // 排行榜轮播卡片
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 12,
                    ),
                    child: const RankingCarousel(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      24,
                      20,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '最近播放',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                // 使用 Navigator.push 导航到最近播放详情页
                                Navigator.of(context).push(
                                  NamidaPageRoute(
                                    page: const RecentlyPlayedDetailPage(),
                                    type: PageTransitionType.slideLeft,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    Text(
                                      '查看全部',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildRecentlyPlayedScroll(context, playerProvider),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: PlatformUtils.select(desktop: 100.0, mobile: 180.0)),
                ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentlyPlayedScroll(BuildContext context, PlayerProvider playerProvider) {
    if (recentSongs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            '暂无播放记录',
            style: TextStyle(
              color: ThemeUtils.select(context, light: Colors.grey.shade600, dark: Colors.grey.shade400),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = Colors.black.withValues(alpha: isDark ? 0.18 : 0.12);
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const _RecentPlayedSnappingPhysics(itemExtent: 168), // 160 + 8
        itemCount: recentSongs.length,
        itemBuilder: (context, index) {
          final song = recentSongs[index];
          final isPlaying = playerProvider.currentSong?.id == song.id;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                playerProvider.playSong(
                  song,
                  playlist: recentSongs,
                  index: index,
                  shuffle: false,
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            UnifiedCoverImage(
                              coverPath: song.albumArtPath,
                              width: 160,
                              height: 160,
                              borderRadius: 0,
                            ),
                            if (isPlaying)
                              Container(
                                color: Colors.black.withValues(alpha: 0.3),
                                child: const Center(
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 48,
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      song.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist ?? '未知艺术家',
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeUtils.select(
                          context,
                          light: Colors.grey.shade600,
                          dark: Colors.grey.shade400,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
