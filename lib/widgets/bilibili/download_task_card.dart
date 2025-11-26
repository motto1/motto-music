import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:motto_music/database/database.dart';
import 'package:motto_music/models/bilibili/audio_quality.dart';
import 'package:motto_music/services/bilibili/download_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';

/// 下载任务卡片
///
/// 显示单个下载任务的详细信息和操作按钮
class DownloadTaskCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback? onTap;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;

  const DownloadTaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onRetry,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final quality = BilibiliAudioQuality.fromId(task.quality);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.blue.withOpacity(0.1)
                : Colors.blue.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.blue.withOpacity(0.05),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.white.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：封面 + 信息
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面
                _buildCover(),
                const SizedBox(width: 12),

                // 标题和艺术家
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.artist != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.artist!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 右侧：音质徽章和状态图标
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusIcon(),
                    const SizedBox(height: 8),
                    quality.getBadge(),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 进度条和信息 (已完成状态显示删除按钮)
            task.status == 'completed'
                ? _buildCompletedActions(context)
                : _buildProgressSection(context),

            // 非已完成状态才显示操作按钮
            if (task.status != 'completed') ...[
              const SizedBox(height: 12),
              _buildActionButtons(context),
            ],
          ],
        ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建封面
  Widget _buildCover() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: task.coverUrl != null && task.coverUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: task.coverUrl!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(CupertinoIcons.music_note, size: 30),
              ),
              errorWidget: (context, url, error) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(CupertinoIcons.exclamationmark_triangle, size: 30),
              ),
            )
          : Container(
              width: 60,
              height: 60,
              color: Colors.grey[300],
              child: const Icon(CupertinoIcons.music_note, size: 30),
            ),
    );
  }

  /// 构建状态图标
  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    switch (task.status) {
      case 'downloading':
        icon = CupertinoIcons.cloud_download;
        color = Colors.blue;
        break;
      case 'pending':
        icon = CupertinoIcons.clock;
        color = Colors.orange;
        break;
      case 'paused':
        icon = CupertinoIcons.pause_circle;
        color = Colors.grey;
        break;
      case 'completed':
        icon = CupertinoIcons.check_mark_circled;
        color = Colors.green;
        break;
      case 'failed':
        icon = CupertinoIcons.exclamationmark_circle;
        color = Colors.red;
        break;
      default:
        icon = CupertinoIcons.question_circle;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 24);
  }

  /// 构建进度区域
  Widget _buildProgressSection(BuildContext context) {
    final downloadManager = context.watch<DownloadManager>();
    final progress = downloadManager.getProgress(task.id);

    if (task.status == 'completed') {
      return Row(
        children: [
          Icon(CupertinoIcons.check_mark_circled, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Text(
            '下载完成',
            style: TextStyle(
              fontSize: 13,
              color: Colors.green[700],
            ),
          ),
          const Spacer(),
          Text(
            _formatSize(task.totalBytes ?? 0),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    }

    if (task.status == 'failed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.exclamationmark_circle, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.errorMessage ?? '下载失败',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.red,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (task.status == 'paused') {
      return Row(
        children: [
          Icon(CupertinoIcons.pause_circle, color: Colors.grey, size: 16),
          const SizedBox(width: 8),
          const Text(
            '已暂停',
            style: TextStyle(fontSize: 13),
          ),
          const Spacer(),
          if (task.totalBytes != null)
            Text(
              '${_formatSize(task.downloadedBytes)} / ${_formatSize(task.totalBytes!)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
        ],
      );
    }

    // 下载中或等待中
    final progressPercent = progress?.progress ?? task.progress;
    final downloadedBytes = progress?.downloadedBytes ?? task.downloadedBytes;
    final totalBytes = progress?.totalBytes ?? task.totalBytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 进度条
        LinearProgressIndicator(
          value: progressPercent / 100.0,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            task.status == 'pending' ? Colors.orange : Colors.blue,
          ),
        ),
        const SizedBox(height: 8),

        // 进度信息
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 左侧：速度或百分比
            if (progress?.speed != null && task.status == 'downloading')
              Text(
                progress!.formattedSpeed,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              )
            else
              Text(
                '$progressPercent%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),

            // 右侧：大小或剩余时间
            if (progress?.estimatedTimeRemaining != null && task.status == 'downloading')
              Text(
                '剩余 ${progress!.formattedTimeRemaining}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              )
            else if (totalBytes != null)
              Text(
                '${_formatSize(downloadedBytes)} / ${_formatSize(totalBytes)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 构建已完成状态的操作区域
  Widget _buildCompletedActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.green, size: 16),
        const SizedBox(width: 8),
        Text(
          '下载完成',
          style: TextStyle(
            fontSize: 13,
            color: Colors.green[700],
          ),
        ),
        const Spacer(),
        Text(
          _formatSize(task.totalBytes ?? 0),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 12),
        _buildCompactButton(
          icon: CupertinoIcons.trash_fill,
          tooltip: '删除',
          onPressed: onDelete,
          color: Colors.red,
          isDark: isDark,
        ),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons(BuildContext context) {
    final buttons = <Widget>[];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (task.status) {
      case 'downloading':
        buttons.addAll([
          _buildCompactButton(
            icon: CupertinoIcons.pause_fill,
            tooltip: '暂停',
            onPressed: onPause,
            isDark: isDark,
          ),
          _buildCompactButton(
            icon: CupertinoIcons.xmark_circle_fill,
            tooltip: '取消',
            onPressed: onCancel,
            color: Colors.red,
            isDark: isDark,
          ),
        ]);
        break;

      case 'pending':
        buttons.add(
          _buildCompactButton(
            icon: CupertinoIcons.xmark_circle_fill,
            tooltip: '取消',
            onPressed: onCancel,
            color: Colors.red,
            isDark: isDark,
          ),
        );
        break;

      case 'paused':
        buttons.addAll([
          _buildCompactButton(
            icon: CupertinoIcons.play_arrow_solid,
            tooltip: '继续',
            onPressed: onResume,
            isDark: isDark,
          ),
          _buildCompactButton(
            icon: CupertinoIcons.xmark_circle_fill,
            tooltip: '取消',
            onPressed: onCancel,
            color: Colors.red,
            isDark: isDark,
          ),
        ]);
        break;

      case 'completed':
        buttons.add(
          _buildCompactButton(
            icon: CupertinoIcons.trash_fill,
            tooltip: '删除',
            onPressed: onDelete,
            color: Colors.red,
            isDark: isDark,
          ),
        );
        break;

      case 'failed':
        buttons.addAll([
          _buildCompactButton(
            icon: CupertinoIcons.arrow_clockwise,
            tooltip: '重试',
            onPressed: onRetry,
            isDark: isDark,
          ),
          _buildCompactButton(
            icon: CupertinoIcons.trash_fill,
            tooltip: '删除',
            onPressed: onDelete,
            color: Colors.red,
            isDark: isDark,
          ),
        ]);
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: buttons.map((btn) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: btn,
      )).toList(),
    );
  }

  /// 构建紧凑型按钮
  Widget _buildCompactButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required bool isDark,
    Color? color,
  }) {
    final buttonColor = color ?? (isDark ? Colors.white70 : Colors.black54);
    
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                width: 0.5,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: buttonColor,
            ),
          ),
        ),
      ),
    );
  }

  /// 格式化文件大小
  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
