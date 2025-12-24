import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/database.dart';
import '../services/player_provider.dart';
import '../utils/theme_utils.dart';
import '../widgets/unified_cover_image.dart';
import '../widgets/global_top_bar.dart';

class RecentlyPlayedDetailPage extends StatefulWidget {
  const RecentlyPlayedDetailPage({super.key});

  @override
  State<RecentlyPlayedDetailPage> createState() => _RecentlyPlayedDetailPageState();
}

class _RecentlyPlayedDetailPageState extends State<RecentlyPlayedDetailPage> {
  static const Color _accentColor = Color(0xFFE84C4C);
  List<Song> recentSongs = [];
  late final VoidCallback _recentSongListener;

  @override
  void initState() {
    super.initState();
    GlobalTopBarController.instance.push(
      GlobalTopBarStyle(
        source: 'detail',
        title: '最近播放',
        showBackButton: true,
        centerTitle: true,
        backIconColor: _accentColor,
        onBack: _handleBackPress,
        opacity: 1.0,
        translateY: 0.0,
        showDivider: true,
      ),
    );
    _recentSongListener = () {
      _loadRecentSongs();
    };
    PlayerProvider.addSongChangeListener(_recentSongListener);
    _loadRecentSongs();
  }

  @override
  void dispose() {
    PlayerProvider.removeSongChangeListener(_recentSongListener);
    GlobalTopBarController.instance.pop();
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
        recentSongs = songs;
      });
    } catch (e) {
      print('加载最近播放失败: $e');
    }
  }

  void _handleBackPress() {
    Navigator.of(context).pop();
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
          SizedBox(height: topPadding + topBarHeight + 1),
          Expanded(
            child: _buildGridContent(textColor, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildGridContent(Color textColor, bool isDark) {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        final borderColor = Colors.black.withValues(alpha: isDark ? 0.18 : 0.12);
        if (recentSongs.isEmpty) {
          return Center(
            child: Text(
              '暂无播放记录',
              style: TextStyle(
                color: ThemeUtils.select(
                  context,
                  light: Colors.grey.shade600,
                  dark: Colors.grey.shade400,
                ),
                fontSize: 16,
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 20,
            childAspectRatio: 0.75,
          ),
          itemCount: recentSongs.length,
          itemBuilder: (context, index) {
            final song = recentSongs[index];
            final isPlaying = playerProvider.currentSong?.id == song.id;

            return InkWell(
              onTap: () {
                playerProvider.playSong(
                  song,
                  playlist: recentSongs,
                  index: index,
                  shuffle: false,
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: _buildCoverCard(
                      song.albumArtPath,
                      isDark,
                      borderColor,
                      isPlaying,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist ?? '未知艺术家',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCoverCard(
    String? coverPath,
    bool isDark,
    Color borderColor,
    bool isPlaying,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Container(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: UnifiedCoverImage(
              coverPath: coverPath,
              width: double.infinity,
              height: double.infinity,
              borderRadius: 0,
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
          if (isPlaying)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 48,
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
        ],
      ),
    );
  }
}
