import 'package:flutter/material.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../database/database.dart';
import '../services/player_provider.dart';
import '../widgets/show_aware_page.dart';
import '../widgets/themed_background.dart';
import '../utils/platform_utils.dart';
import '../contants/app_contants.dart';
import '../router/router.dart';
import '../animations/page_transitions.dart';
import '../views/recently_played_detail_page.dart';
import '../views/library_view.dart';
import '../views/bilibili/favorites_page.dart';

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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      PlatformUtils.select(desktop: 40.0, mobile: 80.0),
                      20,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '音乐库',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildLibraryCardsScroll(context),
                        const SizedBox(height: 32),
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

  Widget _buildLibraryCardsScroll(BuildContext context) {
    return SizedBox(
      height: 260,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildLibraryCard(
            context,
            title: '本地音乐库',
            icon: Icons.library_music_rounded,
            colors: [Color(0xFFE91E63), Color(0xFFF06292)],
            onTap: () {
              Navigator.of(context).push(
                NamidaPageRoute(
                  page: const LibraryView(),
                  type: PageTransitionType.slideUp,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          _buildLibraryCard(
            context,
            title: 'Bilibili音乐',
            icon: Icons.video_library_rounded,
            colors: [Color(0xFF00BCD4), Color(0xFF4DD0E1)],
            onTap: () {
              Navigator.of(context).push(
                NamidaPageRoute(
                  page: const BilibiliFavoritesPage(),
                  type: PageTransitionType.slideUp,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.9), size: 72),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
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
                playerProvider.playSong(song, playlist: recentSongs, index: index);
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
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: song.albumArtPath != null
                                ? (song.source == 'bilibili'
                                    ? Image.network(
                                        song.albumArtPath!,
                                        fit: BoxFit.cover,
                                        width: 160,
                                        height: 160,
                                        errorBuilder: (context, error, stackTrace) => Icon(
                                          Icons.video_library_rounded,
                                          size: 64,
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                        ),
                                      )
                                    : File(song.albumArtPath!).existsSync()
                                        ? Image.file(
                                            File(song.albumArtPath!),
                                            fit: BoxFit.cover,
                                            width: 160,
                                            height: 160,
                                          )
                                        : Icon(
                                            Icons.music_note_rounded,
                                            size: 64,
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                          ))
                                : Icon(
                                    song.source == 'bilibili' 
                                        ? Icons.video_library_rounded 
                                        : Icons.music_note_rounded,
                                    size: 64,
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                  ),
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
