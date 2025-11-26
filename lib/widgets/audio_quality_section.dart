import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' show Value;

import 'package:motto_music/database/database.dart';
import 'package:motto_music/models/bilibili/audio_quality.dart';
import 'package:motto_music/services/cache/bilibili_auto_cache_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/services/bilibili/download_manager.dart';
import 'package:motto_music/services/bilibili/stream_service.dart';
import 'package:motto_music/storage/player_state_storage.dart';

/// 播放 & 下载音质选择组件
///
/// 在播放器三点弹窗、收藏夹歌曲弹窗等位置复用，确保视觉与行为一致。
class AudioQualitySection extends StatefulWidget {
  final Song song;

  const AudioQualitySection({super.key, required this.song});

  @override
  State<AudioQualitySection> createState() => _AudioQualitySectionState();
}

class _AudioQualitySectionState extends State<AudioQualitySection> {
  BilibiliAudioQuality? _playQuality;
  BilibiliAudioQuality? _downloadQuality;
  List<BilibiliAudioQuality>? _availableQualities;
  final Map<BilibiliAudioQuality, AudioQualityStats> _qualityStats = {};
  final Map<BilibiliAudioQuality, _QualityCacheStatus> _cacheStatusMap = {};

  bool _isLoadingQualities = true;
  bool _isRefreshingCacheStatus = false;
  bool _playQualityExpanded = false;
  bool _downloadQualityExpanded = false;
  late Song _currentSong;
  DownloadManager? _downloadManager;
  VoidCallback? _downloadManagerListener;
  late final CookieManager _cookieManager;
  late final BilibiliApiClient _apiClient;
  late final BilibiliStreamService _streamService;
  BilibiliAutoCacheService? _autoCacheService;

  @override
  void initState() {
    super.initState();
    _currentSong = widget.song;
    _cookieManager = CookieManager();
    _apiClient = BilibiliApiClient(_cookieManager);
    _streamService = BilibiliStreamService(_apiClient);
    _initialize();
  }

