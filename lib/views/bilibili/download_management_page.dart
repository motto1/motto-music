import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:motto_music/database/database.dart';
import 'package:motto_music/services/bilibili/download_manager.dart';
import 'package:motto_music/services/player_provider.dart';
import 'package:motto_music/services/cache/album_art_cache_service.dart';
import 'package:motto_music/widgets/bilibili/download_task_card.dart';
import 'package:motto_music/widgets/frosted_page_header.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'dart:ui';

/// Bilibili 下载管理页面
///
/// 功能：
/// - 4个标签页：全部、下载中、已完成、失败
/// - 实时进度更新
/// - 批量操作
/// - 点击播放已完成的任务
class DownloadManagementPage extends StatefulWidget {
  const DownloadManagementPage({super.key});

  @override
  State<DownloadManagementPage> createState() => _DownloadManagementPageState();
}

class _DownloadManagementPageState extends State<DownloadManagementPage> {
  int _selectedSegment = 0; // 0:全部, 1:下载中, 2:已完成, 3:失败

  @override
  void initState() {
    super.initState();
    // 刷新任务列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloadManager>().refreshTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark
          ? ThemeUtils.backgroundColor(context)
          : const Color(0xFFFFFFFF),
      body: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: (notification) {
          notification.disallowIndicator();
          return true;
        },
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
          // 液态玻璃头部
          SliverToBoxAdapter(
            child: FrostedPageHeader(
              title: '下载管理',
              actions: [
                // 批量操作菜单
                PopupMenuButton<String>(
                  icon: const Icon(CupertinoIcons.ellipsis_vertical, size: 22),
                  onSelected: _handleMenuAction,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'pause_all',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.pause_circle, size: 20),
                          SizedBox(width: 8),
                          Text('暂停全部'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'resume_all',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.play_circle, size: 20),
                          SizedBox(width: 8),
                          Text('恢复全部'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'retry_failed',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.refresh, size: 20),
                          SizedBox(width: 8),
                          Text('重试失败'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_completed',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.trash, size: 20),
                          SizedBox(width: 8),
                          Text('清空已完成'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // iOS 风格分段控件
          SliverToBoxAdapter(
            child: _buildSegmentedControl(),
          ),
          
          // 任务列表
          Consumer<DownloadManager>(
            builder: (context, downloadManager, child) {
              if (downloadManager.isLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              final tasks = _getFilteredTasks(downloadManager);
              return _buildTaskList(tasks);
            },
          ),
        ],
      ),
      ),
    );
  }

  /// 构建分段控件 - 带发光效果的液态玻璃样式
  Widget _buildSegmentedControl() {
    return Consumer<DownloadManager>(
      builder: (context, downloadManager, child) {
        final stats = downloadManager.getStatistics();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Theme.of(context).primaryColor.withOpacity(0.12)
                      : Theme.of(context).primaryColor.withOpacity(0.18),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
                if (!isDark)
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.06),
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(0.09)
                        : Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.18)
                          : Colors.white.withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      _buildCompactDockButton(
                        label: '全部',
                        count: stats['total']!,
                        index: 0,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 3),
                      _buildCompactDockButton(
                        label: '下载中',
                        count: stats['downloading']!,
                        index: 1,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 3),
                      _buildCompactDockButton(
                        label: '已完成',
                        count: stats['completed']!,
                        index: 2,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 3),
                      _buildCompactDockButton(
                        label: '失败',
                        count: stats['failed']!,
                        index: 3,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建紧凑型 Dock 按钮
  Widget _buildCompactDockButton({
    required String label,
    required int count,
    required int index,
    required bool isDark,
  }) {
    final isSelected = _selectedSegment == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSegment = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark 
                    ? Colors.white.withOpacity(0.18)
                    : Colors.white.withOpacity(0.85))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.25)
                          : Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.45)),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: isSelected ? 13 : 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (isDark ? Colors.white : Theme.of(context).primaryColor)
                      : (isDark ? Colors.white.withOpacity(0.35) : Colors.black.withOpacity(0.25)),
                ),
                child: Text(count.toString()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取过滤后的任务列表
  List<DownloadTask> _getFilteredTasks(DownloadManager manager) {
    switch (_selectedSegment) {
      case 0:
        return manager.allTasks;
      case 1:
        return manager.downloadingTasks;
      case 2:
        return manager.completedTasks;
      case 3:
        return manager.failedTasks;
      default:
        return manager.allTasks;
    }
  }

  /// 获取空状态提示
  String _getEmptyMessage() {
    switch (_selectedSegment) {
      case 0:
        return '暂无下载任务';
      case 1:
        return '暂无下载中的任务';
      case 2:
        return '暂无已完成的任务';
      case 3:
        return '暂无失败的任务';
      default:
        return '暂无下载任务';
    }
  }

  /// 构建任务列表
  Widget _buildTaskList(List<DownloadTask> tasks) {
    if (tasks.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.cloud_download,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _getEmptyMessage(),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              if (_selectedSegment == 0)
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(CupertinoIcons.back, size: 18),
                  label: const Text('返回收藏夹添加下载'),
                ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 0,
        bottom: 120, // 为小播放器预留空间
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = tasks[index];
            return DownloadTaskCard(
              task: task,
              onTap: () => _handlePlayTask(task), // 点击播放
              onPause: () => _handlePause(task.id),
              onResume: () => _handleResume(task.id),
              onCancel: () => _handleCancel(task.id),
              onRetry: () => _handleRetry(task.id),
              onDelete: () => _handleDelete(task.id),
            );
          },
          childCount: tasks.length,
        ),
      ),
    );
  }

  /// 播放下载任务
  Future<void> _handlePlayTask(DownloadTask task) async {
    // 检查是否已完成
    if (task.status != 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('歌曲还未下载完成'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // 获取本地封面路径
      String? localCoverPath;
      if (task.coverUrl != null && task.coverUrl!.isNotEmpty) {
        final albumArtCache = AlbumArtCacheService.instance;
        localCoverPath = await albumArtCache.ensureLocalPath(task.coverUrl!);
      }

      // 直接从任务信息创建 Song 对象并播放
      final song = Song(
        id: task.id,
        title: task.title,
        artist: task.artist,
        album: null,
        filePath: task.localPath ?? '',
        lyrics: null,
        bitrate: null,
        sampleRate: null,
        duration: task.duration,
        albumArtPath: localCoverPath ?? task.coverUrl,
        dateAdded: task.createdAt,
        isFavorite: false,
        lastPlayedTime: DateTime.now(),
        playedCount: 0,
        source: 'bilibili',
        bvid: task.bvid,
        cid: task.cid,
        pageNumber: null,
        bilibiliVideoId: null,
        bilibiliFavoriteId: null,
        downloadedQualities: null,
        currentQuality: task.quality,
      );

      // 播放歌曲(参考收藏夹页面的方式)
      final playerProvider = context.read<PlayerProvider>();
      await playerProvider.playSong(song);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('正在播放: ${song.title}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放失败: ${e.toString()}'),
          ),
        );
      }
    }
  }

  /// 处理菜单操作
  Future<void> _handleMenuAction(String action) async {
    final downloadManager = context.read<DownloadManager>();

    try {
      switch (action) {
        case 'pause_all':
          await downloadManager.pauseAll();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已暂停全部下载')),
            );
          }
          break;

        case 'resume_all':
          if (!downloadManager.canDownload()) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('当前网络环境不允许下载（仅WiFi设置）')),
              );
            }
            return;
          }
          await downloadManager.resumeAll();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已恢复全部下载')),
            );
          }
          break;

        case 'retry_failed':
          await downloadManager.retryAllFailed();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已重试全部失败任务')),
            );
          }
          break;

        case 'clear_completed':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('确认清空'),
              content: const Text('确定要清空所有已完成的下载记录吗？文件不会被删除。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('确定'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            await downloadManager.clearCompleted();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已清空已完成任务')),
              );
            }
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  /// 暂停下载
  Future<void> _handlePause(int taskId) async {
    try {
      await context.read<DownloadManager>().pauseDownload(taskId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('暂停失败: $e')),
        );
      }
    }
  }

  /// 恢复下载
  Future<void> _handleResume(int taskId) async {
    try {
      await context.read<DownloadManager>().resumeDownload(taskId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e')),
        );
      }
    }
  }

  /// 取消下载
  Future<void> _handleCancel(int taskId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认取消'),
        content: const Text('确定要取消这个下载任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('否'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('是'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<DownloadManager>().cancelDownload(taskId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('取消失败: $e')),
          );
        }
      }
    }
  }

  /// 重试任务
  Future<void> _handleRetry(int taskId) async {
    try {
      await context.read<DownloadManager>().retryFailedTask(taskId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重试失败: $e')),
        );
      }
    }
  }

  /// 删除任务
  Future<void> _handleDelete(int taskId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个任务吗？已下载的文件也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<DownloadManager>().deleteTask(taskId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已删除')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }
}
