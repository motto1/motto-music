import 'package:flutter/material.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:provider/provider.dart';
import '../database/database.dart';
import '../services/player_provider.dart';
import '../widgets/show_aware_page.dart';
import '../widgets/themed_background.dart';
import '../widgets/unified_cover_image.dart';
import '../widgets/ranking_carousel.dart';
import '../utils/platform_utils.dart';
import '../animations/page_transitions.dart';
import '../views/recently_played_detail_page.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> with ShowAwarePage {
  List<Song> recentSongs = [];
  late final VoidCallback _recentSongListener;

  @override
  void onPageShow() {
    _loadRecentSongs();
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
  void dispose() {
    PlayerProvider.removeSongChangeListener(_recentSongListener);
    super.dispose();
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
            return CustomScrollView(
              slivers: [
                // 主页大标题
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: PlatformUtils.select(desktop: 40.0, mobile: 60.0),
                      left: 20,
                      right: 20,
                      bottom: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '主页',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
                // 排行榜轮播卡片
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 16,
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

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: recentSongs.length,
        itemBuilder: (context, index) {
          final song = recentSongs[index];
          final isPlaying = playerProvider.currentSong?.id == song.id;
          
          return Padding(
            padding: const EdgeInsets.only(right: 16),
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
                    Stack(
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          ),
                          child: UnifiedCoverImage(
                            coverPath: song.albumArtPath,
                            width: 160,
                            height: 160,
                            borderRadius: 12,
                          ),
                        ),
                        if (isPlaying)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black.withOpacity(0.3),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                      ],
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
