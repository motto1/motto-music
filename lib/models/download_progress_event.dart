/// 下载进度事件
///
/// 用于通知下载进度更新
class DownloadProgressEvent {
  /// 下载任务 ID
  final int taskId;

  /// 下载状态
  final DownloadEventType type;

  /// 当前进度（0-100）
  final int progress;

  /// 已下载字节数
  final int downloadedBytes;

  /// 总字节数（可能为 null）
  final int? totalBytes;

  /// 下载速度（字节/秒）
  final int? speed;

  /// 预估剩余时间（秒）
  final int? estimatedTimeRemaining;

  /// 错误信息（仅当 type 为 failed 时）
  final String? error;

  DownloadProgressEvent({
    required this.taskId,
    required this.type,
    required this.progress,
    required this.downloadedBytes,
    this.totalBytes,
    this.speed,
    this.estimatedTimeRemaining,
    this.error,
  });

  /// 格式化下载速度
  String get formattedSpeed {
    if (speed == null) return '--';
    final speedMB = speed! / (1024 * 1024);
    return '${speedMB.toStringAsFixed(2)} MB/s';
  }

  /// 格式化预估剩余时间
  String get formattedTimeRemaining {
    if (estimatedTimeRemaining == null) return '--';
    final minutes = estimatedTimeRemaining! ~/ 60;
    final seconds = estimatedTimeRemaining! % 60;
    if (minutes > 0) {
      return '$minutes分$seconds秒';
    }
    return '$seconds秒';
  }

  /// 格式化已下载/总大小
  String get formattedSize {
    final downloadedMB = downloadedBytes / (1024 * 1024);
    if (totalBytes != null) {
      final totalMB = totalBytes! / (1024 * 1024);
      return '${downloadedMB.toStringAsFixed(1)} / ${totalMB.toStringAsFixed(1)} MB';
    }
    return '${downloadedMB.toStringAsFixed(1)} MB';
  }
}

/// 下载事件类型
enum DownloadEventType {
  /// 等待开始
  pending,

  /// 正在下载
  downloading,

  /// 已暂停
  paused,

  /// 下载完成
  completed,

  /// 下载失败
  failed,

  /// 已取消
  cancelled,
}
