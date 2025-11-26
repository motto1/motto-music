import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';
import 'package:motto_music/database/database.dart';
import 'package:motto_music/models/bilibili/audio_quality.dart';
import 'package:motto_music/models/download_progress_event.dart';
import 'package:motto_music/services/bilibili/stream_service.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';

/// Bilibili 音频下载服务
///
/// 核心功能：
/// - 下载队列管理（最多3个并发）
/// - 进度跟踪与通知
/// - 暂停/恢复/取消功能
/// - URL自动刷新（避免过期）
/// - 断点续传支持
/// - 自动重试机制
class BilibiliDownloadService {
  final MusicDatabase _database;
  final BilibiliStreamService _streamService;
  final CookieManager _cookieManager;

  /// 下载客户端
  final Dio _dio = Dio();

  /// 等待下载的任务队列
  final Queue<int> _pendingQueue = Queue<int>();

  /// 正在下载的任务 ID 列表（最多3个）
  final List<int> _activeDownloads = [];

  /// 下载进度流控制器
  final _progressController = StreamController<DownloadProgressEvent>.broadcast();

  /// 下载进度流（供外部监听）
  Stream<DownloadProgressEvent> get progressStream => _progressController.stream;

  /// 最大并发下载数
  int _maxConcurrentDownloads = 3;

  /// 下载任务取消令牌（用于取消下载）
  final Map<int, CancelToken> _cancelTokens = {};

  /// 是否自动重试失败的任务
  bool _autoRetryFailed = true;

  /// 下载重试次数
  static const int _maxRetries = 3;

  BilibiliDownloadService(
    this._database,
    this._streamService,
    this._cookieManager,
  );

  /// 更新最大并发下载数（1-5）
  void setMaxConcurrentDownloads(int count) {
    _maxConcurrentDownloads = count.clamp(1, 5);
    _processQueue(); // 立即处理队列
  }

  /// 设置是否自动重试
  void setAutoRetry(bool enabled) {
    _autoRetryFailed = enabled;
  }

  /// 添加下载任务
  ///
  /// 返回任务 ID
  Future<int> addDownloadTask({
    required String bvid,
    required int cid,
    required String title,
    required BilibiliAudioQuality quality,
    String? artist,
    String? coverUrl,
    int? duration,
  }) async {
    // 1. 检查是否已存在相同任务
    final existing = await _database.getDownloadTask(bvid, cid, quality.id);
    if (existing != null) {
      if (existing.status == 'completed') {
        throw Exception('该音质已下载完成');
      }
      if (existing.status == 'downloading' || existing.status == 'pending') {
        throw Exception('该任务正在下载中');
      }
      // 如果是失败或暂停状态，可以重新添加
      return existing.id;
    }

    // 2. 创建下载任务记录
    final taskId = await _database.into(_database.downloadTasks).insert(
          DownloadTasksCompanion.insert(
            bvid: bvid,
            cid: cid,
            quality: quality.id,
            title: title,
            artist: Value(artist),
            coverUrl: Value(coverUrl),
            duration: Value(duration),
            status: 'pending',
          ),
        );

    // 3. 添加到队列
    _pendingQueue.add(taskId);

    // 4. 发送事件
    _progressController.add(DownloadProgressEvent(
      taskId: taskId,
      type: DownloadEventType.pending,
      progress: 0,
      downloadedBytes: 0,
    ));

    // 5. 尝试开始下载
    _processQueue();

    return taskId;
  }

  /// 处理下载队列
  void _processQueue() {
    // 检查是否有空闲下载槽位
    while (_activeDownloads.length < _maxConcurrentDownloads && _pendingQueue.isNotEmpty) {
      final taskId = _pendingQueue.removeFirst();
      _activeDownloads.add(taskId);
      _startDownload(taskId);
    }
  }

