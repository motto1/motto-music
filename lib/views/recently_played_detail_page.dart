import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../database/database.dart';
import '../services/player_provider.dart';
import '../utils/theme_utils.dart';

class RecentlyPlayedDetailPage extends StatefulWidget {
  const RecentlyPlayedDetailPage({super.key});

  @override
  State<RecentlyPlayedDetailPage> createState() => _RecentlyPlayedDetailPageState();
}

class _RecentlyPlayedDetailPageState extends State<RecentlyPlayedDetailPage> {
  List<Song> recentSongs = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSongs();
  }

  Future<void> _loadRecentSongs() async {
    try {
      final songs = await MusicDatabase.database.smartSearch(
        null,
        orderField: 'lastPlayedTime',
        orderDirection: 'DESC',
        isLastPlayed: true,
      );
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
    return Scaffold(
      backgroundColor: ThemeUtils.backgroundColor(context),
      body: Column(
        children: [
          // 顶部导航栏
          SafeArea(
            bottom: false,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                    onPressed: _handleBackPress,
                  ),
                  const Text(
                    '最近播放',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 网格内容区（底部预留空间给全局播放器）
          Expanded(
            child: _buildGridContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildGridContent() {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 104), // 底部留出播放器空间 (84 + 20)
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 20,
            childAspectRatio: 0.7,
          ),
          itemCount: recentSongs.length,
          itemBuilder: (context, index) {
            final song = recentSongs[index];
            final isPlaying = playerProvider.currentSong?.id == song.id;

            return InkWell(
              onTap: () {
                playerProvider.playSong(song, playlist: recentSongs, index: index);
              },
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        Container(
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
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder: (context, error, stackTrace) => Center(
                                          child: Icon(
                                            Icons.video_library_rounded,
                                            size: 64,
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                          ),
                                        ),
                                      )
                                    : File(song.albumArtPath!).existsSync()
                                        ? Image.file(
                                            File(song.albumArtPath!),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          )
                                        : Center(
                                            child: Icon(
                                              Icons.music_note_rounded,
                                              size: 64,
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                            ),
                                          ))
                                : Center(
                                    child: Icon(
                                      song.source == 'bilibili'
                                          ? Icons.video_library_rounded
                                          : Icons.music_note_rounded,
                                      size: 64,
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                    ),
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
                              child: const Center(
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
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist ?? '未知艺术家',
                    style: TextStyle(
                      fontSize: 13,
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
            );
          },
        );
      },
    );
  }
}