  @override
  void dispose() {
    if (_downloadManagerListener != null && _downloadManager != null) {
      _downloadManager!.removeListener(_downloadManagerListener!);
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final manager = Provider.of<DownloadManager>(context, listen: false);
    if (_downloadManager != manager) {
      if (_downloadManagerListener != null && _downloadManager != null) {
        _downloadManager!.removeListener(_downloadManagerListener!);
      }
      _downloadManager = manager;
      _downloadManagerListener = () {
        _refreshCacheStatuses();
      };
      _downloadManager!.addListener(_downloadManagerListener!);
    }
  }

  @override
  void didUpdateWidget(covariant AudioQualitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _currentSong = widget.song;
      _initialize();
    }
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _isLoadingQualities = true;
      });
    }
    await Future.wait([
      _loadCurrentQualities(),
      _loadAvailableQualities(),
    ]);
    await _refreshCacheStatuses();
  }

  Future<void> _loadCurrentQualities() async {
    final storage = await PlayerStateStorage.getInstance();
    final playQualityId = storage.defaultBilibiliPlayQuality;

    if (mounted) {
      setState(() {
        _playQuality = BilibiliAudioQuality.fromId(playQualityId);
        _downloadQuality = _playQuality ?? BilibiliAudioQuality.extreme;
      });
    }
  }

  Future<void> _loadAvailableQualities() async {
    var bvid = widget.song.bvid;
    var cid = widget.song.cid;

    if (bvid == null || bvid.isEmpty) {
      if (mounted) {
        setState(() {
          _availableQualities = BilibiliAudioQuality.values;
          _isLoadingQualities = false;
        });
      }
      return;
    }

    if (cid == null) {
      try {
        final pages = await _apiClient.get<List<dynamic>>(
          '/x/player/pagelist',
          params: {'bvid': bvid},
        );

        if (pages != null && pages.isNotEmpty) {
          final firstPage = pages[0] as Map<String, dynamic>;
          cid = firstPage['cid'] as int?;

          if (cid != null && mounted) {
            final updatedSong = widget.song.copyWith(cid: Value(cid));
            await MusicDatabase.database.updateSong(updatedSong);
            setState(() {
              _currentSong = updatedSong;
            });
          }
        }
      } catch (_) {}
    }

    if (cid == null) {
      if (mounted) {
        setState(() {
          _availableQualities = BilibiliAudioQuality.values;
          _isLoadingQualities = false;
        });
      }
      return;
    }

    try {
      final statsList = await _streamService.getAvailableQualities(
        bvid: bvid,
        cid: cid,
      );

      final qualities = <BilibiliAudioQuality>[];
      _qualityStats.clear();

      for (final stats in statsList) {
        qualities.add(stats.quality);
        _qualityStats[stats.quality] = stats;
      }

      if (mounted) {
        setState(() {
          _availableQualities = qualities;
          _isLoadingQualities = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _availableQualities = BilibiliAudioQuality.values;
          _isLoadingQualities = false;
        });
      }
    }
  }

  bool _isQualityAvailable(BilibiliAudioQuality quality) {
    return _availableQualities?.contains(quality) ?? false;
  }

  String _formatQualityDescription(BilibiliAudioQuality quality) {
    final stats = _qualityStats[quality];
    final bitrate = stats?.bitrate ?? quality.bitrate;
    return '$bitrate kbps';
  }

  Future<BilibiliAutoCacheService?> _getAutoCacheService() async {
    if (_autoCacheService != null) return _autoCacheService;
    _autoCacheService = await BilibiliAutoCacheService.getInstance(
      streamService: _streamService,
      cookieManager: _cookieManager,
    );
    return _autoCacheService;
  }

  Future<void> _refreshCacheStatuses() async {
    if (!mounted || _isRefreshingCacheStatus) return;
    final bvid = _currentSong.bvid;
    final cid = _currentSong.cid;
    if (bvid == null || cid == null) {
      setState(() {
        _cacheStatusMap.clear();
      });
      return;
    }

    _isRefreshingCacheStatus = true;
    try {
      final downloadManager = _downloadManager;
      final autoCacheService = await _getAutoCacheService();
      final futures = BilibiliAudioQuality.values.map(
        (quality) => _computeCacheStatus(
          bvid: bvid,
          cid: cid,
          quality: quality,
          downloadManager: downloadManager,
          autoCacheService: autoCacheService,
        ),
      );
      final results = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _cacheStatusMap
          ..clear();
        for (var i = 0; i < BilibiliAudioQuality.values.length; i++) {
          _cacheStatusMap[BilibiliAudioQuality.values[i]] = results.elementAt(i);
        }
      });
    } finally {
      _isRefreshingCacheStatus = false;
    }
  }

  Future<_QualityCacheStatus> _computeCacheStatus({
    required String bvid,
    required int cid,
    required BilibiliAudioQuality quality,
    DownloadManager? downloadManager,
    BilibiliAutoCacheService? autoCacheService,
  }) async {
    bool manualDownloading = false;
    bool manualCached = false;

    if (downloadManager != null) {
      final tasks = downloadManager.allTasks.where(
        (t) => t.bvid == bvid && t.cid == cid && t.quality == quality.id,
      );
      manualDownloading = tasks.any(
        (t) => t.status == 'downloading' || t.status == 'pending',
      );
      manualCached = tasks.any((t) => t.status == 'completed');
    }

    if (!manualCached) {
      final cacheData = await MusicDatabase.database.getCachedAudio(
        bvid: bvid,
        cid: cid,
        quality: quality.id,
      );
      if (cacheData != null) {
        final file = File(cacheData.localFilePath);
        if (await file.exists()) {
          manualCached = true;
        }
      }
    }

    AutoCacheState autoState = AutoCacheState.none;
    if (!manualCached && autoCacheService != null) {
      autoState = await autoCacheService.getCacheState(
        bvid: bvid,
        cid: cid,
        quality: quality,
      );
    } else if (manualCached) {
      autoState = AutoCacheState.cached;
    }

    return _QualityCacheStatus(
      manualCached: manualCached,
      manualDownloading: manualDownloading,
      autoState: autoState,
    );
  }

  Widget? _buildCacheBadge(BilibiliAudioQuality quality) {
    final status = _cacheStatusMap[quality];
    if (status == null) return null;

    String? label;
    Color color = Theme.of(context).colorScheme.primary;

    if (status.manualDownloading) {
      label = '下载中';
      color = Colors.orange;
    } else if (status.manualCached) {
      label = '已下载';
      color = Colors.green;
    } else if (status.autoState == AutoCacheState.caching) {
      label = '缓存中';
      color = Colors.orange;
    } else if (status.autoState == AutoCacheState.cached) {
      label = '自动缓存';
      color = Colors.green;
    }

    if (label == null) return null;

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String? _cacheStatusShortLabel(_QualityCacheStatus status) {
    if (status.manualDownloading) {
      return '下载中';
    }
    if (status.manualCached) {
      return '已下载';
    }
    if (status.autoState == AutoCacheState.caching) {
      return '缓存中';
    }
    if (status.autoState == AutoCacheState.cached) {
      return '已缓存';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQualityExpandable(
          title: '播放音质',
          leadingIcon: Icons.play_circle_outline_rounded,
          selectedQuality: _playQuality,
          isExpanded: _playQualityExpanded,
          onTap: () {
            setState(() {
              _playQualityExpanded = !_playQualityExpanded;
            });
            if (!_isLoadingQualities) {
              _refreshCacheStatuses();
            }
          },
          onQualitySelect: (quality) async {
            setState(() {
              _playQuality = quality;
              _playQualityExpanded = false;
            });

            final storage = await PlayerStateStorage.getInstance();
            await storage.setDefaultBilibiliPlayQuality(quality.id);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已设置播放音质: ${quality.displayName}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
        ),
        _buildQualityExpandable(
          title: '下载音质',
          leadingIcon: Icons.cloud_download_rounded,
          selectedQuality: _downloadQuality,
          isExpanded: _downloadQualityExpanded,
          onTap: () {
            setState(() {
              _downloadQualityExpanded = !_downloadQualityExpanded;
            });
            if (!_isLoadingQualities) {
              _refreshCacheStatuses();
            }
          },
          onQualitySelect: (quality) {
            setState(() {
              _downloadQuality = quality;
              _downloadQualityExpanded = false;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已设置下载音质: ${quality.displayName}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
          showDownloadButton: true,
        ),
      ],
    );
  }

  Widget _buildQualityExpandable({
    required String title,
    required IconData leadingIcon,
    required BilibiliAudioQuality? selectedQuality,
    required bool isExpanded,
    required VoidCallback onTap,
    required Function(BilibiliAudioQuality) onQualitySelect,
    bool showDownloadButton = false,
  }) {
    final theme = Theme.of(context);
    final hasSelection = selectedQuality != null;
    final isSelectionAvailable = hasSelection && _isQualityAvailable(selectedQuality!);

    String subtitleText;
    Color subtitleColor = theme.colorScheme.onSurface.withOpacity(0.65);

    if (_isLoadingQualities) {
      subtitleText = '正在加载可用音质...';
    } else if (!hasSelection) {
      subtitleText = '请选择可用音质';
    } else {
      subtitleText = _formatQualityDescription(selectedQuality!);
      if (!isSelectionAvailable) {
        subtitleText = '$subtitleText · 不可用';
        subtitleColor = theme.colorScheme.onSurface.withOpacity(0.5);
      } else {
        subtitleColor = theme.colorScheme.onSurface.withOpacity(0.8);
      }
    }

    final selectedStatus =
        hasSelection ? _cacheStatusMap[selectedQuality!] : null;
    final statusLabel = selectedStatus != null
        ? _cacheStatusShortLabel(selectedStatus)
        : null;
    if (statusLabel != null) {
      subtitleText = '$subtitleText · $statusLabel';
    }

    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(
            leadingIcon,
            color: theme.colorScheme.onSurface.withOpacity(0.85),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: subtitleColor,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDownloadButton) ...[
                Builder(
                  builder: (context) {
                    final quality = selectedQuality;
                    if (quality != null) {
                      return _QualityDownloadButton(
                        song: _currentSong,
                        quality: quality,
                      );
                    }
                    return IconButton(
                      icon: const Icon(Icons.download_outlined, size: 20),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('请先选择下载音质'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: '下载',
                    );
                  },
                ),
                const SizedBox(width: 4),
              ],
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: isExpanded
              ? _isLoadingQualities
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: SingleChildScrollView(
                        child: Column(
                          children: BilibiliAudioQuality.values.map((quality) {
                            final isSelected = selectedQuality == quality;
                            final isAvailable = _isQualityAvailable(quality);
                            final badge = _buildCacheBadge(quality);

                            return Opacity(
                              opacity: isAvailable ? 1.0 : 0.4,
                              child: ListTile(
                                enabled: isAvailable,
                                onTap: isAvailable ? () => onQualitySelect(quality) : null,
                                leading: Icon(
                                  quality.getIcon(),
                                  size: 24,
                                  color: theme.colorScheme.onSurface.withOpacity(isAvailable ? 0.9 : 0.35),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      quality.displayName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        color: theme.colorScheme.onSurface.withOpacity(isAvailable ? 1.0 : 0.55),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (!isAvailable)
                                      Icon(
                                        Icons.lock,
                                        size: 14,
                                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                                      ),
                                    if (badge != null) badge,
                                  ],
                                ),
                                subtitle: Text(
                                  _formatQualityDescription(quality),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface.withOpacity(isAvailable ? 0.6 : 0.3),
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: theme.colorScheme.onSurface.withOpacity(0.9),
                                        size: 20,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _QualityDownloadButton extends StatelessWidget {
  final Song song;
  final BilibiliAudioQuality quality;

  const _QualityDownloadButton({
    required this.song,
    required this.quality,
  });

  @override
  Widget build(BuildContext context) {
    final downloadManager = context.watch<DownloadManager>();

    final bvid = song.bvid;
    final cid = song.cid;

    if (bvid == null || cid == null) {
      return const SizedBox.shrink();
    }

    final matchingTasks = downloadManager.allTasks
        .where((t) => t.bvid == bvid && t.cid == cid && t.quality == quality.id)
        .toList();
    final existingTask = matchingTasks.isNotEmpty ? matchingTasks.first : null;

    final isDownloading = existingTask != null && existingTask.status == 'downloading';
    final isCompleted = existingTask != null && existingTask.status == 'completed';

    return IconButton(
      icon: Icon(
        isCompleted
            ? Icons.check_circle_rounded
            : isDownloading
                ? Icons.downloading_rounded
                : Icons.cloud_download_rounded,
        size: 22,
      ),
      color: isCompleted
          ? Theme.of(context).colorScheme.onSurface.withOpacity(0.85)
          : Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
      onPressed: isDownloading || isCompleted
          ? null
          : () => _startDownload(context, bvid, cid, quality),
      tooltip: isCompleted
          ? '已下载'
          : isDownloading
              ? '下载中 ${existingTask!.progress}%'
              : '下载 ${quality.displayName}',
    );
  }

  Future<void> _startDownload(
    BuildContext context,
    String bvid,
    int cid,
    BilibiliAudioQuality quality,
  ) async {
    final downloadManager = context.read<DownloadManager>();

    try {
      await downloadManager.downloadSong(
        song: song,
        quality: quality,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('开始下载: ${song.title} (${quality.displayName})'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class _QualityCacheStatus {
  final bool manualCached;
  final bool manualDownloading;
  final AutoCacheState autoState;

  const _QualityCacheStatus({
    this.manualCached = false,
    this.manualDownloading = false,
    this.autoState = AutoCacheState.none,
  });
}