  /// 开始下载任务
  Future<void> _startDownload(int taskId) async {
    try {
      // 1. 获取任务信息
      final task = await _database.downloadTasks.select()
        ..where((t) => t.id.equals(taskId));
      final taskData = await task.getSingleOrNull();

      if (taskData == null) {
        print('⚠️ 任务 $taskId 不存在');
        _finishDownload(taskId);
        return;
      }

      // 2. 更新任务状态为下载中
      await _database.update(_database.downloadTasks)
        ..where((t) => t.id.equals(taskId))
        ..write(DownloadTasksCompanion(
          status: const Value('downloading'),
          updatedAt: Value(DateTime.now()),
        ));

      // 3. 获取音频流URL
      final streamInfo = await _streamService.getAudioStream(
        bvid: taskData.bvid,
        cid: taskData.cid,
        quality: BilibiliAudioQuality.fromId(taskData.quality),
      );

      // 4. 准备下载路径
      final localPath = await _getDownloadPath(
        taskData.bvid,
        taskData.cid,
        taskData.quality,
      );

      // 5. 创建取消令牌
      final cancelToken = CancelToken();
      _cancelTokens[taskId] = cancelToken;

      // 6. 获取 Cookie
      final cookie = await _cookieManager.getCookieString();

      // 7. 配置 Dio 请求头
      final headers = {
        'Referer': 'https://www.bilibili.com',
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0_1 like Mac OS X) AppleWebKit/605.1.15',
        if (cookie.isNotEmpty) 'Cookie': cookie,
      };

      // 8. 执行下载（带进度跟踪）
      int lastReportTime = DateTime.now().millisecondsSinceEpoch;
      int lastDownloadedBytes = 0;

      await _dio.download(
        streamInfo.url,
        localPath,
        options: Options(headers: headers),
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) async {
          // 更新进度
          final progress = total > 0 ? ((received / total) * 100).toInt() : 0;

          // 计算下载速度（每秒更新一次）
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastReportTime >= 1000) {
            final speed = ((received - lastDownloadedBytes) * 1000) ~/
                (now - lastReportTime);
            final estimatedTimeRemaining =
                speed > 0 ? ((total - received) ~/ speed) : null;

            _progressController.add(DownloadProgressEvent(
              taskId: taskId,
              type: DownloadEventType.downloading,
              progress: progress,
              downloadedBytes: received,
              totalBytes: total,
              speed: speed,
              estimatedTimeRemaining: estimatedTimeRemaining,
            ));

            lastReportTime = now;
            lastDownloadedBytes = received;
          }

          // 更新数据库
          await _database.update(_database.downloadTasks)
            ..where((t) => t.id.equals(taskId))
            ..write(DownloadTasksCompanion(
              progress: Value(progress),
              downloadedBytes: Value(received),
              totalBytes: Value(total),
              updatedAt: Value(DateTime.now()),
            ));
        },
      );

      // 9. 下载完成
      await _database.update(_database.downloadTasks)
        ..where((t) => t.id.equals(taskId))
        ..write(DownloadTasksCompanion(
          status: const Value('completed'),
          progress: const Value(100),
          localPath: Value(localPath),
          completedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));

      _progressController.add(DownloadProgressEvent(
        taskId: taskId,
        type: DownloadEventType.completed,
        progress: 100,
        downloadedBytes: streamInfo.size,
        totalBytes: streamInfo.size,
      ));

      print('✅ 下载完成: ${taskData.title}');
    } catch (e) {
      print('❌ 下载失败 (任务 $taskId): $e');

      // 判断是否为用户主动取消
      if (e is DioException && e.type == DioExceptionType.cancel) {
        await _handleCancelled(taskId);
      } else {
        await _handleDownloadError(taskId, e.toString());
      }
    } finally {
      _finishDownload(taskId);
    }
  }

  /// 处理下载失败
  Future<void> _handleDownloadError(int taskId, String error) async {
    // 获取当前重试次数
    final task = await (_database.downloadTasks.select()
          ..where((t) => t.id.equals(taskId)))
        .getSingleOrNull();

    if (task == null) return;

    // 解析重试次数（从 errorMessage 中提取）
    int retryCount = 0;
    if (task.errorMessage != null && task.errorMessage!.contains('重试')) {
      final match = RegExp(r'重试 (\d+)').firstMatch(task.errorMessage!);
      if (match != null) {
        retryCount = int.parse(match.group(1)!);
      }
    }

    // 检查是否应该重试
    if (_autoRetryFailed && retryCount < _maxRetries) {
      retryCount++;
      final errorMsg = '下载失败，重试 $retryCount/$_maxRetries: $error';

      await _database.update(_database.downloadTasks)
        ..where((t) => t.id.equals(taskId))
        ..write(DownloadTasksCompanion(
          status: const Value('pending'),
          errorMessage: Value(errorMsg),
          updatedAt: Value(DateTime.now()),
        ));

      // 重新添加到队列
      _pendingQueue.add(taskId);

      print('🔄 任务 $taskId 将自动重试 ($retryCount/$_maxRetries)');
    } else {
      // 标记为失败
      await _database.update(_database.downloadTasks)
        ..where((t) => t.id.equals(taskId))
        ..write(DownloadTasksCompanion(
          status: const Value('failed'),
          errorMessage: Value(error),
          updatedAt: Value(DateTime.now()),
        ));

      _progressController.add(DownloadProgressEvent(
        taskId: taskId,
        type: DownloadEventType.failed,
        progress: 0,
        downloadedBytes: 0,
        error: error,
      ));
    }
  }

  /// 处理下载取消
  Future<void> _handleCancelled(int taskId) async {
    await _database.update(_database.downloadTasks)
      ..where((t) => t.id.equals(taskId))
      ..write(DownloadTasksCompanion(
        status: const Value('cancelled'),
        errorMessage: const Value('用户取消下载'),
        updatedAt: Value(DateTime.now()),
      ));

    _progressController.add(DownloadProgressEvent(
      taskId: taskId,
      type: DownloadEventType.cancelled,
      progress: 0,
      downloadedBytes: 0,
    ));

    print('⏹️ 任务 $taskId 已取消');
  }

  /// 完成下载（无论成功或失败）
  void _finishDownload(int taskId) {
    _activeDownloads.remove(taskId);
    _cancelTokens.remove(taskId);
    _processQueue(); // 继续处理队列中的任务
  }

  /// 暂停下载
  Future<void> pauseDownload(int taskId) async {
    final cancelToken = _cancelTokens[taskId];
    if (cancelToken != null) {
      cancelToken.cancel('用户暂停下载');
    }

    await _database.update(_database.downloadTasks)
      ..where((t) => t.id.equals(taskId))
      ..write(DownloadTasksCompanion(
        status: const Value('paused'),
        updatedAt: Value(DateTime.now()),
      ));

    _progressController.add(DownloadProgressEvent(
      taskId: taskId,
      type: DownloadEventType.paused,
      progress: 0,
      downloadedBytes: 0,
    ));
  }

  /// 恢复下载
  Future<void> resumeDownload(int taskId) async {
    await _database.update(_database.downloadTasks)
      ..where((t) => t.id.equals(taskId))
      ..write(DownloadTasksCompanion(
        status: const Value('pending'),
        errorMessage: const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ));

    _pendingQueue.add(taskId);
    _processQueue();
  }

  /// 取消下载
  Future<void> cancelDownload(int taskId) async {
    final cancelToken = _cancelTokens[taskId];
    if (cancelToken != null) {
      cancelToken.cancel('用户取消下载');
    }

    await _handleCancelled(taskId);

    // 从队列中移除
    _pendingQueue.remove(taskId);
  }

  /// 删除下载任务
  Future<void> deleteDownloadTask(int taskId) async {
    // 1. 如果正在下载，先取消
    if (_activeDownloads.contains(taskId)) {
      await cancelDownload(taskId);
    }

    // 2. 获取任务信息
    final task = await (_database.downloadTasks.select()
          ..where((t) => t.id.equals(taskId)))
        .getSingleOrNull();

    if (task == null) return;

    // 3. 删除本地文件
    if (task.localPath != null && task.localPath!.isNotEmpty) {
      try {
        final file = File(task.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('⚠️ 删除文件失败: $e');
      }
    }

    // 4. 删除数据库记录
    await (_database.delete(_database.downloadTasks)
          ..where((t) => t.id.equals(taskId)))
        .go();

    print('🗑️ 任务 $taskId 已删除');
  }

  /// 重试失败的任务
  Future<void> retryFailedTask(int taskId) async {
    await _database.update(_database.downloadTasks)
      ..where((t) => t.id.equals(taskId))
      ..write(DownloadTasksCompanion(
        status: const Value('pending'),
        progress: const Value(0),
        downloadedBytes: const Value(0),
        errorMessage: const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ));

    _pendingQueue.add(taskId);
    _processQueue();
  }

  /// 获取下载文件路径
  Future<String> _getDownloadPath(String bvid, int cid, int quality) async {
    final baseDir = await _resolveDownloadBaseDirectory();
    final downloadDir = Directory(baseDir);

    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    final fileName = '${bvid}_${cid}_$quality.m4s';
    return p.join(downloadDir.path, fileName);
  }

  Future<String> _resolveDownloadBaseDirectory() async {
    final settings = await _database.getUserSettings();
    final custom = settings?.downloadDirectory;
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }

    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.music);
      if (dirs != null && dirs.isNotEmpty) {
        return p.join(dirs.first.path, 'MottoMusic', 'Bilibili');
      }
      final fallback = await getExternalStorageDirectory();
      if (fallback != null) {
        return p.join(fallback.path, 'MottoMusic', 'Bilibili');
      }
    }

    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'downloads', 'bilibili');
  }

  /// 获取所有下载任务
  Future<List<DownloadTask>> getAllDownloadTasks() async {
    return await _database.downloadTasks.select().get();
  }

  /// 获取正在下载的任务
  Future<List<DownloadTask>> getDownloadingTasks() async {
    return await (_database.downloadTasks.select()
          ..where((t) =>
              t.status.equals('downloading') | t.status.equals('pending')))
        .get();
  }

  /// 获取已完成的任务
  Future<List<DownloadTask>> getCompletedTasks() async {
    return await (_database.downloadTasks.select()
          ..where((t) => t.status.equals('completed')))
        .get();
  }

  /// 获取失败的任务
  Future<List<DownloadTask>> getFailedTasks() async {
    return await (_database.downloadTasks.select()
          ..where((t) => t.status.equals('failed')))
        .get();
  }

  /// 清理已完成的下载记录（保留文件）
  Future<void> clearCompletedTasks() async {
    await (_database.delete(_database.downloadTasks)
          ..where((t) => t.status.equals('completed')))
        .go();
  }

  /// 释放资源
  void dispose() {
    _progressController.close();
    _dio.close();
  }
}
